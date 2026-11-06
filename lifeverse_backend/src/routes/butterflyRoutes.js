const express = require('express');
const router = express.Router();
const butterflyController = require('../controllers/butterflyController');
const { requireAuth, requireBodyUser, requireParamUser } = require('../middleware/authMiddleware');

router.post('/log', requireAuth, requireBodyUser(), butterflyController.logMicroDecision);
router.get('/analysis/:userId', requireAuth, requireParamUser(), butterflyController.getButterflyEffectAnalysis);

module.exports = router;
