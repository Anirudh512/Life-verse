const { db } = require('../config/db');

/**
 * Central activity log — every user action lands here.
 * This is the ultimate timeline that powers Profile, Twin, and Future Sim.
 */
class ActivityLogService {

    async logEvent(userId, actionType, xpGained = 0, metadata = {}, dimension = null, executor = db) {
        await executor.query(
            'INSERT INTO user_activity_logs (user_id, action_type, dimension, xp_gained, metadata) VALUES (?, ?, ?, ?, ?)',
            [userId, actionType, dimension, xpGained, JSON.stringify(metadata)]
        );
        return { actionType, xpGained, dimension };
    }

    async getDailyXpSummary(userId, days = 7) {
        const [rows] = await db.query(`
            SELECT DATE(created_at) as date, SUM(xp_gained) as xp, COUNT(*) as actions
            FROM user_activity_logs
            WHERE user_id = ?
            AND created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
            GROUP BY DATE(created_at)
            ORDER BY date ASC
        `, [userId, days - 1]);
        return rows;
    }

    async getTotalXp(userId, executor = db) {
        const [rows] = await executor.query(
            'SELECT COALESCE(SUM(xp_gained), 0) as total FROM user_activity_logs WHERE user_id = ?',
            [userId]
        );
        return Number(rows[0].total);
    }

    async getDimensionActivity(userId, days = 30, executor = db) {
        const [rows] = await executor.query(`
            SELECT LOWER(dimension) as dimension, COUNT(*) as count, SUM(xp_gained) as xp
            FROM user_activity_logs
            WHERE user_id = ? AND dimension IS NOT NULL
            AND created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
            GROUP BY LOWER(dimension)
        `, [userId, days]);
        return rows;
    }

    async getConsistencyScore(userId, days = 14, executor = db) {
        const [rows] = await executor.query(`
            SELECT COUNT(DISTINCT DATE(created_at)) as active_days
            FROM user_activity_logs
            WHERE user_id = ? AND created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
        `, [userId, days]);
        const activeDays = Number(rows[0].active_days) || 0;
        return Math.min(100, Math.round((activeDays / days) * 100));
    }

    async getRecentLogs(userId, limit = 50) {
        const [rows] = await db.query(
            'SELECT id, action_type, dimension, xp_gained, created_at FROM user_activity_logs WHERE user_id = ? ORDER BY created_at DESC LIMIT ?',
            [userId, limit]
        );
        return rows;
    }

    async getActionCounts(userId, days = 30) {
        const [rows] = await db.query(`
            SELECT action_type, COUNT(*) as count
            FROM user_activity_logs
            WHERE user_id = ? AND created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
            GROUP BY action_type
        `, [userId, days]);
        return rows;
    }
}

module.exports = new ActivityLogService();
