function parseJson(value, fallback = null) {
    if (value == null) return fallback;
    if (Buffer.isBuffer(value)) value = value.toString('utf8');
    if (typeof value !== 'string') return value;

    try {
        return JSON.parse(value);
    } catch (_) {
        return fallback;
    }
}

function parseJsonArray(value) {
    const parsed = parseJson(value, []);
    return Array.isArray(parsed) ? parsed : [];
}

function parseJsonObject(value) {
    const parsed = parseJson(value, {});
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        return {};
    }
    return parsed;
}

module.exports = {
    parseJson,
    parseJsonArray,
    parseJsonObject
};
