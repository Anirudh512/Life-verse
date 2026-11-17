const { db } = require('../config/db');

class FriendController {
    
    // Send a friend request by username or exact ID
    async sendRequest(req, res) {
        let connection;
        let transactionStarted = false;
        try {
            const { senderId, receiverUsername } = req.body;
            const normalizedSenderId = String(senderId || '');
            const normalizedUsername = typeof receiverUsername === 'string' ? receiverUsername.trim() : '';
            if (!normalizedSenderId || !normalizedUsername || normalizedUsername.length > 100) {
                return res.status(400).json({ success: false, message: 'A valid recipient username is required.' });
            }

            // Find receiver by username
            const [users] = await db.query('SELECT id FROM users WHERE username = ?', [normalizedUsername]);
            if (users.length === 0) {
                return res.status(404).json({ success: false, message: 'User not found.' });
            }
            const receiverId = users[0].id;

            if (normalizedSenderId === String(receiverId)) {
                return res.status(400).json({ success: false, message: 'You cannot friend yourself.' });
            }

            connection = await db.getConnection();
            await connection.beginTransaction();
            transactionStarted = true;

            // Lock both accounts in a stable order so opposite-direction requests
            // cannot race past the checks below or deadlock each other.
            const orderedIds = [normalizedSenderId, String(receiverId)].sort();
            const [lockedUsers] = await connection.query(
                'SELECT id FROM users WHERE id IN (?, ?) ORDER BY id FOR UPDATE',
                orderedIds
            );
            if (lockedUsers.length !== 2) {
                await connection.rollback();
                transactionStarted = false;
                return res.status(404).json({ success: false, message: 'User not found.' });
            }

            // Check if already friends
            const [existingFriend] = await connection.query(
                'SELECT id FROM friendships WHERE (user_id_1 = ? AND user_id_2 = ?) OR (user_id_1 = ? AND user_id_2 = ?)',
                [normalizedSenderId, receiverId, receiverId, normalizedSenderId]
            );
            if (existingFriend.length > 0) {
                await connection.commit();
                transactionStarted = false;
                return res.status(409).json({ success: false, message: 'You are already friends.' });
            }

            // A retry of the same request is successful and idempotent. An
            // opposite pending request should be accepted from the inbox instead.
            const [existingReq] = await connection.query(
                'SELECT id, sender_id, receiver_id, status FROM friend_requests WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?) FOR UPDATE',
                [normalizedSenderId, receiverId, receiverId, normalizedSenderId]
            );

            const sameDirection = existingReq.find(request =>
                String(request.sender_id) === normalizedSenderId && String(request.receiver_id) === String(receiverId)
            );
            const reverseDirection = existingReq.find(request =>
                String(request.sender_id) === String(receiverId) && String(request.receiver_id) === normalizedSenderId
            );

            if (sameDirection?.status === 'PENDING') {
                await connection.commit();
                transactionStarted = false;
                return res.json({ success: true, alreadyRequested: true, message: 'Friend request already sent.' });
            }
            if (reverseDirection?.status === 'PENDING') {
                await connection.commit();
                transactionStarted = false;
                return res.status(409).json({ success: false, incomingRequest: true, message: 'This user has already sent you a request.' });
            }
            if (sameDirection?.status === 'ACCEPTED' || reverseDirection?.status === 'ACCEPTED') {
                const id1 = orderedIds[0];
                const id2 = orderedIds[1];
                await connection.query(
                    'INSERT IGNORE INTO friendships (user_id_1, user_id_2) VALUES (?, ?)',
                    [id1, id2]
                );
                await connection.commit();
                transactionStarted = false;
                return res.json({ success: true, alreadyFriends: true, message: 'You are already friends.' });
            }
            if (existingReq.length > 0) {
                await connection.commit();
                transactionStarted = false;
                return res.status(409).json({ success: false, message: 'A request already exists between you two.' });
            }

            // Insert request
            await connection.query('INSERT INTO friend_requests (sender_id, receiver_id) VALUES (?, ?)', [normalizedSenderId, receiverId]);
            await connection.commit();
            transactionStarted = false;
            
            res.json({ success: true, message: 'Friend request sent!' });
        } catch (error) {
            if (transactionStarted) await connection.rollback().catch(() => {});
            console.error('[FriendController] sendRequest error:', error);
            res.status(500).json({ success: false, message: 'Internal server error.' });
        } finally {
            connection?.release();
        }
    }

    // Accept a friend request
    async acceptRequest(req, res) {
        let connection;
        let transactionStarted = false;
        try {
            const { receiverId, senderId } = req.body;
            const normalizedReceiverId = String(receiverId || '');
            const normalizedSenderId = String(senderId || '');
            if (!normalizedReceiverId || !normalizedSenderId || normalizedReceiverId === normalizedSenderId) {
                return res.status(400).json({ success: false, message: 'A valid friend request is required.' });
            }

            connection = await db.getConnection();
            await connection.beginTransaction();
            transactionStarted = true;

            const orderedIds = [normalizedSenderId, normalizedReceiverId].sort();
            const [lockedUsers] = await connection.query(
                'SELECT id FROM users WHERE id IN (?, ?) ORDER BY id FOR UPDATE',
                orderedIds
            );
            if (lockedUsers.length !== 2) {
                await connection.rollback();
                transactionStarted = false;
                return res.status(404).json({ success: false, message: 'User not found.' });
            }

            const [existingFriend] = await connection.query(
                'SELECT id FROM friendships WHERE user_id_1 = ? AND user_id_2 = ? LIMIT 1',
                orderedIds
            );
            if (existingFriend.length > 0) {
                await connection.commit();
                transactionStarted = false;
                return res.json({ success: true, alreadyFriends: true, message: 'You are already friends.' });
            }

            const [requests] = await connection.query(
                'SELECT id FROM friend_requests WHERE sender_id = ? AND receiver_id = ? AND status = ? LIMIT 1 FOR UPDATE',
                [normalizedSenderId, normalizedReceiverId, 'PENDING']
            );

            if (requests.length === 0) {
                await connection.rollback();
                transactionStarted = false;
                return res.status(404).json({ success: false, message: 'No pending request found.' });
            }

            const requestId = requests[0].id;

            // Mark as accepted
            await connection.query('UPDATE friend_requests SET status = ? WHERE id = ? AND status = ?', ['ACCEPTED', requestId, 'PENDING']);

            await connection.query(
                'INSERT IGNORE INTO friendships (user_id_1, user_id_2) VALUES (?, ?)',
                orderedIds
            );
            await connection.commit();
            transactionStarted = false;

            res.json({ success: true, alreadyFriends: false, message: 'Friend request accepted!' });
        } catch (error) {
            if (transactionStarted) await connection.rollback().catch(() => {});
            console.error('[FriendController] acceptRequest error:', error);
            res.status(500).json({ success: false, message: 'Internal server error.' });
        } finally {
            connection?.release();
        }
    }

    // List friends and pending requests
    async getFriendsAndRequests(req, res) {
        try {
            const { userId } = req.params;

            // Get Friends
            const [friendsQuery] = await db.query(`
                SELECT u.id, u.username, u.full_name 
                FROM friendships f
                JOIN users u ON (u.id = f.user_id_1 OR u.id = f.user_id_2) AND u.id != ?
                WHERE f.user_id_1 = ? OR f.user_id_2 = ?
            `, [userId, userId, userId]);

            // Get Incoming Pending Requests
            const [requestsQuery] = await db.query(`
                SELECT u.id, u.username, u.full_name 
                FROM friend_requests r
                JOIN users u ON u.id = r.sender_id
                WHERE r.receiver_id = ? AND r.status = 'PENDING'
            `, [userId]);

            res.json({ 
                success: true, 
                friends: friendsQuery,
                pendingRequests: requestsQuery 
            });
        } catch (error) {
            console.error('[FriendController] getFriendsAndRequests error:', error);
            res.status(500).json({ success: false, message: 'Internal server error.' });
        }
    }

    // A compact, shareable profile is visible only across an accepted friendship.
    // Reflections, goals, account details, and capsule messages/media stay private.
    async getFriendProfile(req, res) {
        const viewerId = String(req.user?.userId || '');
        const friendId = String(req.params.friendId || '');
        if (!viewerId || !friendId || friendId.length > 255 || viewerId === friendId) {
            return res.status(400).json({ success: false, message: 'A valid friend profile is required.' });
        }

        try {
            const [friendships] = await db.query(`
                SELECT id
                FROM friendships
                WHERE (user_id_1 = ? AND user_id_2 = ?)
                   OR (user_id_1 = ? AND user_id_2 = ?)
                LIMIT 1
            `, [viewerId, friendId, friendId, viewerId]);
            if (friendships.length === 0) {
                return res.status(404).json({ success: false, message: 'Friend profile not found.' });
            }

            const [users] = await db.query(
                'SELECT id, username, full_name, created_at FROM users WHERE id = ? LIMIT 1',
                [friendId]
            );
            if (users.length === 0) {
                return res.status(404).json({ success: false, message: 'Friend profile not found.' });
            }

            const viewerUsername = String(req.user?.username || '').trim().replace(/^@/, '').toLowerCase();
            const [lifetimeRows, periodRows, statsRows, capsuleRows] = await Promise.all([
                db.query(`
                    SELECT COALESCE(SUM(xp_gained), 0) AS totalXp
                    FROM user_activity_logs
                    WHERE user_id = ?
                `, [friendId]).then(([rows]) => rows),
                db.query(`
                    SELECT
                        SUM(CASE WHEN action_type = 'TASK_COMPLETED' THEN 1 ELSE 0 END) AS tasksCompleted,
                        SUM(CASE WHEN action_type = 'SURVEY_SUBMITTED' THEN 1 ELSE 0 END) AS reviewsCompleted,
                        COUNT(DISTINCT CASE WHEN action_type IN ('TASK_COMPLETED', 'SURVEY_SUBMITTED') THEN DATE(created_at) END) AS growthDays,
                        COALESCE(SUM(CASE WHEN action_type IN ('TASK_COMPLETED', 'SURVEY_SUBMITTED') THEN xp_gained ELSE 0 END), 0) AS periodXp
                    FROM user_activity_logs
                    WHERE user_id = ?
                      AND created_at >= DATE_SUB(UTC_DATE(), INTERVAL 29 DAY)
                      AND created_at < DATE_ADD(UTC_DATE(), INTERVAL 1 DAY)
                `, [friendId]).then(([rows]) => rows),
                db.query(`
                    SELECT current_streak, physical_xp, physical_level,
                           cognitive_xp, cognitive_level,
                           psychosocial_xp, psychosocial_level,
                           moral_xp, moral_level
                    FROM user_hde_stats
                    WHERE user_id = ?
                    LIMIT 1
                `, [friendId]).then(([rows]) => rows),
                db.query(`
                    SELECT tc.id, tc.title, tc.open_date AS openDate, tc.status,
                           tc.created_at AS createdAt, tc.theme_style AS themeStyle,
                           IF(tc.latitude IS NOT NULL AND tc.longitude IS NOT NULL, 1, 0) AS geoLocked,
                           (SELECT COUNT(*) FROM capsule_media cm WHERE cm.capsule_id = tc.id) AS mediaCount
                    FROM time_capsules tc
                    WHERE tc.user_id = ?
                      AND (tc.recipient_user_id = ? OR (
                          tc.contributors IS NOT NULL
                          AND JSON_CONTAINS(LOWER(tc.contributors), ?)
                      ))
                    ORDER BY tc.created_at DESC
                    LIMIT 20
                `, [friendId, viewerId, JSON.stringify(viewerUsername || '__NONE__')]).then(([rows]) => rows)
            ]);

            const stat = statsRows[0] || {};
            const activity = periodRows[0] || {};
            const now = Date.now();
            const capsules = capsuleRows.map(row => {
                const openDate = row.openDate ? new Date(row.openDate) : null;
                const isReady = Boolean(openDate && !Number.isNaN(openDate.getTime()) && openDate.getTime() <= now);
                return {
                    id: row.id,
                    title: row.title || 'A Memory Preserved',
                    openDate: row.openDate,
                    createdAt: row.createdAt,
                    status: row.status,
                    themeStyle: row.themeStyle,
                    isReady,
                    isLocked: row.status === 'LOCKED' && !isReady,
                    isGeoLocked: Number(row.geoLocked) === 1,
                    mediaCount: Number(row.mediaCount) || 0
                };
            });

            res.json({
                success: true,
                profile: {
                    fullName: users[0].full_name,
                    username: users[0].username,
                    createdAt: users[0].created_at
                },
                progress: {
                    totalXp: Number(lifetimeRows[0]?.totalXp) || 0,
                    tasksCompleted: Number(activity.tasksCompleted) || 0,
                    reviewsCompleted: Number(activity.reviewsCompleted) || 0,
                    growthDays: Number(activity.growthDays) || 0,
                    periodXp: Number(activity.periodXp) || 0,
                    days: 30,
                    currentStreak: Number(stat.current_streak) || 0
                },
                dimensions: Object.fromEntries(['physical', 'cognitive', 'psychosocial', 'moral'].map(dimension => [dimension, {
                    xp: Number(stat[`${dimension}_xp`]) || 0,
                    level: Number(stat[`${dimension}_level`]) || 1
                }])),
                capsules
            });
        } catch (error) {
            console.error('[FriendController] getFriendProfile error:', error.message);
            res.status(500).json({ success: false, message: 'Friend profile is unavailable right now.' });
        }
    }
}

module.exports = new FriendController();
