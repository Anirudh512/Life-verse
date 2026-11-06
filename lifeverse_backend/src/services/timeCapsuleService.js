const { db } = require('../config/db');
const crypto = require('crypto');
const { MAX_FILE_SIZE } = require('../middleware/uploadMiddleware');
const { parseJsonArray } = require('../utils/json');

const MIN_UNLOCK_HOURS = 24;
const configuredUserStorageLimit = Number(process.env.USER_CAPSULE_STORAGE_LIMIT_BYTES);
const MAX_USER_CAPSULE_STORAGE_BYTES = Number.isSafeInteger(configuredUserStorageLimit) && configuredUserStorageLimit > 0
    ? configuredUserStorageLimit
    : 1024 * 1024 * 1024;

class TimeCapsuleService {
    _mapCapsuleRow(row, viewerId) {
        const isRecipient = row.recipient_user_id === viewerId;
        const openTime = new Date(row.open_date);
        const isReady = !Number.isNaN(openTime.getTime()) && openTime <= new Date();
        const isLocked = row.status === 'LOCKED' && !isReady;

        return {
            id: row.id,
            title: row.title,
            message: isLocked ? null : row.message,
            prediction: isLocked ? null : row.prediction,
            openDate: row.open_date,
            status: row.status,
            createdAt: row.created_at,
            capsuleType: row.capsule_type,
            themeStyle: row.theme_style,
            mediaTotalBytes: row.media_total_bytes || 0,
            mediaCount: row.media_count || 0,
            senderUserId: row.user_id,
            senderUsername: row.sender_username,
            recipientUserId: row.recipient_user_id,
            recipientUsername: row.recipient_username,
            isIncoming: isRecipient,
            isReady,
            isLocked,
            timeRemaining: isLocked ? this._formatTimeRemaining(row.open_date) : 'Ready to Open!',
            latitude: row.latitude,
            longitude: row.longitude,
            contributors: parseJsonArray(row.contributors),
        };
    }

    _formatTimeRemaining(openDate) {
        const diff = new Date(openDate) - new Date();
        if (diff <= 0) return 'Ready to Open!';
        const days = Math.floor(diff / (1000 * 60 * 60 * 24));
        const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        if (days > 0) return `Opens in ${days}d ${hours}h`;
        return `Opens in ${hours}h`;
    }

    async lookupUserByUsername(username) {
        if (!username || !String(username).trim()) return null;
        const [rows] = await db.query(
            'SELECT id, username, full_name FROM users WHERE username = ? LIMIT 1',
            [String(username).trim()]
        );
        return rows.length > 0 ? rows[0] : null;
    }

    async _getUsername(userId) {
        const [rows] = await db.query('SELECT username FROM users WHERE id = ? LIMIT 1', [userId]);
        return rows.length > 0 ? rows[0].username : null;
    }

    _calculateDistanceMeters(lat1, lon1, lat2, lon2) {
        const toRad = deg => (deg * Math.PI) / 180;
        const R = 6371000; // Earth's radius in meters
        const dLat = toRad(lat2 - lat1);
        const dLon = toRad(lon2 - lon1);
        const a =
            Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    _viewerCanAccess(row, viewerId, viewerUsername) {
        if (!viewerId) return false;
        if (row.user_id === viewerId || row.recipient_user_id === viewerId) return true;

        const contributors = parseJsonArray(row.contributors).map(value => String(value).trim().replace(/^@/, '').toLowerCase());
        const normalizedUsername = viewerUsername ? String(viewerUsername).trim().replace(/^@/, '').toLowerCase() : '';
        return Boolean(normalizedUsername && contributors.includes(normalizedUsername));
    }

    async createCapsule(senderId, data, files = [], executor = db) {
        const {
            message, openDate, title, prediction, themeStyle,
            capsuleType, recipientUsername, recipientUserId, idempotencyKey
        } = data;

        if (!senderId || !message || !openDate) {
            throw new Error('Message and unlock date are required');
        }

        const unlockTime = new Date(openDate);
        if (Number.isNaN(unlockTime.getTime())) {
            throw new Error('Unlock date is invalid');
        }

        const minTime = new Date(Date.now() + MIN_UNLOCK_HOURS * 60 * 60 * 1000);
        if (unlockTime < minTime) {
            throw new Error('Capsule must unlock at least 24 hours from now');
        }

        let recipientId = recipientUserId || null;
        if (capsuleType === 'friend') {
            if (!recipientUsername && !recipientId) {
                throw new Error('Friend username is required');
            }
            if (!recipientId) {
                const friend = await this.lookupUserByUsername(recipientUsername);
                if (!friend) throw new Error(`User @${recipientUsername} not found on LifeVerse`);
                if (friend.id === senderId) throw new Error('You cannot send a capsule to yourself');
                recipientId = friend.id;
            }
        }

        const totalBytes = files.reduce((sum, f) => sum + f.size, 0);
        if (totalBytes > MAX_FILE_SIZE) {
            throw new Error('Total media size exceeds 200MB limit');
        }
        if (totalBytes > 0) {
            const [usageRows] = await executor.query(
                'SELECT COALESCE(SUM(media_total_bytes), 0) AS used_bytes FROM time_capsules WHERE user_id = ?',
                [senderId]
            );
            const usedBytes = Number(usageRows[0]?.used_bytes) || 0;
            if (usedBytes + totalBytes > MAX_USER_CAPSULE_STORAGE_BYTES) {
                throw new Error('Your stored capsule media is at its account limit. Remove old media before adding more.');
            }
        }

        const normalizedContributors = (data.contributors || [])
            .map(c => String(c).trim().replace(/^@/, '').toLowerCase())
            .filter(Boolean);
        const uniqueContributors = [...new Set(normalizedContributors)];

        const capsuleId = crypto.randomUUID();
        const status = unlockTime > new Date() ? 'LOCKED' : 'OPENED';

        await executor.query(`
            INSERT INTO time_capsules
            (id, user_id, idempotency_key, recipient_user_id, title, message, prediction, open_date, status,
             capsule_type, theme_style, media_total_bytes, latitude, longitude, contributors)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `, [
            capsuleId, senderId, idempotencyKey || null, recipientId,
            title || 'A Memory Preserved', message, prediction || '',
            openDate, status, capsuleType || 'self', themeStyle || 'amber_gold', totalBytes,
            data.latitude, data.longitude, JSON.stringify(uniqueContributors)
        ]);

        for (const file of files) {
            const mediaId = crypto.randomUUID();
            const mediaType = this._detectMediaType(file.mimetype, file.originalname);
            await executor.query(`
                INSERT INTO capsule_media (id, capsule_id, file_name, stored_name, mime_type, file_size, media_type)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            `, [mediaId, capsuleId, file.originalname, file.filename, file.mimetype, file.size, mediaType]);
        }

        return capsuleId;
    }

    _detectMediaType(mime, filename) {
        if (mime?.startsWith('image/')) return 'image';
        if (mime?.startsWith('video/')) return 'video';
        if (mime?.startsWith('audio/')) return 'audio';
        return 'file';
    }

    async getCapsuleById(capsuleId, viewerId) {
        const [rows] = await db.query(`
            SELECT tc.*,
                   su.username as sender_username,
                   ru.username as recipient_username,
                   (SELECT COUNT(*) FROM capsule_media cm WHERE cm.capsule_id = tc.id) as media_count
            FROM time_capsules tc
            LEFT JOIN users su ON su.id = tc.user_id
            LEFT JOIN users ru ON ru.id = tc.recipient_user_id
            WHERE tc.id = ?
            LIMIT 1
        `, [capsuleId]);

        if (rows.length === 0) throw new Error('Capsule not found');

        const viewerUsername = await this._getUsername(viewerId);
        if (!this._viewerCanAccess(rows[0], viewerId, viewerUsername)) {
            throw new Error('Capsule not found');
        }

        const capsule = this._mapCapsuleRow(rows[0], viewerId);
        capsule.media = await this.getCapsuleMedia(capsuleId, capsule.isLocked);
        return capsule;
    }

    async getCapsuleMedia(capsuleId, locked = false) {
        const [rows] = await db.query(
            'SELECT id, file_name as fileName, stored_name as storedName, mime_type as mimeType, file_size as fileSize, media_type as mediaType FROM capsule_media WHERE capsule_id = ?',
            [capsuleId]
        );
        if (locked) {
            return rows.map(r => ({ id: r.id, fileName: r.fileName, mediaType: r.mediaType, fileSize: r.fileSize, locked: true }));
        }
        return rows.map(r => ({
            ...r,
            url: `/uploads/capsules/${r.storedName}`,
            locked: false
        }));
    }

    async getCapsuleMediaByStoredName(storedName) {
        const [rows] = await db.query(`
            SELECT cm.*, tc.status, tc.open_date, tc.user_id, tc.recipient_user_id, tc.contributors
            FROM capsule_media cm
            JOIN time_capsules tc ON tc.id = cm.capsule_id
            WHERE cm.stored_name = ?
            LIMIT 1
        `, [storedName]);
        return rows.length > 0 ? rows[0] : null;
    }

    async getAllCapsules(userId) {
        const username = await this._getUsername(userId);
        const normalizedUsername = username ? username.trim().replace(/^@/, '').toLowerCase() : null;

        const [rows] = await db.query(`
            SELECT tc.*,
                   su.username as sender_username,
                   ru.username as recipient_username,
                   (SELECT COUNT(*) FROM capsule_media cm WHERE cm.capsule_id = tc.id) as media_count
            FROM time_capsules tc
            LEFT JOIN users su ON su.id = tc.user_id
            LEFT JOIN users ru ON ru.id = tc.recipient_user_id
            WHERE tc.user_id = ? OR tc.recipient_user_id = ? 
               OR (tc.contributors IS NOT NULL AND JSON_CONTAINS(LOWER(tc.contributors), ?))
            ORDER BY tc.created_at DESC
        `, [userId, userId, normalizedUsername ? JSON.stringify(normalizedUsername) : '"__NONE__"']);

        const sent = [];
        const received = [];

        for (const row of rows) {
            const mapped = this._mapCapsuleRow(row, userId);
            if (row.recipient_user_id === userId && row.user_id !== userId) {
                received.push(mapped);
            } else {
                sent.push(mapped);
            }
        }

        return { sent, received, all: rows.map(r => this._mapCapsuleRow(r, userId)) };
    }

    async getPendingDeliveries(userId) {
        const username = await this._getUsername(userId);
        const normalizedUsername = username ? username.trim().replace(/^@/, '').toLowerCase() : null;

        const [rows] = await db.query(`
            SELECT tc.*,
                   su.username as sender_username,
                   ru.username as recipient_username,
                   (SELECT COUNT(*) FROM capsule_media cm WHERE cm.capsule_id = tc.id) as media_count
            FROM time_capsules tc
            LEFT JOIN users su ON su.id = tc.user_id
            LEFT JOIN users ru ON ru.id = tc.recipient_user_id
            WHERE (tc.recipient_user_id = ? OR (tc.contributors IS NOT NULL AND JSON_CONTAINS(LOWER(tc.contributors), ?)))
              AND tc.status = 'LOCKED'
              AND tc.open_date <= NOW()
              AND NOT EXISTS (
                  SELECT 1 FROM capsule_delivery_acknowledgements cda
                  WHERE cda.capsule_id = tc.id AND cda.user_id = ?
              )
        `, [userId, normalizedUsername ? JSON.stringify(normalizedUsername) : '"__NONE__"', userId]);

        return rows.map(r => this._mapCapsuleRow(r, userId));
    }

    async markDeliveryNotified(capsuleId, viewerId) {
        await this.getCapsuleById(capsuleId, viewerId);
        await db.query(`
            INSERT IGNORE INTO capsule_delivery_acknowledgements (capsule_id, user_id)
            VALUES (?, ?)
        `, [capsuleId, viewerId]);
        await db.query('UPDATE time_capsules SET delivery_notified = 1 WHERE id = ?', [capsuleId]);
    }

    async checkUnlockedCapsules(userId) {
        const username = await this._getUsername(userId);
        const normalizedUsername = username ? username.trim().replace(/^@/, '').toLowerCase() : null;

        const [rows] = await db.query(`
            SELECT tc.*, su.username as sender_username, ru.username as recipient_username,
                   (SELECT COUNT(*) FROM capsule_media cm WHERE cm.capsule_id = tc.id) as media_count
            FROM time_capsules tc
            LEFT JOIN users su ON su.id = tc.user_id
            LEFT JOIN users ru ON ru.id = tc.recipient_user_id
            WHERE (tc.user_id = ? OR tc.recipient_user_id = ? OR (tc.contributors IS NOT NULL AND JSON_CONTAINS(LOWER(tc.contributors), ?)))
              AND tc.status = 'LOCKED' AND tc.open_date <= NOW()
        `, [userId, userId, normalizedUsername ? JSON.stringify(normalizedUsername) : '"__NONE__"']);

        return rows.map(r => this._mapCapsuleRow(r, userId));
    }

    async openCapsule(userId, capsuleId, clientLocation = null, executor = db) {
        const username = await this._getUsername(userId);

        const [rows] = await executor.query(`
            SELECT tc.*, su.username as sender_username, ru.username as recipient_username
            FROM time_capsules tc
            LEFT JOIN users su ON su.id = tc.user_id
            LEFT JOIN users ru ON ru.id = tc.recipient_user_id
            WHERE tc.id = ?
            LIMIT 1 FOR UPDATE
        `, [capsuleId]);

        if (rows.length === 0) throw new Error('Capsule not found');

        const capsule = rows[0];

        // Object-level authorization check: sender, recipient, or collaborator
        if (!this._viewerCanAccess(capsule, userId, username)) {
            throw new Error('Capsule not found');
        }

        if (capsule.status === 'OPENED') {
            return { capsuleId, message: capsule.message, alreadyOpened: true };
        }

        // Server-side unlock time enforcement
        const openTime = new Date(capsule.open_date);
        if (Number.isNaN(openTime.getTime()) || openTime > new Date()) {
            throw new Error('Capsule is not ready to be opened yet');
        }

        // Server-side Geo-Lock verification
        const isGeoLocked = capsule.latitude != null && capsule.longitude != null;
        if (isGeoLocked) {
            const clientLat = clientLocation?.latitude != null ? Number(clientLocation.latitude) : null;
            const clientLon = clientLocation?.longitude != null ? Number(clientLocation.longitude) : null;

            if (clientLat == null || clientLon == null || !Number.isFinite(clientLat) || !Number.isFinite(clientLon)) {
                throw new Error('This capsule is Geo-Locked. Valid location coordinates are required to open it.');
            }

            if (clientLat < -90 || clientLat > 90 || clientLon < -180 || clientLon > 180) {
                throw new Error('Invalid GPS coordinates provided.');
            }

            const distance = this._calculateDistanceMeters(capsule.latitude, capsule.longitude, clientLat, clientLon);
            const MAX_DISTANCE_METERS = 100;
            if (distance > MAX_DISTANCE_METERS) {
                throw new Error(`Location verification failed: You are ${Math.round(distance)}m away (must be within ${MAX_DISTANCE_METERS}m to open).`);
            }
        }

        await executor.query('UPDATE time_capsules SET status = ?, delivery_notified = 1 WHERE id = ?', ['OPENED', capsuleId]);
        await executor.query('INSERT IGNORE INTO capsule_delivery_acknowledgements (capsule_id, user_id) VALUES (?, ?)', [capsuleId, userId]);

        return { capsuleId, message: capsule.message, alreadyOpened: false };
    }
}

module.exports = new TimeCapsuleService();
