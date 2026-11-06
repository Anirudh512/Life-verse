const mysql = require('mysql2/promise');

function useUtcSessions(pool) {
    // MySQL date functions (CURDATE/DATE) must follow the UTC task-day policy.
    // Queue this once on each new socket before the pool hands it to a caller.
    pool.on('connection', connection => {
        connection.query("SET SESSION time_zone = '+00:00'", error => {
            if (error) {
                console.error('[Database] Could not set UTC session timezone:', error.message);
                connection.destroy();
            }
        });
    });
    return pool;
}

function createPool() {
    const url = process.env.DATABASE_URL || process.env.MYSQL_URL;

    if (url) {
        return useUtcSessions(mysql.createPool({
            uri: url,
            waitForConnections: true,
            connectionLimit: 10,
            queueLimit: 0,
            timezone: 'Z',
            ssl: process.env.DB_SSL === 'true'
                ? { rejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED !== 'false' }
                : undefined
        }));
    }

    return useUtcSessions(mysql.createPool({
        host: process.env.DB_HOST || 'localhost',
        port: Number(process.env.DB_PORT) || 3306,
        user: process.env.DB_USER || 'root',
        password: process.env.DB_PASSWORD || '',
        database: process.env.DB_NAME || 'lifeverse',
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0,
        timezone: 'Z'
    }));
}

module.exports = { db: createPool() };
