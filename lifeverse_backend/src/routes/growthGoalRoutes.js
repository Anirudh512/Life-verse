const express = require('express');
const growthGoalController = require('../controllers/growthGoalController');
const { requireAuth, requireBodyUser, requireParamUser } = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/:userId', requireAuth, requireParamUser(), growthGoalController.list);
router.post('/', requireAuth, requireBodyUser(), growthGoalController.create);
router.put('/:userId/:goalId', requireAuth, requireParamUser(), growthGoalController.update);
router.delete('/:userId/:goalId', requireAuth, requireParamUser(), growthGoalController.remove);

module.exports = router;
