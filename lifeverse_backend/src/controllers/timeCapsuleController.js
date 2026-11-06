const path = require('path');
const fs = require('fs');
const timeCapsuleService = require('../services/timeCapsuleService');
const { lifeEventEngine } = require('../core/lifeEventEngine');
const { upload, UPLOAD_DIR } = require('../middleware/uploadMiddleware');

class TimeCapsuleController {

    _parseContributors(value) {
        if (!value) return [];
        let list = [];
        if (Array.isArray(value)) {
            list = value;
        } else {
            try {
                const parsed = JSON.parse(value);
                if (Array.isArray(parsed)) list = parsed;
            } catch (_) {
                list = [];
            }
        }
        return [...new Set(list.map(v => String(v).trim().replace(/^@/, '').toLowerCase()).filter(Boolean))];
    }

    _parseOptionalNumber(value) {
        if (value == null || value === '') return null;
        const parsed = Number(value);
        return Number.isFinite(parsed) ? parsed : null;
    }

    async createCapsule(req, res) {
        let connection;
        let transactionStarted = false;
        let committed = false;
        try {
            const userId = req.body.userId;
            const idempotencyKey = req.get('Idempotency-Key')?.trim() || null;
            if (idempotencyKey && !/^[A-Za-z0-9_-]{16,64}$/.test(idempotencyKey)) {
                const error = new Error('Idempotency-Key must contain 16–64 letters, numbers, underscores, or hyphens.');
                error.statusCode = 400;
                throw error;
            }
            const capsuleData = {
                message: req.body.message,
                openDate: req.body.openDate,
                title: req.body.title,
                prediction: req.body.prediction,
                themeStyle: req.body.themeStyle,
                capsuleType: req.body.capsuleType || 'self',
                recipientUsername: req.body.recipientUsername,
                recipientUserId: req.body.recipientUserId,
                latitude: this._parseOptionalNumber(req.body.latitude),
                longitude: this._parseOptionalNumber(req.body.longitude),
                contributors: this._parseContributors(req.body.contributors),
                idempotencyKey,
            };

            const files = req.files || [];
            const { db } = require('../config/db');
            connection = await db.getConnection();
            await connection.beginTransaction();
            transactionStarted = true;

            // Serialize requests per account so a retry with the same key sees
            // the capsule created by the first request before creating another.
            const [userRows] = await connection.query(
                'SELECT id FROM users WHERE id = ? FOR UPDATE',
                [userId]
            );
            if (userRows.length === 0) {
                const error = new Error('User not found.');
                error.statusCode = 404;
                throw error;
            }

            if (idempotencyKey) {
                const [existingCapsules] = await connection.query(
                    'SELECT id FROM time_capsules WHERE user_id = ? AND idempotency_key = ? LIMIT 1 FOR UPDATE',
                    [userId, idempotencyKey]
                );
                if (existingCapsules.length > 0) {
                    await connection.commit();
                    transactionStarted = false;
                    committed = true;
                    await Promise.all((req.files || []).map(file =>
                        fs.promises.unlink(file.path).catch(() => {})
                    ));
                    const existingCapsule = await timeCapsuleService.getCapsuleById(existingCapsules[0].id, userId);
                    return res.json({ success: true, capsule: existingCapsule, alreadyCreated: true });
                }
            }

            const capsuleId = await timeCapsuleService.createCapsule(userId, capsuleData, files, connection);

            await lifeEventEngine.processEvent({
                userId,
                type: 'TIME_CAPSULE_CREATED',
                details: {
                    capsuleId,
                    message: capsuleData.message,
                    openDate: capsuleData.openDate,
                    title: capsuleData.title,
                    recipientUsername: capsuleData.recipientUsername
                }
            }, { executor: connection });

            await connection.commit();
            transactionStarted = false;
            committed = true;
            const newCapsule = await timeCapsuleService.getCapsuleById(capsuleId, userId);

            res.json({ success: true, capsule: newCapsule, alreadyCreated: false });
        } catch (error) {
            if (transactionStarted) await connection.rollback().catch(() => {});
            if (!committed) {
                await Promise.all((req.files || []).map(file =>
                    fs.promises.unlink(file.path).catch(() => {})
                ));
            }
            console.error('[TimeCapsuleController] Error creating capsule:', error);
            res.status(error.statusCode || 400).json({ success: false, error: error.message });
        } finally {
            connection?.release();
        }
    }

    async lookupFriend(req, res) {
        try {
            const { username } = req.params;
            const user = await timeCapsuleService.lookupUserByUsername(username);
            if (!user) {
                return res.status(404).json({ success: false, message: 'User not found on LifeVerse' });
            }
            res.json({ success: true, user: { id: user.id, username: user.username, fullName: user.full_name } });
        } catch (error) {
            res.status(500).json({ success: false, error: error.message });
        }
    }

    async getPendingDeliveries(req, res) {
        try {
            const { userId } = req.params;
            const pending = await timeCapsuleService.getPendingDeliveries(userId);
            res.json({ success: true, pending });
        } catch (error) {
            res.status(500).json({ success: false, error: error.message });
        }
    }

    async markDelivered(req, res) {
        try {
            const { capsuleId } = req.body;
            await timeCapsuleService.markDeliveryNotified(capsuleId, req.user.userId);
            res.json({ success: true });
        } catch (error) {
            res.status(500).json({ success: false, error: error.message });
        }
    }

    async checkStatus(req, res) {
        try {
            const { userId } = req.params;
            const unlocked = await timeCapsuleService.checkUnlockedCapsules(userId);
            res.json({ success: true, newlyUnlocked: unlocked });
        } catch (error) {
            res.status(500).json({ success: false, error: error.message });
        }
    }

    async openCapsule(req, res) {
        let connection;
        let transactionStarted = false;
        try {
            const { userId, capsuleId, latitude, longitude } = req.body;
            const { db } = require('../config/db');
            connection = await db.getConnection();
            await connection.beginTransaction();
            transactionStarted = true;

            const capsuleState = await timeCapsuleService.openCapsule(
                userId, capsuleId, { latitude, longitude }, connection
            );

            if (!capsuleState.alreadyOpened) {
                await lifeEventEngine.processEvent({
                    userId,
                    type: 'TIME_CAPSULE_OPENED',
                    details: { capsuleId, message: capsuleState.message }
                }, { executor: connection });
            }

            await connection.commit();
            transactionStarted = false;
            const capsuleData = await timeCapsuleService.getCapsuleById(capsuleId, userId);

            res.json({ success: true, capsule: capsuleData, aiReflection: '', alreadyOpened: capsuleState.alreadyOpened });
        } catch (error) {
            if (transactionStarted) await connection.rollback().catch(() => {});
            console.error('[TimeCapsuleController] Error opening capsule:', error);
            res.status(400).json({ success: false, error: error.message });
        } finally {
            connection?.release();
        }
    }

    async getAllCapsules(req, res) {
        try {
            const { userId } = req.params;
            const data = await timeCapsuleService.getAllCapsules(userId);
            res.json({ success: true, ...data, capsules: data.all });
        } catch (error) {
            res.status(500).json({ success: false, error: error.message });
        }
    }

    async getCapsule(req, res) {
        try {
            const { capsuleId, userId } = req.params;
            const capsule = await timeCapsuleService.getCapsuleById(capsuleId, userId);
            res.json({ success: true, capsule });
        } catch (error) {
            res.status(404).json({ success: false, error: error.message });
        }
    }

    async streamCapsuleMedia(req, res) {
        try {
            const filename = path.basename(req.params.filename || '');
            if (!filename) {
                return res.status(400).json({ success: false, message: 'Filename is required' });
            }

            const mediaRecord = await timeCapsuleService.getCapsuleMediaByStoredName(filename);
            if (!mediaRecord) {
                return res.status(404).json({ success: false, message: 'Media not found' });
            }

            const viewerId = req.user?.userId;
            const viewerUsername = req.user?.username;

            // Authorization: sender, recipient, or collaborator
            if (!timeCapsuleService._viewerCanAccess(mediaRecord, viewerId, viewerUsername)) {
                return res.status(403).json({ success: false, message: 'Access denied to this media' });
            }

            // Locked state: if capsule is still locked, only original creator can preview
            const openTime = new Date(mediaRecord.open_date);
            const isReady = !Number.isNaN(openTime.getTime()) && openTime <= new Date();
            const isLocked = mediaRecord.status === 'LOCKED' && !isReady;
            if (isLocked && mediaRecord.user_id !== viewerId) {
                return res.status(403).json({ success: false, message: 'Capsule media is locked until open date' });
            }

            const safePath = path.resolve(UPLOAD_DIR, filename);
            const resolvedUploadDir = path.resolve(UPLOAD_DIR);
            const relativePath = path.relative(resolvedUploadDir, safePath);

            // Path containment check (prevent path traversal)
            if (relativePath.startsWith('..') || path.isAbsolute(relativePath)) {
                return res.status(403).json({ success: false, message: 'Invalid file path' });
            }

            if (!fs.existsSync(safePath)) {
                return res.status(404).json({ success: false, message: 'File not found on storage' });
            }

            res.set('X-Content-Type-Options', 'nosniff');
            res.sendFile(safePath);
        } catch (error) {
            console.error('[TimeCapsuleController] Error streaming media:', error);
            res.status(500).json({ success: false, message: 'Could not stream media' });
        }
    }
}

const timeCapsuleController = new TimeCapsuleController();
module.exports = { timeCapsuleController, uploadMiddleware: upload.array('media', 20) };
