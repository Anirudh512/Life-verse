const sessionService = require('../services/sessionService');

/**
 * Validates session token from Authorization header or body.
 * Attaches req.user = { userId, email, username, fullName }
 */
async function requireAuth(req, res, next) {
    try {
        const header = req.headers.authorization || '';
        const token = header.startsWith('Bearer ')
            ? header.slice(7)
            : req.body?.sessionToken;

        const session = await sessionService.validateSession(token);

        if (!session) {
            return res.status(401).json({ success: false, message: 'Session expired or invalid. Please log in again.' });
        }

        req.user = session;
        req.sessionToken = token;
        next();
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
}

/**
 * Optional auth — attaches user if token present, continues either way.
 */
async function optionalAuth(req, res, next) {
    try {
        const header = req.headers.authorization || '';
        const token = header.startsWith('Bearer ')
            ? header.slice(7)
            : req.body?.sessionToken;

        if (token) {
            const session = await sessionService.validateSession(token);
            if (session) {
                req.user = session;
                req.sessionToken = token;
            }
        }
        next();
    } catch (_) {
        next();
    }
}

function requireBodyUser(field = 'userId') {
    return requireMatchingUser('body', field);
}

function requireParamUser(field = 'userId') {
    return requireMatchingUser('params', field);
}

function requireMatchingUser(source, field) {
    return (req, res, next) => {
        const requestedUserId = req[source]?.[field];

        if (!requestedUserId) {
            return res.status(400).json({ success: false, message: `${field} is required.` });
        }

        if (!req.user || String(req.user.userId) !== String(requestedUserId)) {
            return res.status(403).json({ success: false, message: 'You can only access your own LifeVerse data.' });
        }

        next();
    };
}

function attachAuthenticatedUser(field = 'userId') {
    return (req, res, next) => {
        if (!req.body || typeof req.body !== 'object') {
            req.body = {};
        }
        if (req.user?.userId) {
            req.body[field] = req.user.userId;
        }
        next();
    };
}

module.exports = {
    requireAuth,
    optionalAuth,
    requireBodyUser,
    requireParamUser,
    attachAuthenticatedUser
};
