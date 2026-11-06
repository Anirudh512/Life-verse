const { db } = require('../config/db');
const crypto = require('crypto');
const { parseJsonArray } = require('../utils/json');

class LegacyService {

    async addLegacyEvent(userId, eventData, executor = db) {
        const eventId = crypto.randomUUID();
        const coreValues = Array.isArray(eventData.coreValues)
            ? eventData.coreValues
                .filter(value => typeof value === 'string')
                .map(value => value.trim().slice(0, 80))
                .filter(Boolean)
                .slice(0, 8)
            : [];
        const newEvent = {
            id: eventId,
            title: eventData.title,
            description: eventData.description || '',
            chapter: eventData.chapter || 'Uncategorized',
            type: eventData.type || 'MILESTONE',
            coreValues,
            mediaUrls: eventData.mediaUrls || [],
        };

        await executor.query(`
            INSERT INTO legacy_events (id, user_id, title, description, chapter, event_type, core_values, media_urls)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `, [
            eventId, userId, newEvent.title, newEvent.description,
            newEvent.chapter, newEvent.type,
            JSON.stringify(newEvent.coreValues),
            JSON.stringify(newEvent.mediaUrls)
        ]);

        return { ...newEvent, date: new Date().toISOString() };
    }

    async getTimeline(userId) {
        const [rows] = await db.query(`
            SELECT id, title, description, chapter, event_type as type,
                   core_values as coreValues, media_urls as mediaUrls, event_date as date
            FROM legacy_events
            WHERE user_id = ?
            ORDER BY event_date DESC
        `, [userId]);

        return rows.map(row => ({
            ...row,
            coreValues: parseJsonArray(row.coreValues),
            mediaUrls: parseJsonArray(row.mediaUrls)
        }));
    }

    async updateAIBiography(userId, biographyText) {
        await db.query(`
            INSERT INTO legacy_profiles (user_id, ai_biography, last_updated)
            VALUES (?, ?, NOW())
            ON DUPLICATE KEY UPDATE ai_biography = ?, last_updated = NOW()
        `, [userId, biographyText, biographyText]);
        return biographyText;
    }

    async getAIBiography(userId) {
        const [rows] = await db.query(
            'SELECT ai_biography FROM legacy_profiles WHERE user_id = ? LIMIT 1',
            [userId]
        );
        return rows.length > 0 ? rows[0].ai_biography : null;
    }
}

module.exports = new LegacyService();
