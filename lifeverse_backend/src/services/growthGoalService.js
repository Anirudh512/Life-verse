const crypto = require('node:crypto');
const { db } = require('../config/db');
const hdeService = require('./hdeService');

const MAX_TARGET_TASKS = 100;
const MAX_GOAL_DAYS = 365;
const MAX_SAVED_GOALS = 10;

function invalid(message) {
    const error = new Error(message);
    error.statusCode = 400;
    throw error;
}

function validateGoal(input, now = new Date(), { allowPastDueDate = false } = {}) {
    const title = String(input?.title || '').trim();
    if (title.length < 3 || title.length > 120) {
        invalid('Goal title must contain between 3 and 120 characters.');
    }

    const dimension = hdeService.normalizeDimension(input?.dimension);
    if (!hdeService.isTrackedDimension(dimension)) {
        invalid('Choose a valid HDE dimension.');
    }

    const progressMetric = String(input?.progressMetric || 'tasks');
    if (!['tasks', 'active_days'].includes(progressMetric)) {
        invalid('Choose whether this goal measures completed tasks or active days.');
    }

    const targetTasks = Number(input?.targetTasks);
    if (!Number.isInteger(targetTasks) || targetTasks < 1 || targetTasks > MAX_TARGET_TASKS) {
        invalid(`Task target must be a whole number between 1 and ${MAX_TARGET_TASKS}.`);
    }

    const dueDate = String(input?.dueDate || '');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dueDate)) {
        invalid('Choose a valid goal date.');
    }
    const parsedDueDate = new Date(`${dueDate}T00:00:00.000Z`);
    if (!Number.isFinite(parsedDueDate.getTime()) || parsedDueDate.toISOString().slice(0, 10) !== dueDate) {
        invalid('Choose a valid goal date.');
    }

    const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    const latestDate = new Date(today);
    latestDate.setUTCDate(latestDate.getUTCDate() + MAX_GOAL_DAYS);
    if ((!allowPastDueDate && parsedDueDate < today) || parsedDueDate > latestDate) {
        invalid('Goal date must be today or within the next 365 days.');
    }

    const reminderEnabled = input?.reminderEnabled === true || Number(input?.reminderEnabled) === 1;
    return { title, dimension, targetTasks, dueDate, reminderEnabled, progressMetric };
}

class GrowthGoalService {
    validateGoal(input, now) {
        return validateGoal(input, now);
    }

    async create(userId, input, executor = db, now = new Date()) {
        if (!userId) invalid('A valid user is required.');
        const goal = validateGoal(input, now);
        const ownsConnection = executor === db;
        const connection = ownsConnection ? await db.getConnection() : executor;
        let transactionStarted = false;
        try {
            if (ownsConnection) {
                await connection.beginTransaction();
                transactionStarted = true;
                // Serialize this user's goal-count check to enforce the saved-goal cap.
                const [users] = await connection.query(
                    'SELECT id FROM users WHERE id = ? FOR UPDATE',
                    [userId]
                );
                if (users.length === 0) invalid('The account for this goal no longer exists.');
            }

            const [savedRows] = await connection.query(
                'SELECT COUNT(*) AS count FROM user_growth_goals WHERE user_id = ?',
                [userId]
            );
            if (Number(savedRows[0]?.count) >= MAX_SAVED_GOALS) {
                invalid(`You can keep up to ${MAX_SAVED_GOALS} saved goals. Delete one to add another.`);
            }
            const id = crypto.randomUUID();
            await connection.query(
                'INSERT INTO user_growth_goals (id, user_id, title, dimension, target_tasks, due_date, reminder_enabled, progress_metric) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                [id, userId, goal.title, goal.dimension, goal.targetTasks, goal.dueDate, goal.reminderEnabled ? 1 : 0, goal.progressMetric]
            );
            if (transactionStarted) {
                await connection.commit();
                transactionStarted = false;
            }
            return { id, ...goal, completedTasks: 0, activeDays: 0, progressValue: 0, isComplete: false, isOverdue: false };
        } catch (error) {
            if (transactionStarted) await connection.rollback().catch(() => {});
            throw error;
        } finally {
            if (ownsConnection) connection.release();
        }
    }

    async list(userId, executor = db, now = new Date()) {
        const [rows] = await executor.query(`
            SELECT
                goal.id,
                goal.title,
                goal.dimension,
                goal.target_tasks AS targetTasks,
                DATE_FORMAT(goal.due_date, '%Y-%m-%d') AS dueDate,
                goal.reminder_enabled AS reminderEnabled,
                goal.progress_metric AS progressMetric,
                goal.created_at AS createdAt,
                (
                    SELECT COUNT(*)
                    FROM user_activity_logs AS activity
                    WHERE activity.user_id = goal.user_id
                      AND LOWER(activity.dimension) = goal.dimension
                      AND activity.action_type = 'TASK_COMPLETED'
                      AND activity.created_at >= goal.created_at
                      AND activity.created_at < DATE_ADD(goal.due_date, INTERVAL 1 DAY)
                ) AS completedTasks,
                (
                    SELECT COUNT(DISTINCT DATE(activity.created_at))
                    FROM user_activity_logs AS activity
                    WHERE activity.user_id = goal.user_id
                      AND LOWER(activity.dimension) = goal.dimension
                      AND activity.action_type = 'TASK_COMPLETED'
                      AND activity.created_at >= goal.created_at
                      AND activity.created_at < DATE_ADD(goal.due_date, INTERVAL 1 DAY)
                ) AS activeDays
            FROM user_growth_goals AS goal
            WHERE goal.user_id = ?
            ORDER BY goal.due_date ASC, goal.created_at DESC
        `, [userId]);

        const today = now.toISOString().slice(0, 10);
        return rows.map(row => {
            const targetTasks = Number(row.targetTasks) || 1;
            const completedTasks = Number(row.completedTasks) || 0;
            const activeDays = Number(row.activeDays) || 0;
            const progressMetric = row.progressMetric === 'active_days' ? 'active_days' : 'tasks';
            const progressValue = progressMetric === 'active_days' ? activeDays : completedTasks;
            const isComplete = progressValue >= targetTasks;
            const dueDate = String(row.dueDate).slice(0, 10);
            return {
                ...row,
                targetTasks,
                reminderEnabled: Boolean(Number(row.reminderEnabled)),
                progressMetric,
                completedTasks,
                activeDays,
                progressValue,
                isComplete,
                isOverdue: !isComplete && dueDate < today
            };
        });
    }

    async update(userId, goalId, input, executor = db, now = new Date()) {
        if (!userId || !goalId) invalid('A valid user and goal are required.');
        const [existingRows] = await executor.query(
            `SELECT DATE_FORMAT(due_date, '%Y-%m-%d') AS dueDate
             FROM user_growth_goals WHERE id = ? AND user_id = ? LIMIT 1`,
            [goalId, userId]
        );
        if (existingRows.length === 0) return null;
        const keepExistingDueDate = String(input?.dueDate || '') ===
            String(existingRows[0].dueDate).slice(0, 10);
        const goal = validateGoal(input, now, { allowPastDueDate: keepExistingDueDate });
        await executor.query(
            `UPDATE user_growth_goals
             SET title = ?, dimension = ?, target_tasks = ?, due_date = ?, reminder_enabled = ?, progress_metric = ?
             WHERE id = ? AND user_id = ?`,
            [goal.title, goal.dimension, goal.targetTasks, goal.dueDate, goal.reminderEnabled ? 1 : 0, goal.progressMetric, goalId, userId]
        );
        const [rows] = await executor.query(
            `SELECT id, title, dimension, target_tasks AS targetTasks,
                    DATE_FORMAT(due_date, '%Y-%m-%d') AS dueDate,
                    reminder_enabled AS reminderEnabled,
                    progress_metric AS progressMetric
             FROM user_growth_goals WHERE id = ? AND user_id = ? LIMIT 1`,
            [goalId, userId]
        );
        if (rows.length === 0) return null;
        return {
            ...rows[0],
            targetTasks: Number(rows[0].targetTasks),
            reminderEnabled: Boolean(Number(rows[0].reminderEnabled)),
            ...goal
        };
    }

    async remove(userId, goalId, executor = db) {
        if (!userId || !goalId) invalid('A valid user and goal are required.');
        const [result] = await executor.query(
            'DELETE FROM user_growth_goals WHERE id = ? AND user_id = ?',
            [goalId, userId]
        );
        return Number(result.affectedRows) > 0;
    }
}

module.exports = new GrowthGoalService();
