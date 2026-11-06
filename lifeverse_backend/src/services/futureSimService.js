const activityLogService = require('./activityLogService');
const hdeService = require('./hdeService');

class FutureSimService {

    async checkUnlockStatus(userId) {
        const consistency = await activityLogService.getConsistencyScore(userId);
        const totalXp = await activityLogService.getTotalXp(userId);
        const hdeStats = await hdeService.getStats(userId);

        const dataPoints = totalXp + (hdeStats.currentStreak * 5) + consistency;
        const requiredData = 100;

        return {
            unlocked: dataPoints >= requiredData,
            progress: Math.min(100, Math.round((dataPoints / requiredData) * 100)),
            currentData: dataPoints,
            requiredData,
            consistency,
            totalXp
        };
    }
}

module.exports = new FutureSimService();
