require('dotenv').config();
const { db } = require('../src/config/db');

async function inspectDb() {
    const targetTable = process.argv[2];

    try {
        const dbName = process.env.DB_NAME || 'lifeverse';
        const host = process.env.DB_HOST || 'localhost';
        console.log(`\n======================================================`);
        console.log(`  LifeVerse Database: ${dbName} @ ${host}`);
        console.log(`======================================================\n`);

        if (targetTable) {
            // Show data from a specific table
            console.log(`--- Rows in table: ${targetTable} (Limit 20) ---`);
            const [rows] = await db.query(`SELECT * FROM ?? LIMIT 20`, [targetTable]);
            if (rows.length === 0) {
                console.log(`Table '${targetTable}' is currently empty (0 rows).\n`);
            } else {
                console.table(rows);
            }
        } else {
            // Show summary of all tables
            const [tables] = await db.query('SHOW TABLES');
            if (tables.length === 0) {
                console.log('No tables found in this database. Run: npm run init-db');
                process.exit(0);
            }

            const summary = [];
            for (const tableObj of tables) {
                const tableName = Object.values(tableObj)[0];
                const [[{ count }]] = await db.query(`SELECT COUNT(*) AS count FROM \`${tableName}\``);
                summary.push({
                    'Table Name': tableName,
                    'Row Count': count
                });
            }

            console.table(summary);
            console.log(`Total Tables: ${tables.length}`);
            console.log(`\nTip: To see actual rows inside a table, run:`);
            console.log(`     node scripts/inspect-db.js <table_name>`);
            console.log(`     Example: node scripts/inspect-db.js users\n`);
        }

        process.exit(0);
    } catch (error) {
        console.error('❌ Database error:', error.message);
        process.exit(1);
    }
}

inspectDb();
