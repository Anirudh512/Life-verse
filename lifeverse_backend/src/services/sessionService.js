const { db } = require('../config/db');
const crypto = require('crypto');
const { parseJsonObject } = require('../utils/json');

const SESSION_DAYS = 30;

class SessionService {

    hashToken(sessionToken) {
        return crypto.createHash('sha256').update(sessionToken).digest('hex');
    }

    generateToken() {
        return crypto.randomBytes(48).toString('hex');
    }

    async createSession(userId, deviceInfo = {}) {
        const token = this.generateToken();
        const tokenHash = this.hashToken(token);
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + SESSION_DAYS);

        await db.query(
            `INSERT INTO user_sessions (id, user_id, session_token, device_info, expires_at, last_active)
             VALUES (?, ?, ?, ?, ?, NOW())`,
            [crypto.randomUUID(), userId, tokenHash, JSON.stringify(deviceInfo), expiresAt]
        );

        return { sessionToken: token, expiresAt };
    }

    async validateSession(sessionToken) {
        if (!sessionToken) return null;

        const tokenHash = this.hashToken(sessionToken);
        const [rows] = await db.query(`
            SELECT s.id, s.session_token, s.user_id, s.expires_at, u.email, u.username, u.full_name
            FROM user_sessions s
            JOIN users u ON u.id = s.user_id
            WHERE s.session_token IN (?, ?) AND s.is_active = 1 AND s.expires_at > NOW()
            LIMIT 1
        `, [tokenHash, sessionToken]);

        if (rows.length === 0) return null;

        // Upgrade sessions created by older builds that stored bearer tokens in plaintext.
        if (rows[0].session_token === sessionToken) {
            await db.query('UPDATE user_sessions SET session_token = ? WHERE id = ?', [tokenHash, rows[0].id]);
        }
        await db.query('UPDATE user_sessions SET last_active = NOW() WHERE id = ?', [rows[0].id]);

        return {
            userId: rows[0].user_id,
            email: rows[0].email,
            username: rows[0].username,
            fullName: rows[0].full_name,
            expiresAt: rows[0].expires_at
        };
    }

    async destroySession(sessionToken) {
        if (!sessionToken) return;
        const tokenHash = this.hashToken(sessionToken);
        await db.query(
            'UPDATE user_sessions SET is_active = 0 WHERE session_token IN (?, ?)',
            [tokenHash, sessionToken]
        );
    }

    async destroyAllUserSessions(userId, executor = db) {
        await executor.query(
            'UPDATE user_sessions SET is_active = 0 WHERE user_id = ?',
            [userId]
        );
    }

    async getAppState(userId) {
        const [rows] = await db.query(
            'SELECT state_json FROM user_app_state WHERE user_id = ? LIMIT 1',
            [userId]
        );
        if (rows.length === 0) return {};
        return parseJsonObject(rows[0].state_json);
    }

    async saveAppState(userId, state) {
        const safeState = parseJsonObject(state);
        await db.query(`
            INSERT INTO user_app_state (user_id, state_json, updated_at)
            VALUES (?, ?, NOW())
            ON DUPLICATE KEY UPDATE state_json = ?, updated_at = NOW()
        `, [userId, JSON.stringify(safeState), JSON.stringify(safeState)]);
        return safeState;
    }

    async mergeAppState(userId, partialState) {
        const current = await this.getAppState(userId);
        const incoming = parseJsonObject(partialState);
        const merged = { ...current, ...incoming };
        return this.saveAppState(userId, merged);
    }
}

module.exports = new SessionService();
