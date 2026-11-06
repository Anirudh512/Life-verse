const { db } = require('../config/db');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const sessionService = require('../services/sessionService');
const { UPLOAD_DIR } = require('../middleware/uploadMiddleware');
const {
    hashSecret,
    verifySecret,
    isHashedSecret,
    normalizeSecurityAnswer
} = require('../utils/credentials');

class AuthController {

    async register(req, res) {
        try {
            const { email, password, username, fullName, securityQuestion, securityAnswer } = req.body;
            const normalizedEmail = String(email || '').trim().toLowerCase();
            const normalizedUsername = String(username || '').trim();
            const normalizedFullName = String(fullName || '').trim();
            const normalizedQuestion = String(securityQuestion || '').trim();
            const normalizedAnswer = normalizeSecurityAnswer(securityAnswer);

            if (!normalizedEmail || !password || !normalizedUsername || !normalizedFullName || !normalizedQuestion || !normalizedAnswer) {
                return res.status(400).json({ success: false, message: 'All fields are required.' });
            }

            if (typeof password !== 'string' || password.trim().length < 12 || password.length > 128) {
                return res.status(400).json({ success: false, message: 'Password must be 12 to 128 characters.' });
            }

            const [existing] = await db.query('SELECT * FROM users WHERE username = ? OR email = ?', [normalizedUsername, normalizedEmail]);
            if (existing.length > 0) {
                return res.status(400).json({ success: false, message: 'Username or Email already taken.' });
            }

            const userId = crypto.randomUUID();
            const qrHash = crypto.createHash('sha256').update(userId + normalizedUsername + Date.now().toString()).digest('hex');
            const passwordHash = await hashSecret(password);
            const securityAnswerHash = await hashSecret(normalizedAnswer);

            await db.query(
                'INSERT INTO users (id, email, username, full_name, password, qr_hash, security_question, security_answer) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                [userId, normalizedEmail, normalizedUsername, normalizedFullName, passwordHash, qrHash, normalizedQuestion, securityAnswerHash]
            );

            // Initialize server-side app state (non-fatal if table missing)
            try {
                await sessionService.saveAppState(userId, {
                    onboardingComplete: false,
                    lastRoute: '/home',
                    theme: 'dark'
                });
            } catch (stateErr) {
                console.warn('[AuthController] App state init skipped:', stateErr.message);
            }

            res.json({ success: true, userId, message: 'Account created successfully! You can now log in.' });
        } catch (error) {
            console.error('[AuthController] Register error:', error);
            let message = error.message || 'Registration failed.';
            if (error.code === 'ECONNREFUSED') {
                message = 'Cannot connect to MySQL. Start XAMPP MySQL and run: npm run init-db';
            } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
                message = 'MySQL login failed. Check DB_USER and DB_PASSWORD in .env';
            } else if (error.code === 'ER_BAD_DB_ERROR') {
                message = 'Database not found. Run: npm run init-db';
            }
            res.status(500).json({ success: false, message });
        }
    }

    async login(req, res) {
        try {
            const { email, password, deviceInfo } = req.body;
            const normalizedEmail = String(email || '').trim().toLowerCase();

            if (!normalizedEmail || !password) {
                return res.status(400).json({ success: false, message: 'Email and password required.' });
            }

            const [rows] = await db.query('SELECT * FROM users WHERE email = ? LIMIT 1', [normalizedEmail]);

            if (rows.length === 0) {
                return res.status(401).json({ success: false, message: 'Email or password is incorrect.' });
            }

            const user = rows[0];

            const passwordMatches = await verifySecret(password, user.password);
            if (!passwordMatches) {
                return res.status(401).json({ success: false, message: 'Email or password is incorrect.' });
            }

            if (!isHashedSecret(user.password)) {
                await db.query('UPDATE users SET password = ? WHERE id = ?', [await hashSecret(password), user.id]);
            }

            let session;
            try {
                session = await sessionService.createSession(user.id, deviceInfo || {});
            } catch (sessionErr) {
                console.error('[AuthController] Session create error:', sessionErr);
                return res.status(500).json({
                    success: false,
                    message: 'Could not create session. Run: npm run init-db in lifeverse_backend folder.'
                });
            }

            res.json({
                success: true,
                userId: user.id,
                username: user.username,
                fullName: user.full_name,
                email: user.email,
                sessionToken: session.sessionToken,
                expiresAt: session.expiresAt,
                message: 'Login successful!'
            });
        } catch (error) {
            console.error('[AuthController] Login error:', error);
            res.status(500).json({ success: false, message: error.message });
        }
    }

    async validateSession(req, res) {
        try {
            const token = req.headers.authorization?.replace('Bearer ', '') || req.body.sessionToken;

            const session = await sessionService.validateSession(token);

            if (!session) {
                return res.status(401).json({ success: false, message: 'Session expired. Please log in again.' });
            }

            const appState = await sessionService.getAppState(session.userId);

            res.json({
                success: true,
                userId: session.userId,
                username: session.username,
                fullName: session.fullName,
                email: session.email,
                expiresAt: session.expiresAt,
                appState
            });
        } catch (error) {
            console.error('[AuthController] validateSession error:', error);
            res.status(500).json({ success: false, message: error.message });
        }
    }

    async logout(req, res) {
        try {
            const token = req.headers.authorization?.replace('Bearer ', '') || req.body.sessionToken;
            await sessionService.destroySession(token);
            res.json({ success: true, message: 'Logged out successfully.' });
        } catch (error) {
            console.error('[AuthController] logout error:', error);
            res.status(500).json({ success: false, message: error.message });
        }
    }

    async getAppState(req, res) {
        try {
            const { userId } = req.params;
            const state = await sessionService.getAppState(userId);
            res.json({ success: true, state });
        } catch (error) {
            res.status(500).json({ success: false, message: error.message });
        }
    }

    async saveAppState(req, res) {
        try {
            const { userId } = req.params;
            const { state } = req.body;
            const saved = await sessionService.mergeAppState(userId, state);
            res.json({ success: true, state: saved });
        } catch (error) {
            res.status(500).json({ success: false, message: error.message });
        }
    }

    async deleteAccount(req, res) {
        const userId = String(req.body?.userId || '');
        const password = req.body?.password;
        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required.' });
        }
        if (typeof password !== 'string' || password.length === 0 || password.length > 128) {
            return res.status(400).json({ success: false, message: 'Enter your current password to delete this account.' });
        }

        let connection;
        let transactionStarted = false;
        let committed = false;
        let mediaNames = [];
        try {
            connection = await db.getConnection();
            await connection.beginTransaction();
            transactionStarted = true;

            const [users] = await connection.query(
                'SELECT id, username, password FROM users WHERE id = ? LIMIT 1 FOR UPDATE',
                [userId]
            );
            if (users.length === 0) {
                await connection.rollback();
                transactionStarted = false;
                return res.status(404).json({ success: false, message: 'Account not found.' });
            }
            if (!(await verifySecret(password, users[0].password))) {
                await connection.rollback();
                transactionStarted = false;
                return res.status(401).json({ success: false, message: 'Current password is incorrect.' });
            }

            const [mediaRows] = await connection.query(`
                SELECT cm.stored_name
                FROM capsule_media cm
                JOIN time_capsules tc ON tc.id = cm.capsule_id
                WHERE tc.user_id = ?
            `, [userId]);
            mediaNames = mediaRows.map(row => row.stored_name).filter(name => typeof name === 'string');

            // This table has no foreign keys, so clear acknowledgements before
            // the user's capsules and account rows are removed.
            await connection.query(`
                DELETE FROM capsule_delivery_acknowledgements
                WHERE user_id = ? OR capsule_id IN (SELECT id FROM time_capsules WHERE user_id = ?)
            `, [userId, userId]);

            // Keep other users' capsules intact while removing links to the
            // account being deleted.
            await connection.query(
                'UPDATE time_capsules SET recipient_user_id = NULL WHERE recipient_user_id = ?',
                [userId]
            );
            const normalizedUsername = String(users[0].username || '').trim().replace(/^@/, '').toLowerCase();
            if (normalizedUsername) {
                await connection.query(`
                    UPDATE time_capsules
                    SET contributors = JSON_REMOVE(
                        contributors,
                        JSON_UNQUOTE(JSON_SEARCH(contributors, 'one', ?, NULL, '$[*]'))
                    )
                    WHERE contributors IS NOT NULL
                      AND JSON_SEARCH(contributors, 'one', ?, NULL, '$[*]') IS NOT NULL
                `, [normalizedUsername, normalizedUsername]);
            }

            // User-owned tables and capsule media metadata use ON DELETE CASCADE.
            await connection.query('DELETE FROM users WHERE id = ?', [userId]);
            await connection.commit();
            transactionStarted = false;
            committed = true;
        } catch (error) {
            if (transactionStarted) await connection.rollback().catch(() => {});
            console.error('[AuthController] Account deletion failed:', error.message);
            return res.status(500).json({ success: false, message: 'Account deletion failed. Please try again.' });
        } finally {
            connection?.release();
        }

        if (!committed) return;

        const uploadRoot = path.resolve(UPLOAD_DIR);
        let mediaCleanupComplete = true;
        for (const storedName of mediaNames) {
            const safeName = path.basename(storedName);
            if (!safeName || safeName !== storedName) {
                mediaCleanupComplete = false;
                continue;
            }
            const mediaPath = path.resolve(uploadRoot, safeName);
            if (!mediaPath.startsWith(`${uploadRoot}${path.sep}`)) {
                mediaCleanupComplete = false;
                continue;
            }
            try {
                await fs.promises.unlink(mediaPath);
            } catch (error) {
                if (error.code !== 'ENOENT') mediaCleanupComplete = false;
            }
        }

        if (!mediaCleanupComplete) {
            console.warn('[AuthController] Account deleted, but some capsule files need storage cleanup.');
        }
        return res.json({ success: true, mediaCleanupComplete, message: 'Account and personal data deleted.' });
    }

    async verifyEmail(req, res) {
        return res.status(410).json({
            success: false,
            message: 'This recovery step is retired. Use the password recovery form.'
        });
    }

    async verifySecurity(req, res) {
        return res.status(410).json({
            success: false,
            message: 'This recovery step is retired. Use the password recovery form.'
        });
    }

    async recover(req, res) {
        try {
            const { email, username, securityAnswer, newPassword } = req.body;
            const normalizedEmail = String(email || '').trim().toLowerCase();
            const normalizedUsername = String(username || '').trim();
            const normalizedAnswer = normalizeSecurityAnswer(securityAnswer);

            if (!normalizedEmail || !normalizedUsername || !normalizedAnswer || !newPassword) {
                return res.status(400).json({ success: false, message: 'All fields are required.' });
            }

            if (typeof newPassword !== 'string' || newPassword.trim().length < 12 || newPassword.length > 128) {
                return res.status(400).json({ success: false, message: 'Password must be 12 to 128 characters.' });
            }

            const [rows] = await db.query(
                'SELECT id, username, security_answer FROM users WHERE email = ? LIMIT 1',
                [normalizedEmail]
            );

            if (rows.length === 0) return this._invalidRecoveryResponse(res);

            const user = rows[0];

            if (user.username.toLowerCase() !== normalizedUsername.toLowerCase()) {
                return this._invalidRecoveryResponse(res);
            }

            const answerMatches = await verifySecret(normalizedAnswer, user.security_answer);
            if (!answerMatches) {
                return this._invalidRecoveryResponse(res);
            }

            const passwordHash = await hashSecret(newPassword);
            const connection = await db.getConnection();
            try {
                await connection.beginTransaction();
                if (!isHashedSecret(user.security_answer)) {
                    await connection.query(
                        'UPDATE users SET password = ?, security_answer = ? WHERE email = ?',
                        [passwordHash, await hashSecret(normalizedAnswer), normalizedEmail]
                    );
                } else {
                    await connection.query('UPDATE users SET password = ? WHERE email = ?', [passwordHash, normalizedEmail]);
                }
                await sessionService.destroyAllUserSessions(user.id, connection);
                await connection.commit();
            } catch (error) {
                await connection.rollback().catch(() => {});
                throw error;
            } finally {
                connection.release();
            }

            res.json({ success: true, message: 'Password reset successful!' });
        } catch (error) {
            console.error('[AuthController] Recover error:', error);
            res.status(500).json({ success: false, message: 'Password recovery is temporarily unavailable.' });
        }
    }

    _invalidRecoveryResponse(res) {
        return res.status(401).json({
            success: false,
            message: 'Unable to reset the password with the supplied details.'
        });
    }

    async getProfile(req, res) {
        try {
            const { userId } = req.params;

            if (!userId) {
                return res.status(400).json({ success: false, message: 'User ID is required.' });
            }

            const [rows] = await db.query('SELECT id, email, username, full_name, qr_hash, photo_url, created_at FROM users WHERE id = ? LIMIT 1', [userId]);

            if (rows.length === 0) {
                return res.status(404).json({ success: false, message: 'Profile not found.' });
            }

            const user = rows[0];

            res.json({
                success: true,
                profile: {
                    fullName: user.full_name,
                    username: user.username,
                    email: user.email,
                    qrHash: user.qr_hash,
                    photoUrl: user.photo_url,
                    createdAt: user.created_at
                }
            });
        } catch (error) {
            console.error('[AuthController] getProfile error:', error.message);
            res.status(500).json({ success: false, message: 'Profile is unavailable right now.' });
        }
    }

    async updateProfile(req, res) {
        const userId = String(req.user?.userId || '');
        const fullName = String(req.body?.fullName || '').trim();
        const username = String(req.body?.username || '').trim();
        if (!userId) return res.status(401).json({ success: false, message: 'Sign in to update your profile.' });
        if (fullName.length < 1 || fullName.length > 100) {
            return res.status(400).json({ success: false, message: 'Display name must contain 1 to 100 characters.' });
        }
        if (!/^[A-Za-z0-9_.-]{3,30}$/.test(username)) {
            return res.status(400).json({ success: false, message: 'Username must be 3 to 30 characters using letters, numbers, dots, dashes, or underscores.' });
        }
        try {
            const [existing] = await db.query('SELECT id FROM users WHERE username = ? AND id <> ? LIMIT 1', [username, userId]);
            if (existing.length) return res.status(409).json({ success: false, message: 'That username is already in use.' });
            await db.query('UPDATE users SET full_name = ?, username = ? WHERE id = ?', [fullName, username, userId]);
            const [rows] = await db.query('SELECT full_name, username FROM users WHERE id = ? LIMIT 1', [userId]);
            if (!rows.length) return res.status(404).json({ success: false, message: 'Profile not found.' });
            return res.json({ success: true, profile: { fullName: rows[0].full_name, username: rows[0].username } });
        } catch (error) {
            if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ success: false, message: 'That username is already in use.' });
            console.error('[AuthController] updateProfile error:', error.message);
            return res.status(500).json({ success: false, message: 'Profile could not be saved.' });
        }
    }
}

module.exports = new AuthController();
