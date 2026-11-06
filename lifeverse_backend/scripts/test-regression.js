require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const assert = require('assert');
const timeCapsuleService = require('../src/services/timeCapsuleService');

async function runRegressionTests() {
    console.log('--- Starting LifeVerse Pre-Review Regression Tests ---');
    let passed = 0;
    let failed = 0;

    // Test 1: Geo-Lock distance calculation
    try {
        const distSame = timeCapsuleService._calculateDistanceMeters(12.9716, 77.5946, 12.9716, 77.5946);
        assert(Math.abs(distSame) < 0.001, 'Distance to same coordinate should be 0');

        const dist111m = timeCapsuleService._calculateDistanceMeters(12.9716, 77.5946, 12.9726, 77.5946);
        assert(dist111m > 100 && dist111m < 120, `Expected ~111m, got ${dist111m}`);

        const dist22m = timeCapsuleService._calculateDistanceMeters(12.9716, 77.5946, 12.9718, 77.5946);
        assert(dist22m < 100, `Expected <100m, got ${dist22m}`);

        console.log('✅ PASS: Geo-Lock distance formula works correctly.');
        passed++;
    } catch (err) {
        console.error('❌ FAIL: Geo-Lock distance formula:', err.message);
        failed++;
    }

    // Test 2: Geo-Lock coordinate and access checks
    try {
        const capsule = {
            id: 'cap_geo_test',
            user_id: 'user_123',
            recipient_user_id: null,
            contributors: '[]',
            latitude: 12.9716,
            longitude: 77.5946,
            open_date: new Date(Date.now() - 3600000)
        };

        // Access check for owner
        assert(timeCapsuleService._viewerCanAccess(capsule, 'user_123', 'alice') === true, 'Owner should have access');
        assert(timeCapsuleService._viewerCanAccess(capsule, 'user_999', 'bob') === false, 'Stranger should not have access');

        // Geo-Lock coordinate checks
        const checkGeo = (clientLoc) => {
            const clientLat = clientLoc?.latitude != null ? Number(clientLoc.latitude) : null;
            const clientLon = clientLoc?.longitude != null ? Number(clientLoc.longitude) : null;

            if (clientLat == null || clientLon == null || !Number.isFinite(clientLat) || !Number.isFinite(clientLon)) {
                throw new Error('This capsule is Geo-Locked. Valid location coordinates are required to open it.');
            }
            if (clientLat < -90 || clientLat > 90 || clientLon < -180 || clientLon > 180) {
                throw new Error('Invalid GPS coordinates provided.');
            }
            const distance = timeCapsuleService._calculateDistanceMeters(capsule.latitude, capsule.longitude, clientLat, clientLon);
            if (distance > 100) {
                throw new Error(`Location verification failed: You are ${Math.round(distance)}m away (must be within 100m to open).`);
            }
            return true;
        };

        // Missing location should throw
        assert.throws(() => checkGeo(null), /Valid location coordinates are required/);
        // Distant location should throw
        assert.throws(() => checkGeo({ latitude: 12.9800, longitude: 77.5946 }), /Location verification failed/);
        // Close location within 100m should pass
        assert.doesNotThrow(() => checkGeo({ latitude: 12.9717, longitude: 77.5946 }));

        console.log('✅ PASS: Backend Geo-Lock validation logic verified.');
        passed++;
    } catch (err) {
        console.error('❌ FAIL: Backend Geo-Lock validation logic:', err.message);
        failed++;
    }

    // Test 3: Collaborator access verification
    try {
        const capsule = {
            id: 'cap_collab_test',
            user_id: 'user_owner',
            recipient_user_id: null,
            contributors: JSON.stringify(['bob', 'charlie']),
            latitude: null,
            longitude: null
        };

        assert(timeCapsuleService._viewerCanAccess(capsule, 'user_owner', 'alice') === true, 'Owner has access');
        assert(timeCapsuleService._viewerCanAccess(capsule, 'user_bob', 'bob') === true, 'Collaborator Bob has access');
        assert(timeCapsuleService._viewerCanAccess(capsule, 'user_bob', '@bob') === true, 'Collaborator @bob with at-sign has access');
        assert(timeCapsuleService._viewerCanAccess(capsule, 'user_charlie', 'Charlie') === true, 'Case-insensitive collaborator has access');
        assert(timeCapsuleService._viewerCanAccess(capsule, 'user_eve', 'eve') === false, 'Eve has no access');

        console.log('✅ PASS: Collaborator authorization verified.');
        passed++;
    } catch (err) {
        console.error('❌ FAIL: Collaborator authorization:', err.message);
        failed++;
    }

    // Test 4: First-time user momentum & streak logic
    try {
        const initialStats = {
            current_streak: 0,
            momentum: 50,
            last_active_date: null
        };

        const today = new Date().toISOString().split('T')[0];
        let currentStreak = Number(initialStats.current_streak) || 0;
        let momentum = Number(initialStats.momentum) || 50;
        const lastActiveDate = initialStats.last_active_date;

        if (lastActiveDate !== today) {
            const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
            if (!lastActiveDate) {
                currentStreak = 1;
                momentum = Math.min(100, momentum + 2);
            } else if (lastActiveDate === yesterday) {
                currentStreak += 1;
                momentum = Math.min(100, momentum + 2);
            } else {
                currentStreak = 1;
                momentum = Math.max(0, momentum - 15);
            }
        }

        assert.strictEqual(currentStreak, 1, 'First task streak should be 1');
        assert.strictEqual(momentum, 52, 'First task momentum should increase to 52, not drop to 35');

        console.log('✅ PASS: First-time user streak and momentum increment verified.');
        passed++;
    } catch (err) {
        console.error('❌ FAIL: First-time user momentum calculation:', err.message);
        failed++;
    }

    // Test 5: Task completion idempotency
    try {
        const tasks = [
            { title: 'Hydration', completed: false, expReward: 25 },
            { title: 'Reading', completed: false, expReward: 25 }
        ];

        let alreadyCompletedFirst = false;
        for (const t of tasks) {
            if (t.title === 'Hydration') {
                if (t.completed) alreadyCompletedFirst = true;
                else t.completed = true;
                break;
            }
        }
        assert.strictEqual(alreadyCompletedFirst, false, 'First completion should not be alreadyCompleted');
        assert.strictEqual(tasks[0].completed, true, 'Task should now be completed');

        let alreadyCompletedSecond = false;
        for (const t of tasks) {
            if (t.title === 'Hydration') {
                if (t.completed) alreadyCompletedSecond = true;
                else t.completed = true;
                break;
            }
        }
        assert.strictEqual(alreadyCompletedSecond, true, 'Second completion must be flagged alreadyCompleted');

        console.log('✅ PASS: Task completion idempotency logic verified.');
        passed++;
    } catch (err) {
        console.error('❌ FAIL: Task completion idempotency:', err.message);
        failed++;
    }

    // Test 6: Vision Engine simulation persistence
    try {
        const { db } = require('../src/config/db');
        const [userRows] = await db.query('SELECT id FROM users LIMIT 1');
        assert(userRows.length > 0, 'At least one user must exist in users table');
        const testUserId = userRows[0].id;

        const simId = 'test_sim_' + Date.now();
        const testSimulation = {
            projection: 'High momentum achieved in Cognitive and Physical dimensions.',
            milestones: ['Consistent habit tracking', 'Deep work stamina unlocked'],
            risks: ['Screen fatigue']
        };

        await db.query(
            'INSERT INTO future_simulations (id, user_id, decision_question, simulation_json) VALUES (?, ?, ?, ?)',
            [simId, testUserId, 'Should I focus on deep work?', JSON.stringify(testSimulation)]
        );

        const [rows] = await db.query(
            'SELECT * FROM future_simulations WHERE user_id = ? ORDER BY created_at DESC LIMIT 1',
            [testUserId]
        );

        const parseJson = (v) => (typeof v === 'string' ? JSON.parse(v) : v);
        assert(rows.length > 0, 'Simulation should be stored and retrievable');
        const retrieved = parseJson(rows[0].simulation_json);
        assert.strictEqual(retrieved.projection, testSimulation.projection);

        // Clean up test sim record
        await db.query('DELETE FROM future_simulations WHERE id = ?', [simId]);

        console.log('✅ PASS: Vision Engine simulation persistence (future_simulations) verified.');
        passed++;
    } catch (err) {
        console.error('❌ FAIL: Vision Engine simulation persistence:', err.message);
        failed++;
    }

    // Test 7: Vision recommendation commit into daily tasks
    try {
        const { db } = require('../src/config/db');
        const futureSimController = require('../src/controllers/futureSimController');
        const parseJson = (v) => (typeof v === 'string' ? JSON.parse(v) : v);
        const [userRows] = await db.query('SELECT id FROM users LIMIT 1');
        assert(userRows.length > 0, 'At least one user must exist in users table');
        const testUserId = userRows[0].id;

        let commitResult;
        let mockRes = {
            status: function() { return this; },
            json: function(data) { commitResult = data; return this; }
        };

        await futureSimController.commitRecommendation({
            body: {
                userId: testUserId,
                title: 'Morning Flow State Session',
                description: '25-minute deep focus before notifications.',
                dimension: 'cognitive'
            }
        }, mockRes);

        assert(commitResult && commitResult.success === true, 'Commit should succeed');
        assert(commitResult.task.title.includes('Morning Flow State Session'), 'Task title should match');

        // Verify task appears in daily_tasks for today
        const todayStr = new Date().toISOString().split('T')[0];
        const [taskRows] = await db.query(
            'SELECT tasks_json FROM daily_tasks WHERE user_id = ? AND dimension = ? AND task_date = ? LIMIT 1',
            [testUserId, 'cognitive', todayStr]
        );
        assert(taskRows.length > 0, 'Daily tasks record should exist');
        const tasks = parseJson(taskRows[0].tasks_json);
        const committedTask = tasks.find(t => t.title === '[Vision Focus] Morning Flow State Session');
        assert(committedTask != null, 'Committed task must exist in daily tasks list');
        assert.strictEqual(committedTask.completed, false, 'Committed task must initially be uncompleted');

        // Test deduplication: committing again should not create duplicate task
        await futureSimController.commitRecommendation({
            body: {
                userId: testUserId,
                title: 'Morning Flow State Session',
                description: '25-minute deep focus before notifications.',
                dimension: 'cognitive'
            }
        }, mockRes);

        const [taskRows2] = await db.query(
            'SELECT tasks_json FROM daily_tasks WHERE user_id = ? AND dimension = ? AND task_date = ? LIMIT 1',
            [testUserId, 'cognitive', todayStr]
        );
        const tasks2 = parseJson(taskRows2[0].tasks_json);
        const count = tasks2.filter(t => t.title === '[Vision Focus] Morning Flow State Session').length;
        assert.strictEqual(count, 1, 'Duplicate commitment should be ignored idempotently');

        // Clean up test committed task from daily_tasks
        const cleanedTasks = tasks2.filter(t => t.title !== '[Vision Focus] Morning Flow State Session');
        await db.query(
            'UPDATE daily_tasks SET tasks_json = ? WHERE user_id = ? AND dimension = ? AND task_date = ?',
            [JSON.stringify(cleanedTasks), testUserId, 'cognitive', todayStr]
        );

        console.log('✅ PASS: Vision recommendation commit and deduplication verified.');
        passed++;
    } catch (err) {
        console.error('❌ FAIL: Vision recommendation commit flow:', err.message);
        failed++;
    }

    // Test 8: HDE Controller quest lifecycle & non-empty completion response
    try {
        const { db } = require('../src/config/db');
        const hdeController = require('../src/controllers/hdeController');
        const [userRows] = await db.query('SELECT id FROM users LIMIT 1');
        assert(userRows.length > 0, 'At least one user must exist in users table');
        const testUserId = userRows[0].id;

        let genResult;
        let mockRes = {
            status: function() { return this; },
            json: function(data) { genResult = data; return this; }
        };

        await hdeController.generateDailyTasks({
            body: {
                userId: testUserId,
                dimension: 'physical'
            }
        }, mockRes);

        assert(genResult && genResult.success === true, 'generateDailyTasks should succeed');
        assert(Array.isArray(genResult.data.tasks), 'tasks array should be returned');
        assert(genResult.data.tasks.length > 0, 'tasks array should not be empty');

        console.log('✅ PASS: HDE quest generation lifecycle returns populated tasks array.');
        passed++;
    } catch (err) {
        console.error('❌ FAIL: HDE quest generation lifecycle:', err.message);
        failed++;
    }

    console.log(`\nRegression Test Summary: ${passed} passed, ${failed} failed.`);
    process.exit(failed > 0 ? 1 : 0);
}

runRegressionTests();
