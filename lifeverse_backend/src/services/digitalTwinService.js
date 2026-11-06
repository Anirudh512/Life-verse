const { db } = require('../config/db');
const activityLogService = require('./activityLogService');
const { parseJsonObject } = require('../utils/json');

const ALL_DIMENSIONS = ['physical', 'cognitive', 'psychosocial', 'moral'];

class DigitalTwinService {

    async aggregateFromLogs(userId, executor = db) {
        const dimensionActivity = await activityLogService.getDimensionActivity(userId, 30, executor);
        const consistency = await activityLogService.getConsistencyScore(userId, 30, executor);
        const [coverageRows] = await executor.query(`
            SELECT COUNT(*) AS logged_actions,
                   COUNT(DISTINCT DATE(created_at)) AS active_days,
                   COALESCE(SUM(xp_gained), 0) AS xp_earned
            FROM user_activity_logs
            WHERE user_id = ? AND created_at >= DATE_SUB(CURDATE(), INTERVAL 29 DAY)
        `, [userId]);
        const coverage = coverageRows[0] || {};

        const activityMap = {};
        for (const dim of ALL_DIMENSIONS) {
            activityMap[dim] = { count: 0, xp: 0 };
        }
        for (const row of dimensionActivity) {
            activityMap[row.dimension] = { count: Number(row.count), xp: Number(row.xp) };
        }

        const sorted = ALL_DIMENSIONS
            .map(d => ({ dimension: d, ...activityMap[d] }))
            .sort((a, b) => b.count - a.count);

        const activeDimensions = sorted.filter(d => d.count > 0);
        const strong = activeDimensions.slice(0, 3).map(d => this.formatDimension(d.dimension));
        const notYetRecorded = sorted.filter(d => d.count === 0).map(d => this.formatDimension(d.dimension));
        const activeDays = Number(coverage.active_days) || 0;
        const loggedActions = Number(coverage.logged_actions) || 0;

        const profile = {
            habitDNA: {
                strong: strong.length > 0 ? strong : ['Getting Started'],
                notYetRecorded
            },
            observedEngagement: {
                periodDays: 30,
                loggedActions,
                activeDays,
                xpEarned: Number(coverage.xp_earned) || 0,
                activeDayRate: Math.round((activeDays / 30) * 100),
                consistencyRate: consistency,
                dimensions: activeDimensions.map(d => ({
                    name: this.formatDimension(d.dimension),
                    loggedActions: d.count,
                    xpEarned: d.xp
                })),
                coverageLabel: activeDays < 4 ? 'Early record' : activeDays < 12 ? 'Building record' : 'Ongoing record'
            },
            lastAggregated: new Date().toISOString()
        };

        await executor.query(`
            INSERT INTO digital_twin_profiles (user_id, habit_dna, personality_evolution, confidence_score, last_aggregated)
            VALUES (?, ?, ?, ?, NOW())
            ON DUPLICATE KEY UPDATE
                habit_dna = ?, personality_evolution = ?, confidence_score = ?, last_aggregated = NOW()
        `, [
            userId,
            JSON.stringify(profile.habitDNA),
            JSON.stringify(profile.observedEngagement),
            0,
            JSON.stringify(profile.habitDNA),
            JSON.stringify(profile.observedEngagement),
            0
        ]);

        return profile;
    }

    formatDimension(dimension) {
        return dimension.charAt(0).toUpperCase() + dimension.slice(1);
    }

    async getTwinProfile(userId) {
        const [rows] = await db.query(
            'SELECT habit_dna, personality_evolution, confidence_score, last_aggregated FROM digital_twin_profiles WHERE user_id = ? LIMIT 1',
            [userId]
        );

        if (rows.length > 0) {
            const observedEngagement = parseJsonObject(rows[0].personality_evolution);
            // Replace previously stored personality scores with activity facts
            // the first time an older profile is read after this update.
            if (!Number.isFinite(Number(observedEngagement.loggedActions)) ||
                !Number.isFinite(Number(observedEngagement.activeDays))) {
                return this.aggregateFromLogs(userId);
            }
            return {
                habitDNA: parseJsonObject(rows[0].habit_dna),
                observedEngagement,
                lastAggregated: rows[0].last_aggregated
            };
        }

        return this.aggregateFromLogs(userId);
    }
}

module.exports = new DigitalTwinService();
