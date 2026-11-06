const crypto = require('crypto');
const { promisify } = require('util');

const scrypt = promisify(crypto.scrypt);
const PREFIX = 'scrypt';
const KEY_LENGTH = 64;

function normalizeSecurityAnswer(answer) {
    return String(answer || '').trim().toLowerCase();
}

function isHashedSecret(value) {
    return typeof value === 'string' && value.startsWith(`${PREFIX}$`);
}

async function hashSecret(secret) {
    const salt = crypto.randomBytes(16).toString('hex');
    const derivedKey = await scrypt(String(secret), salt, KEY_LENGTH);
    return `${PREFIX}$${salt}$${derivedKey.toString('hex')}`;
}

async function verifySecret(secret, storedSecret) {
    if (!storedSecret) return false;

    if (!isHashedSecret(storedSecret)) {
        return String(secret) === String(storedSecret);
    }

    const parts = storedSecret.split('$');
    if (parts.length !== 3 || parts[0] !== PREFIX) return false;

    const [, salt, storedHash] = parts;
    const storedBuffer = Buffer.from(storedHash, 'hex');
    if (storedBuffer.length !== KEY_LENGTH) return false;

    const derivedKey = await scrypt(String(secret), salt, KEY_LENGTH);
    return crypto.timingSafeEqual(storedBuffer, derivedKey);
}

module.exports = {
    hashSecret,
    verifySecret,
    isHashedSecret,
    normalizeSecurityAnswer
};
