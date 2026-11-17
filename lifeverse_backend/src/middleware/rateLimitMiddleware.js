function createRateLimiter({ windowMs, max, message = 'Too many attempts. Please try again later.' }) {
    const clients = new Map();
    let lastPrunedAt = 0;

    return (req, res, next) => {
        const now = Date.now();
        const key = req.ip || req.socket?.remoteAddress || 'unknown';
        let entry = clients.get(key);

        if (!entry || entry.resetAt <= now) {
            entry = { count: 0, resetAt: now + windowMs };
            clients.set(key, entry);
        }

        if (entry.count >= max) {
            const retryAfter = Math.max(1, Math.ceil((entry.resetAt - now) / 1000));
            res.set('Retry-After', String(retryAfter));
            return res.status(429).json({ success: false, message });
        }

        entry.count += 1;
        if (clients.size > 10000 && now - lastPrunedAt > 60000) {
            lastPrunedAt = now;
            for (const [clientKey, client] of clients) {
                if (client.resetAt <= now) clients.delete(clientKey);
            }
            if (clients.size > 20000) {
                const iterator = clients.keys();
                while (clients.size > 10000) {
                    clients.delete(iterator.next().value);
                }
            }
        }
        next();
    };
}

module.exports = { createRateLimiter };
