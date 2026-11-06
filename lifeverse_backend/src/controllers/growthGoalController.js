const growthGoalService = require('../services/growthGoalService');

class GrowthGoalController {
    async list(req, res) {
        try {
            const goals = await growthGoalService.list(req.params.userId);
            return res.json({ success: true, goals });
        } catch (error) {
            console.error('[GrowthGoalController] Error listing goals:', error);
            return res.status(500).json({ success: false, message: 'Could not load goals.' });
        }
    }

    async create(req, res) {
        try {
            const goal = await growthGoalService.create(req.body.userId, req.body);
            return res.status(201).json({ success: true, goal });
        } catch (error) {
            const status = error.statusCode || 500;
            if (status === 500) console.error('[GrowthGoalController] Error creating goal:', error);
            return res.status(status).json({
                success: false,
                message: status === 400 ? error.message : 'Could not save this goal.'
            });
        }
    }

    async update(req, res) {
        try {
            const goal = await growthGoalService.update(
                req.params.userId,
                req.params.goalId,
                req.body
            );
            if (!goal) return res.status(404).json({ success: false, message: 'Goal not found.' });
            return res.json({ success: true, goal });
        } catch (error) {
            const status = error.statusCode || 500;
            if (status === 500) console.error('[GrowthGoalController] Error updating goal:', error);
            return res.status(status).json({
                success: false,
                message: status === 400 ? error.message : 'Could not update this goal.'
            });
        }
    }

    async remove(req, res) {
        try {
            const removed = await growthGoalService.remove(req.params.userId, req.params.goalId);
            if (!removed) return res.status(404).json({ success: false, message: 'Goal not found.' });
            return res.json({ success: true });
        } catch (error) {
            console.error('[GrowthGoalController] Error deleting goal:', error);
            return res.status(500).json({ success: false, message: 'Could not delete this goal.' });
        }
    }
}

module.exports = new GrowthGoalController();
