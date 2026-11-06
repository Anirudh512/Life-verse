const mysql = require('mysql2/promise');
require('dotenv').config();

async function safeAlter(db, sql) {
    try {
        await db.query(sql);
    } catch (error) {
        if (!/Duplicate column|Duplicate key name/i.test(error.message)) {
            console.warn(`Migration note: ${error.message}`);
        }
    }
}

let databasePool;
let bootstrapConnection;

async function initDb() {
    try {
        const databaseUrl = process.env.DATABASE_URL || process.env.MYSQL_URL;
        const databaseName = process.env.DB_NAME || 'lifeverse';
        if (!databaseUrl) {
            console.log("Connecting to MySQL to ensure database exists...");
            bootstrapConnection = await mysql.createConnection({
                host: process.env.DB_HOST || 'localhost',
                port: process.env.DB_PORT || 3306,
                user: process.env.DB_USER || 'root',
                password: process.env.DB_PASSWORD || ''
            });
            await bootstrapConnection.query('CREATE DATABASE IF NOT EXISTS ??', [databaseName]);
            await bootstrapConnection.end();
            bootstrapConnection = null;
            console.log(`Database '${databaseName}' is ready. Connecting to create tables...`);
        } else {
            console.log('Using configured MySQL URL and applying schema migrations...');
        }

        databasePool = require('./config/db').db;
        const db = databasePool;

        await db.query(`
            CREATE TABLE IF NOT EXISTS users (
                id VARCHAR(255) PRIMARY KEY,
                email VARCHAR(255) UNIQUE NOT NULL,
                username VARCHAR(100) UNIQUE NOT NULL,
                full_name VARCHAR(255) NOT NULL,
                password VARCHAR(255) NOT NULL,
                qr_hash VARCHAR(255),
                security_question VARCHAR(255),
                security_answer VARCHAR(255),
                photo_url VARCHAR(1024),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        await db.query(`
            CREATE TABLE IF NOT EXISTS time_capsules (
                id VARCHAR(255) PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                idempotency_key VARCHAR(64) NULL,
                recipient_user_id VARCHAR(255),
                title VARCHAR(255),
                message TEXT,
                prediction TEXT,
                open_date TIMESTAMP,
                status VARCHAR(50) DEFAULT 'LOCKED',
                capsule_type VARCHAR(20) DEFAULT 'self',
                theme_style VARCHAR(50) DEFAULT 'amber_gold',
                media_total_bytes BIGINT DEFAULT 0,
                delivery_notified TINYINT(1) DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);

        await safeAlter(db, 'ALTER TABLE time_capsules ADD COLUMN recipient_user_id VARCHAR(255) AFTER user_id');
        await safeAlter(db, 'ALTER TABLE time_capsules ADD COLUMN idempotency_key VARCHAR(64) NULL AFTER user_id');
        await safeAlter(db, 'ALTER TABLE time_capsules ADD UNIQUE KEY unique_capsule_idempotency (user_id, idempotency_key)');
        await safeAlter(db, 'ALTER TABLE time_capsules ADD COLUMN prediction TEXT AFTER message');
        await safeAlter(db, 'ALTER TABLE time_capsules ADD COLUMN capsule_type VARCHAR(20) DEFAULT \'self\' AFTER status');
        await safeAlter(db, 'ALTER TABLE time_capsules ADD COLUMN theme_style VARCHAR(50) DEFAULT \'amber_gold\' AFTER capsule_type');
        await safeAlter(db, 'ALTER TABLE time_capsules ADD COLUMN media_total_bytes BIGINT DEFAULT 0 AFTER theme_style');
        await safeAlter(db, 'ALTER TABLE time_capsules ADD COLUMN delivery_notified TINYINT(1) DEFAULT 0 AFTER media_total_bytes');
        await safeAlter(db, 'ALTER TABLE time_capsules ADD COLUMN latitude DOUBLE AFTER delivery_notified');
        await safeAlter(db, 'ALTER TABLE time_capsules ADD COLUMN longitude DOUBLE AFTER latitude');
        await safeAlter(db, 'ALTER TABLE time_capsules ADD COLUMN contributors JSON AFTER longitude');

        await db.query(`
            CREATE TABLE IF NOT EXISTS capsule_delivery_acknowledgements (
                capsule_id VARCHAR(255) NOT NULL,
                user_id VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (capsule_id, user_id),
                INDEX idx_cda_user (user_id)
            )
        `);

        await db.query(`
            CREATE TABLE IF NOT EXISTS capsule_media (
                id VARCHAR(255) PRIMARY KEY,
                capsule_id VARCHAR(255) NOT NULL,
                file_name VARCHAR(255) NOT NULL,
                stored_name VARCHAR(255) NOT NULL,
                mime_type VARCHAR(100),
                file_size BIGINT DEFAULT 0,
                media_type VARCHAR(20) DEFAULT 'file',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (capsule_id) REFERENCES time_capsules(id) ON DELETE CASCADE,
                INDEX idx_capsule_media (capsule_id)
            )
        `);

        await db.query(`
            CREATE TABLE IF NOT EXISTS daily_tasks (
                id VARCHAR(255) PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                dimension VARCHAR(100) NOT NULL,
                task_date DATE NOT NULL,
                tasks_json JSON,
                flashcards_json JSON,
                survey_questions_json JSON,
                survey_submitted TINYINT(1) NOT NULL DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                UNIQUE KEY unique_daily_task (user_id, dimension, task_date)
            )
        `);
        await safeAlter(db, 'ALTER TABLE daily_tasks ADD COLUMN survey_submitted TINYINT(1) NOT NULL DEFAULT 0 AFTER survey_questions_json');

        await db.query(`
            CREATE TABLE IF NOT EXISTS survey_answers (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                dimension VARCHAR(100) NOT NULL,
                qna_json JSON,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);

        // Central nervous system — every action lands here
        await db.query(`
            CREATE TABLE IF NOT EXISTS user_activity_logs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                action_type VARCHAR(255) NOT NULL,
                dimension VARCHAR(100),
                xp_gained INT DEFAULT 0,
                metadata JSON,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_user_date (user_id, created_at),
                INDEX idx_user_action (user_id, action_type)
            )
        `);

        // One row per authenticated account and UTC calendar day. This table
        // records app visits separately from meaningful growth activities.
        // It is additive and intentionally has no historical backfill.
        await db.query(`
            CREATE TABLE IF NOT EXISTS user_app_visits (
                user_id VARCHAR(255) NOT NULL,
                visit_date DATE NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (user_id, visit_date),
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);

        // Migrate existing tables that were created before metadata column
        await safeAlter(db, 'ALTER TABLE user_activity_logs ADD COLUMN dimension VARCHAR(100) AFTER action_type');
        await safeAlter(db, 'ALTER TABLE user_activity_logs ADD COLUMN metadata JSON AFTER xp_gained');

        // HDE progression stats (derived from activity logs)
        await db.query(`
            CREATE TABLE IF NOT EXISTS user_hde_stats (
                user_id VARCHAR(255) PRIMARY KEY,
                current_streak INT DEFAULT 0,
                momentum INT DEFAULT 50,
                last_active_date DATE,
                life_balance_index INT DEFAULT 0,
                physical_xp INT DEFAULT 0,
                physical_level INT DEFAULT 1,
                cognitive_xp INT DEFAULT 0,
                cognitive_level INT DEFAULT 1,
                psychosocial_xp INT DEFAULT 0,
                psychosocial_level INT DEFAULT 1,
                moral_xp INT DEFAULT 0,
                moral_level INT DEFAULT 1,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);

        // Personal HDE goals are measured from task completions in user_activity_logs.
        await db.query(`
            CREATE TABLE IF NOT EXISTS user_growth_goals (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                title VARCHAR(120) NOT NULL,
                dimension VARCHAR(32) NOT NULL,
                target_tasks SMALLINT UNSIGNED NOT NULL,
                due_date DATE NOT NULL,
                  reminder_enabled TINYINT(1) NOT NULL DEFAULT 0,
                  progress_metric VARCHAR(16) NOT NULL DEFAULT 'tasks',
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_growth_goal_user_due (user_id, due_date)
            )
        `);
        await safeAlter(db, 'ALTER TABLE user_growth_goals ADD COLUMN reminder_enabled TINYINT(1) NOT NULL DEFAULT 0 AFTER due_date');
        await safeAlter(db, 'ALTER TABLE user_growth_goals ADD COLUMN progress_metric VARCHAR(16) NOT NULL DEFAULT \'tasks\' AFTER reminder_enabled');

        // Legacy timeline events
        await db.query(`
            CREATE TABLE IF NOT EXISTS legacy_events (
                id VARCHAR(255) PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                title VARCHAR(255) NOT NULL,
                description TEXT,
                chapter VARCHAR(100),
                event_type VARCHAR(50) DEFAULT 'MILESTONE',
                core_values JSON,
                media_urls JSON,
                event_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_legacy_user (user_id, event_date)
            )
        `);

        await db.query(`
            CREATE TABLE IF NOT EXISTS legacy_profiles (
                user_id VARCHAR(255) PRIMARY KEY,
                ai_biography TEXT,
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);

        // Digital Twin profile (aggregated from activity logs)
        await db.query(`
            CREATE TABLE IF NOT EXISTS digital_twin_profiles (
                user_id VARCHAR(255) PRIMARY KEY,
                habit_dna JSON,
                personality_evolution JSON,
                confidence_score INT DEFAULT 0,
                last_aggregated TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);

        // Twin Mind Memories (saved proactive insights)
        await db.query(`
            CREATE TABLE IF NOT EXISTS twin_memories (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                memory_tag VARCHAR(100) NOT NULL,
                memory_content TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_twin_memory (user_id, memory_tag)
            )
        `);

        // Twin Mind dialogue is retained per account so the mentor can continue
        // across app visits. Users can clear both dialogue and saved memories.
        await db.query(`
            CREATE TABLE IF NOT EXISTS twin_conversations (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                persona VARCHAR(32) NOT NULL,
                role ENUM('user', 'assistant') NOT NULL,
                content LONGTEXT NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_twin_conversation_history (user_id, id),
                INDEX idx_twin_conversation_persona_history (user_id, persona, id)
            )
        `);
        // Retain all exchanges; this migration only widens message storage and
        // preserves existing rows. No automatic conversation cleanup is used.
        await db.query('ALTER TABLE twin_conversations MODIFY COLUMN content LONGTEXT NOT NULL');
        await safeAlter(db, 'ALTER TABLE twin_conversations ADD INDEX idx_twin_conversation_persona_history (user_id, persona, id)');

        // Friend Requests
        await db.query(`
            CREATE TABLE IF NOT EXISTS friend_requests (
                id INT AUTO_INCREMENT PRIMARY KEY,
                sender_id VARCHAR(255) NOT NULL,
                receiver_id VARCHAR(255) NOT NULL,
                status VARCHAR(50) DEFAULT 'PENDING',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
                UNIQUE KEY unique_request (sender_id, receiver_id)
            )
        `);

        // Friendships (Mutual Connections)
        await db.query(`
            CREATE TABLE IF NOT EXISTS friendships (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id_1 VARCHAR(255) NOT NULL,
                user_id_2 VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id_1) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id_2) REFERENCES users(id) ON DELETE CASCADE,
                UNIQUE KEY unique_friendship (user_id_1, user_id_2)
            )
        `);

        // Server-side sessions — login state lives in MySQL, not on device
        await db.query(`
            CREATE TABLE IF NOT EXISTS user_sessions (
                id VARCHAR(255) PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                session_token VARCHAR(512) NOT NULL UNIQUE,
                device_info JSON,
                is_active TINYINT(1) DEFAULT 1,
                expires_at TIMESTAMP NOT NULL,
                last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_session_token (session_token),
                INDEX idx_session_user (user_id, is_active)
            )
        `);

        // Server-side app state — preferences, last screen, etc. all in MySQL
        await db.query(`
            CREATE TABLE IF NOT EXISTS user_app_state (
                user_id VARCHAR(255) PRIMARY KEY,
                state_json JSON,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);

        // Epic 4: Butterfly Effect - Logging micro decisions
        await db.query(`
            CREATE TABLE IF NOT EXISTS micro_decisions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                decision_text TEXT NOT NULL,
                context_tags JSON,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_micro_decision (user_id, created_at)
            )
        `);

        // Epic 4: Future Simulations persistence
        await db.query(`
            CREATE TABLE IF NOT EXISTS future_simulations (
                id VARCHAR(255) PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                decision_question TEXT,
                simulation_json JSON,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_future_sim_user (user_id, created_at)
            )
        `);

        // User feedback helps future reflections adapt their guidance style.
        // It records usefulness preference, not whether a scenario came true.
        await db.query(`
            CREATE TABLE IF NOT EXISTS future_simulation_feedback (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                simulation_id VARCHAR(255) NOT NULL,
                was_helpful TINYINT(1) NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (simulation_id) REFERENCES future_simulations(id) ON DELETE CASCADE,
                UNIQUE KEY unique_user_simulation_feedback (user_id, simulation_id),
                INDEX idx_future_feedback_user (user_id, created_at)
            )
        `);

        console.log("✅ Database initialized successfully!");
        await databasePool.end();
        databasePool = null;
    } catch (error) {
        console.error("❌ Failed to initialize database:", error);
        if (databasePool) await databasePool.end().catch(() => {});
        if (bootstrapConnection) await bootstrapConnection.end().catch(() => {});
        process.exitCode = 1;
    }
}

initDb();
