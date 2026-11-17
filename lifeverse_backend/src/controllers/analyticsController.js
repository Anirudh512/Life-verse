const { db } = require('../config/db');
const activityLogService = require('../services/activityLogService');
const growthGoalService = require('../services/growthGoalService');
const hdeService = require('../services/hdeService');

const ALLOWED_RANGES = new Set([7, 30, 90]);

function asIsoDate(value) {
    if (value instanceof Date) return value.toISOString().slice(0, 10);
    return String(value || '').slice(0, 10);
}

class AnalyticsController {
    async recordVisit(req, res) {
        try {
            const userId = req.user?.userId;
            if (!userId) return res.status(401).json({ success: false, message: 'Sign in to record this visit.' });

            // The primary key makes retries, app resumes, and multiple tabs count
            // as one visit per account per UTC date.
            const [result] = await db.query(
                'INSERT IGNORE INTO user_app_visits (user_id, visit_date) VALUES (?, UTC_DATE())',
                [userId]
            );
            res.json({ success: true, recorded: Number(result.affectedRows) === 1, policy: 'one_per_utc_day' });
        } catch (error) {
            console.error('[AnalyticsController] recordVisit failed:', error.message);
            res.status(500).json({ success: false, message: 'Visit could not be recorded.' });
        }
    }

    async getProgress(req, res) {
        try {
            const { userId } = req.params;
            const days = Number(req.query.days || 7);
            if (!userId) return res.status(400).json({ success: false, message: 'User ID is required.' });
            if (!ALLOWED_RANGES.has(days)) {
                return res.status(400).json({ success: false, message: 'Choose a 7, 30, or 90 day range.' });
            }

            const interval = days - 1;
            const settled = await Promise.allSettled([
                db.query(`
                    SELECT DATE_FORMAT(created_at, '%Y-%m-%d') AS date,
                           SUM(CASE WHEN action_type = 'TASK_COMPLETED' THEN 1 ELSE 0 END) AS tasksCompleted,
                           SUM(CASE WHEN action_type = 'SURVEY_SUBMITTED' THEN 1 ELSE 0 END) AS reviewsCompleted,
                           COALESCE(SUM(xp_gained), 0) AS xp
                    FROM user_activity_logs
                    WHERE user_id = ?
                      AND created_at >= DATE_SUB(UTC_DATE(), INTERVAL ? DAY)
                      AND created_at < DATE_ADD(UTC_DATE(), INTERVAL 1 DAY)
                    GROUP BY DATE(created_at)
                    ORDER BY DATE(created_at) ASC
                `, [userId, interval]),
                db.query(`
                    SELECT DATE_FORMAT(visit_date, '%Y-%m-%d') AS date
                    FROM user_app_visits
                    WHERE user_id = ?
                      AND visit_date BETWEEN DATE_SUB(UTC_DATE(), INTERVAL ? DAY) AND UTC_DATE()
                    ORDER BY visit_date ASC
                `, [userId, interval]),
                db.query(`
                    SELECT LOWER(dimension) AS dimension,
                           SUM(CASE WHEN action_type = 'TASK_COMPLETED' THEN 1 ELSE 0 END) AS tasksCompleted,
                           SUM(CASE WHEN action_type = 'SURVEY_SUBMITTED' THEN 1 ELSE 0 END) AS reviewsCompleted,
                           COUNT(DISTINCT CASE WHEN action_type IN ('TASK_COMPLETED', 'SURVEY_SUBMITTED') THEN DATE(created_at) END) AS activeDays,
                           COALESCE(SUM(xp_gained), 0) AS xp
                    FROM user_activity_logs
                    WHERE user_id = ? AND dimension IS NOT NULL
                      AND action_type IN ('TASK_COMPLETED', 'SURVEY_SUBMITTED')
                      AND created_at >= DATE_SUB(UTC_DATE(), INTERVAL ? DAY)
                      AND created_at < DATE_ADD(UTC_DATE(), INTERVAL 1 DAY)
                    GROUP BY LOWER(dimension)
                `, [userId, interval]),
                db.query(`
                    SELECT action_type AS actionType, LOWER(dimension) AS dimension,
                           xp_gained AS xp, created_at AS createdAt
                    FROM user_activity_logs
                    WHERE user_id = ?
                      AND created_at >= DATE_SUB(UTC_DATE(), INTERVAL ? DAY)
                      AND created_at < DATE_ADD(UTC_DATE(), INTERVAL 1 DAY)
                    ORDER BY created_at DESC
                    LIMIT 30
                `, [userId, interval]),
                activityLogService.getTotalXp(userId),
                hdeService.getStats(userId),
                growthGoalService.list(userId)
            ]);

            const required = [settled[0], settled[2], settled[3]];
            const requiredFailure = required.find(result => result.status === 'rejected');
            if (requiredFailure) throw requiredFailure.reason;

            const [dailyRows] = settled[0].value;
            const [dimensionRows] = settled[2].value;
            const [recentRows] = settled[3].value;

            const visitResult = settled[1];
            const totalXpResult = settled[4];
            const hdeStatsResult = settled[5];
            const goalsResult = settled[6];
            const visitsAvailable = visitResult.status === 'fulfilled';
            const totalXpAvailable = totalXpResult.status === 'fulfilled';
            const hdeStatsAvailable = hdeStatsResult.status === 'fulfilled';
            const goalsAvailable = goalsResult.status === 'fulfilled';

            if (!visitsAvailable) console.error('[AnalyticsController] Visit history unavailable:', visitResult.reason?.message || visitResult.reason);
            if (!totalXpAvailable) console.error('[AnalyticsController] Lifetime XP unavailable:', totalXpResult.reason?.message || totalXpResult.reason);
            if (!hdeStatsAvailable) console.error('[AnalyticsController] Growth levels unavailable:', hdeStatsResult.reason?.message || hdeStatsResult.reason);
            if (!goalsAvailable) console.error('[AnalyticsController] Growth goals unavailable:', goalsResult.reason?.message || goalsResult.reason);

            const visitRows = visitsAvailable ? visitResult.value[0] : [];
            const totalXp = totalXpAvailable ? totalXpResult.value : null;
            const hdeStats = hdeStatsAvailable ? hdeStatsResult.value : null;
            const goals = goalsAvailable ? goalsResult.value : null;

            const dailyByDate = new Map(dailyRows.map(row => [asIsoDate(row.date), {
                tasksCompleted: Number(row.tasksCompleted) || 0,
                reviewsCompleted: Number(row.reviewsCompleted) || 0,
                xp: Number(row.xp) || 0
            }]));
            const visitDates = new Set(visitRows.map(row => asIsoDate(row.date)));
            const daily = [];
            const today = new Date();
            for (let offset = interval; offset >= 0; offset -= 1) {
                const date = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() - offset));
                const dateKey = asIsoDate(date);
                const activity = dailyByDate.get(dateKey) || { tasksCompleted: 0, reviewsCompleted: 0, xp: 0 };
                daily.push({
                    date: dateKey,
                    visited: visitsAvailable ? visitDates.has(dateKey) : null,
                    tasksCompleted: activity.tasksCompleted,
                    reviewsCompleted: activity.reviewsCompleted,
                    growthActivity: activity.tasksCompleted + activity.reviewsCompleted > 0,
                    xp: activity.xp
                });
            }

            const dimensions = Object.fromEntries(['physical', 'cognitive', 'psychosocial', 'moral'].map(name => [name, {
                tasksCompleted: 0, reviewsCompleted: 0, activeDays: 0, xp: 0
            }]));
            for (const row of dimensionRows) {
                if (dimensions[row.dimension]) {
                    dimensions[row.dimension] = {
                        tasksCompleted: Number(row.tasksCompleted) || 0,
                        reviewsCompleted: Number(row.reviewsCompleted) || 0,
                        activeDays: Number(row.activeDays) || 0,
                        xp: Number(row.xp) || 0
                    };
                }
            }

            const tasksCompleted = daily.reduce((sum, item) => sum + item.tasksCompleted, 0);
            const reviewsCompleted = daily.reduce((sum, item) => sum + item.reviewsCompleted, 0);
            const growthDays = daily.filter(item => item.growthActivity).length;
            const periodXp = daily.reduce((sum, item) => sum + item.xp, 0);

            res.json({
                success: true,
                window: { days, startDate: daily[0]?.date, endDate: daily[daily.length - 1]?.date, timezone: 'UTC' },
                summary: {
                    visitDays: visitsAvailable ? visitDates.size : null,
                    growthDays,
                    tasksCompleted,
                    reviewsCompleted,
                    periodXp,
                    totalXp: totalXpAvailable ? Number(totalXp) || 0 : null
                },
                availability: { visits: visitsAvailable, totalXp: totalXpAvailable, hdeStats: hdeStatsAvailable, goals: goalsAvailable },
                daily,
                dimensions,
                hdeStats,
                goals,
                recentActivity: recentRows.map(row => ({
                    actionType: row.actionType,
                    dimension: row.dimension,
                    xp: Number(row.xp) || 0,
                    createdAt: row.createdAt
                }))
            });
        } catch (error) {
            console.error('[AnalyticsController] getProgress failed:', error.message);
            res.status(500).json({ success: false, message: 'Progress is unavailable right now.' });
        }
    }

    async getXP(req, res) {
        // Keep the existing API response for current clients while sharing the
        // canonical UTC date handling used by the new Progress screen.
        try {
            const { userId } = req.params;
            if (!userId) return res.status(400).json({ success: false, message: 'User ID is required.' });
            const dailyRows = await activityLogService.getDailyXpSummary(userId, 7);
            const totalXp = await activityLogService.getTotalXp(userId);
            const hdeStats = await hdeService.getStats(userId);
            const xpByDate = Object.fromEntries(dailyRows.map(row => [asIsoDate(row.date), Number(row.xp) || 0]));
            const chartData = [];
            let cumulativeXp = 0;
            const today = new Date();
            for (let offset = 6; offset >= 0; offset -= 1) {
                const date = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() - offset));
                const dateKey = asIsoDate(date);
                const xp = xpByDate[dateKey] || 0;
                cumulativeXp += xp;
                chartData.push({ day: 6 - offset, date: dateKey, xp, collective: cumulativeXp });
            }
            res.json({ success: true, data: chartData, totalXp, hdeStats });
        } catch (error) {
            console.error('[AnalyticsController] getXP error:', error.message);
            res.status(500).json({ success: false, message: 'Progress is unavailable right now.' });
        }
    }
}

module.exports = new AnalyticsController();
