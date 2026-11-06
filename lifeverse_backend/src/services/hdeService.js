const { db } = require('../config/db');

const DIMENSIONS = ['physical', 'cognitive', 'psychosocial', 'moral'];

class HDEService {

    normalizeDimension(dimension) {
        return String(dimension || 'general').trim().toLowerCase();
    }

    isTrackedDimension(dimension) {
        return DIMENSIONS.includes(this.normalizeDimension(dimension));
    }

    async getOrCreateStats(userId, executor = db) {
        const [rows] = await executor.query(
            'SELECT * FROM user_hde_stats WHERE user_id = ? LIMIT 1',
            [userId]
        );

        if (rows.length > 0) {
            return rows[0];
        }

        await executor.query(
            'INSERT IGNORE INTO user_hde_stats (user_id) VALUES (?)',
            [userId]
        );

        const [created] = await executor.query(
            'SELECT * FROM user_hde_stats WHERE user_id = ? LIMIT 1',
            [userId]
        );
        return created[0];
    }

    getDimensionXp(stats, dimension) {
        const key = `${this.normalizeDimension(dimension)}_xp`;
        return Number(stats[key]) || 0;
    }

    getDimensionLevel(stats, dimension) {
        const key = `${this.normalizeDimension(dimension)}_level`;
        return Number(stats[key]) || 1;
    }

    calculateLevel(xp) {
        return Math.floor(Math.sqrt(xp / 100)) + 1;
    }

    calculateLifeBalance(stats) {
        const levels = DIMENSIONS.map(d => this.getDimensionLevel(stats, d));
        const maxLevel = Math.max(...levels, 1);
        let balanceScore = 0;
        for (const level of levels) {
            balanceScore += (level / maxLevel) * 25;
        }
        return Math.round(balanceScore);
    }

    /**
     * Completes a development task and updates user's HDE stats.
     */
    async completeTask(userId, taskTitle, dimension, xpReward = 25, executor = db) {
        const dim = this.normalizeDimension(dimension);
        if (!this.isTrackedDimension(dim)) {
            throw new Error(`Invalid HDE dimension: ${dimension}`);
        }
        const stats = await this.getOrCreateStats(userId, executor);

        const xpKey = `${dim}_xp`;
        const levelKey = `${dim}_level`;
        const newXp = this.getDimensionXp(stats, dim) + xpReward;
        const newLevel = this.calculateLevel(newXp);

        const today = new Date().toISOString().split('T')[0];
        let currentStreak = Number(stats.current_streak) || 0;
        let momentum = Number(stats.momentum) || 50;
        const lastActiveDate = stats.last_active_date
            ? new Date(stats.last_active_date).toISOString().split('T')[0]
            : null;

        if (lastActiveDate !== today) {
            const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
            if (!lastActiveDate) {
                // First-ever completed task for a new user
                currentStreak = 1;
                momentum = Math.min(100, momentum + 2);
            } else if (lastActiveDate === yesterday) {
                currentStreak += 1;
                momentum = Math.min(100, momentum + 2);
            } else {
                currentStreak = 1;
                momentum = Math.max(0, momentum - 15);
            }
        } else {
            momentum = Math.min(100, momentum + 0.5);
        }

        const updatedStats = {
            ...stats,
            [xpKey.replace('_xp', '_xp')]: newXp,
        };
        updatedStats[`${dim}_xp`] = newXp;
        updatedStats[`${dim}_level`] = newLevel;
        updatedStats.current_streak = currentStreak;
        updatedStats.momentum = momentum;
        updatedStats.last_active_date = today;
        updatedStats.life_balance_index = this.calculateLifeBalance({
            ...stats,
            [`${dim}_level`]: newLevel
        });

        await executor.query(`
            UPDATE user_hde_stats SET
                ${dim}_xp = ?, ${dim}_level = ?,
                current_streak = ?, momentum = ?, last_active_date = ?, life_balance_index = ?
            WHERE user_id = ?
        `, [newXp, newLevel, currentStreak, momentum, today, updatedStats.life_balance_index, userId]);

        return {
            dimension: dim,
            taskTitle,
            newXp,
            newLevel,
            leveledUp: newLevel > this.getDimensionLevel(stats, dim),
            momentum,
            currentStreak,
            lifeBalanceIndex: updatedStats.life_balance_index
        };
    }

    async getStats(userId, executor = db) {
        const stats = await this.getOrCreateStats(userId, executor);
        return {
            currentStreak: stats.current_streak,
            momentum: stats.momentum,
            lifeBalanceIndex: stats.life_balance_index,
            dimensions: DIMENSIONS.reduce((acc, dim) => {
                acc[dim] = {
                    xp: this.getDimensionXp(stats, dim),
                    level: this.getDimensionLevel(stats, dim)
                };
                return acc;
            }, {})
        };
    }
}

module.exports = new HDEService();
