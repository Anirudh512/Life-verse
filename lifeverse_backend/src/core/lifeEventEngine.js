/**
 * Life Event Engine — Central Nervous System of LifeVerse.
 * Every meaningful user action flows through here, gets logged,
 * and triggers updates across all pillars.
 */

const activityLogService = require('../services/activityLogService');
const hdeService = require('../services/hdeService');
const legacyService = require('../services/legacyService');
const digitalTwinService = require('../services/digitalTwinService');
const { db } = require('../config/db');

const XP_REWARDS = {
    SURVEY_SUBMITTED: 10,
    TIME_CAPSULE_CREATED: 15,
    TIME_CAPSULE_OPENED: 20,
    LEGACY_EVENT_ADDED: 5,
};
const DAILY_REWARD_LIMITS = {
    TIME_CAPSULE_CREATED: 3,
    LEGACY_EVENT_ADDED: 1
};

class LifeEventEngine {

    normalizeEvent(eventData) {
        const type = eventData.type || eventData.eventType;
        const details = eventData.details || eventData.data || {};
        return { userId: eventData.userId, type, details };
    }

    async processEvent(eventData, { executor = db, taskXpReward } = {}) {
        const { userId, type, details } = this.normalizeEvent(eventData);

        if (!userId || !type) {
            throw new Error('userId and event type are required');
        }

        console.log(`[LifeEventEngine] ${type} → user ${userId}`);

        // XP is a server-owned value. Request metadata must never choose its reward.
        let xpReward = type === 'TASK_COMPLETED'
            ? Math.max(0, Math.min(50, Math.floor(Number(taskXpReward) || 0)))
            : (XP_REWARDS[type] ?? 0);
        if (type === 'TASK_COMPLETED' && xpReward <= 0) {
            throw new Error('A valid server task reward is required');
        }
        const dailyLimit = DAILY_REWARD_LIMITS[type];
        if (dailyLimit) {
            // These events are generated inside their route transaction. Locking the
            // user's row serializes concurrent requests while the daily cap is checked.
            await executor.query('SELECT id FROM users WHERE id = ? FOR UPDATE', [userId]);
            const [rows] = await executor.query(`
                SELECT COUNT(*) AS reward_count
                FROM user_activity_logs
                WHERE user_id = ? AND action_type = ? AND created_at >= CURDATE()
            `, [userId, type]);
            if (Number(rows[0].reward_count) >= dailyLimit) xpReward = 0;
        }
        const dimension = details.dimension ? hdeService.normalizeDimension(details.dimension) : null;

        // Step 1: Always log to the central timeline first
        // Activity analytics are deliberately content-free. Capsule messages,
        // reflections, AI prompts, and private milestone text stay in their
        // feature-specific records and never enter the general activity log.
        const logEntry = await activityLogService.logEvent(
            userId, type, xpReward, {}, dimension, executor
        );

        // Step 2: Route to pillar updates
        const results = { log: logEntry };

        switch (type) {
            case 'TASK_COMPLETED':
                results.hde = await hdeService.completeTask(
                    userId, details.taskTitle || details.taskId, dimension, xpReward, executor
                );
                results.twin = await digitalTwinService.aggregateFromLogs(userId, executor);
                break;

            case 'SURVEY_SUBMITTED':
                results.twin = await digitalTwinService.aggregateFromLogs(userId, executor);
                break;

            case 'TIME_CAPSULE_CREATED':
                results.legacy = await legacyService.addLegacyEvent(userId, {
                    title: details.title || 'Time Capsule Sealed',
                    description: details.message || '',
                    chapter: 'Time Capsules',
                    type: 'MILESTONE',
                    coreValues: ['Reflection', 'Memory']
                }, executor);
                results.twin = await digitalTwinService.aggregateFromLogs(userId, executor);
                break;

            case 'TIME_CAPSULE_OPENED':
                results.twin = await digitalTwinService.aggregateFromLogs(userId, executor);
                break;

            case 'LEGACY_EVENT_ADDED':
                results.legacy = await legacyService.addLegacyEvent(userId, details, executor);
                results.twin = await digitalTwinService.aggregateFromLogs(userId, executor);
                break;

            default:
                console.log(`[LifeEventEngine] Logged unhandled type: ${type}`);
        }

        return {
            success: true,
            message: 'Event processed successfully',
            eventType: type,
            xpGained: xpReward,
            results
        };
    }
}

const lifeEventEngine = new LifeEventEngine();
module.exports = { lifeEventEngine };
