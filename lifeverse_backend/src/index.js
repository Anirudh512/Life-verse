const path = require('path');
const fs = require('fs');
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

// Load environment variables FIRST before requiring any local modules that depend on them (like db.js)
dotenv.config();

const { requireAuth, requireBodyUser, requireParamUser, attachAuthenticatedUser } = require('./middleware/authMiddleware');

const app = express();
if (process.env.NODE_ENV === 'production') app.set('trust proxy', 1);

const { createRateLimiter } = require('./middleware/rateLimitMiddleware');
const loginRateLimit = createRateLimiter({ windowMs: 15 * 60 * 1000, max: 10, message: 'Too many sign-in attempts. Try again in 15 minutes.' });
const recoveryRateLimit = createRateLimiter({ windowMs: 15 * 60 * 1000, max: 5, message: 'Too many recovery attempts. Try again in 15 minutes.' });
const registrationRateLimit = createRateLimiter({ windowMs: 15 * 60 * 1000, max: 5, message: 'Too many account creation attempts. Try again later.' });

// CORS â€” allow Flutter app + Render production frontend
const allowedOrigins = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : ['*'];

app.use(cors({
    origin: allowedOrigins.includes('*') ? true : allowedOrigins,
    credentials: true
}));
app.use(express.json({ limit: '2mb' }));

const { lifeEventEngine } = require('./core/lifeEventEngine');
const authController = require('./controllers/authController');
const analyticsController = require('./controllers/analyticsController');
const friendController = require('./controllers/friendController');
const hdeController = require('./controllers/hdeController');
const { timeCapsuleController, uploadMiddleware } = require('./controllers/timeCapsuleController');
const legacyController = require('./controllers/legacyController');
const digitalTwinController = require('./controllers/digitalTwinController');
const futureSimController = require('./controllers/futureSimController');

app.get('/health', async (req, res) => {
    try {
        const { db } = require('./config/db');
        await db.query('SELECT 1');
        res.json({
            status: 'OK',
            message: 'LifeVerse Backend and database are ready.',
            environment: process.env.NODE_ENV || 'development'
        });
    } catch (error) {
        res.status(503).json({ status: 'UNAVAILABLE', message: 'Database is not ready.' });
    }
});

// Auth Routes
app.post('/api/auth/register', registrationRateLimit, authController.register);
app.post('/api/auth/login', loginRateLimit, authController.login);
app.post('/api/auth/logout', authController.logout);
app.post('/api/auth/session/validate', authController.validateSession);
app.get('/api/auth/session/validate', authController.validateSession);
app.post('/api/auth/recover', recoveryRateLimit, authController.recover);
app.post('/api/auth/account/delete', requireAuth, requireBodyUser(), authController.deleteAccount);
app.post('/api/auth/verify-email', recoveryRateLimit, authController.verifyEmail);
app.post('/api/auth/verify-security', recoveryRateLimit, authController.verifySecurity);
app.get('/api/auth/profile/:userId', requireAuth, requireParamUser(), authController.getProfile);
app.put('/api/auth/profile/:userId', requireAuth, requireParamUser(), authController.updateProfile);
app.get('/api/auth/app-state/:userId', requireAuth, requireParamUser(), authController.getAppState);
app.put('/api/auth/app-state/:userId', requireAuth, requireParamUser(), authController.saveAppState);

// Analytics Routes
app.get('/api/analytics/xp/:userId', requireAuth, requireParamUser(), analyticsController.getXP);
app.get('/api/analytics/progress/:userId', requireAuth, requireParamUser(), analyticsController.getProgress);
app.post('/api/analytics/visit', requireAuth, analyticsController.recordVisit);
app.use('/api/growth-goals', require('./routes/growthGoalRoutes'));

// Friend Routes
app.post('/api/friends/request', requireAuth, requireBodyUser('senderId'), friendController.sendRequest);
app.post('/api/friends/accept', requireAuth, requireBodyUser('receiverId'), friendController.acceptRequest);
app.get('/api/friends/list/:userId', requireAuth, requireParamUser(), friendController.getFriendsAndRequests);
app.get('/api/friends/profile/:friendId', requireAuth, friendController.getFriendProfile);

// Butterfly Effect Routes
app.use('/api/butterfly', require('./routes/butterflyRoutes'));

// Human Development Engine Routes
app.post('/api/hde/tasks', requireAuth, requireBodyUser(), hdeController.generateDailyTasks);
app.get('/api/hde/stats/:userId', requireAuth, requireParamUser(), hdeController.getStats);
app.post('/api/hde/log', requireAuth, requireBodyUser(), hdeController.logActivity);
app.post('/api/hde/tasks/complete', requireAuth, requireBodyUser(), hdeController.completeDailyTask);
app.post('/api/hde/survey/submit', requireAuth, requireBodyUser(), hdeController.submitSurvey);

// Time Capsule Routes
app.post('/api/capsules/create', requireAuth, uploadMiddleware, attachAuthenticatedUser(), timeCapsuleController.createCapsule);
app.post('/api/capsules', requireAuth, attachAuthenticatedUser(), timeCapsuleController.createCapsule); // legacy JSON-only
app.get('/api/capsules/pending/:userId', requireAuth, requireParamUser(), timeCapsuleController.getPendingDeliveries);
app.get('/api/capsules/detail/:capsuleId/:userId', requireAuth, requireParamUser(), timeCapsuleController.getCapsule);
app.get('/api/capsules/lookup/:username', requireAuth, timeCapsuleController.lookupFriend);
app.post('/api/capsules/delivered', requireAuth, timeCapsuleController.markDelivered);
app.get('/api/capsules/:userId', requireAuth, requireParamUser(), timeCapsuleController.getAllCapsules);
app.get('/api/capsules/status/:userId', requireAuth, requireParamUser(), timeCapsuleController.checkStatus);
app.post('/api/capsules/open', requireAuth, requireBodyUser(), timeCapsuleController.openCapsule);
app.get('/uploads/capsules/:filename', requireAuth, timeCapsuleController.streamCapsuleMedia);

// Legacy Routes
app.post('/api/legacy/event', requireAuth, requireBodyUser(), legacyController.addEvent);
app.get('/api/legacy/timeline/:userId', requireAuth, requireParamUser(), legacyController.getTimeline);
app.post('/api/legacy/biography', requireAuth, requireBodyUser(), legacyController.generateAIBiography);
app.put('/api/legacy/biography', requireAuth, requireBodyUser(), legacyController.saveAIBiography);

// Digital Twin Routes
app.get('/api/twin/profile/:userId', requireAuth, requireParamUser(), digitalTwinController.getProfile);
app.post('/api/twin/mirror', requireAuth, requireBodyUser(), digitalTwinController.generateMirrorQuestion);
app.get('/api/twin/history/:userId', requireAuth, requireParamUser(), digitalTwinController.getConversationHistory);
app.get('/api/twin/memories/:userId', requireAuth, requireParamUser(), digitalTwinController.getSavedMemories);
app.delete('/api/twin/memories/:userId/:memoryId', requireAuth, requireParamUser(), digitalTwinController.deleteSavedMemory);
app.delete('/api/twin/history/:userId', requireAuth, requireParamUser(), digitalTwinController.clearConversationHistory);
app.post('/api/twin/chat_twin', requireAuth, requireBodyUser(), digitalTwinController.chatWithTwin);

// Future Simulation Routes
app.get('/api/future/status/:userId', requireAuth, requireParamUser(), futureSimController.getUnlockStatus);
app.get('/api/future/latest/:userId', requireAuth, requireParamUser(), futureSimController.getLatestSimulation);
app.post('/api/future/simulate', requireAuth, requireBodyUser(), futureSimController.simulateFuture);
app.post('/api/future/feedback', requireAuth, requireBodyUser(), futureSimController.saveFeedback);
app.post('/api/future/commit', requireAuth, requireBodyUser(), futureSimController.commitRecommendation);

// Central nervous system — all life events
app.post('/api/events', requireAuth, (req, res) => {
    res.status(410).json({ success: false, message: 'Generic life events are disabled. Use the specific action endpoint.' });
});

// A release container can serve the Flutter Web build and API from one origin.
// Local API-only setups keep working when no web build directory is present.
const webBuildDir = path.resolve(
    process.env.WEB_BUILD_DIR || path.join(__dirname, '../../lifeverse_app/build/web')
);
if (fs.existsSync(path.join(webBuildDir, 'index.html'))) {
    app.use(express.static(webBuildDir, {
        maxAge: process.env.NODE_ENV === 'production' ? '1h' : 0,
        setHeaders: (response, filePath) => {
            if (path.basename(filePath) === 'index.html') {
                response.setHeader('Cache-Control', 'no-cache');
            }
        }
    }));
    app.use((req, res, next) => {
        const isReservedPath = req.path === '/health' || req.path === '/api' ||
            req.path.startsWith('/api/') || req.path === '/uploads' ||
            req.path.startsWith('/uploads/');
        if (req.method !== 'GET' || isReservedPath || !req.accepts('html')) {
            return next();
        }
        res.sendFile('index.html', { root: webBuildDir }, error => {
            if (error) next(error);
        });
    });
}

// Global Error Handler to catch Multer and other errors gracefully as JSON
app.use((err, req, res, next) => {
    console.error('Unhandled Error:', err.message);
    const status = err.statusCode || (String(err.code || '').startsWith('LIMIT_') ? 413 : 500);
    res.status(status).json({ success: false, message: err.message || 'Server error' });
});

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

async function startServer() {
    try {
        const { db } = require('./config/db');
        await db.query('SELECT 1');
        console.log(`MySQL connected (${process.env.DB_HOST || 'localhost'}:${process.env.DB_PORT || 3306}/${process.env.DB_NAME || 'lifeverse'})`);
    } catch (dbErr) {
        console.error('❌ MySQL connection failed:', dbErr.message);
        console.error('   Fix: check .env DB settings, start XAMPP MySQL, run: npm run init-db');
    }

    app.listen(PORT, HOST, () => {
        console.log(`LifeVerse Core running on ${HOST}:${PORT}`);
        console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    });
}

if (require.main === module) {
    startServer();
}

module.exports = { app, startServer };
