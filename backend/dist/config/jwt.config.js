"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("@nestjs/config");
const DEV_FALLBACK = 'dev-access-secret';
exports.default = (0, config_1.registerAs)('jwt', () => {
    const accessSecret = process.env.JWT_ACCESS_SECRET ??
        (process.env.NODE_ENV === 'production' ? undefined : DEV_FALLBACK);
    const refreshSecret = process.env.JWT_REFRESH_SECRET ??
        (process.env.NODE_ENV === 'production' ? undefined : 'dev-refresh-secret');
    if (!accessSecret || !refreshSecret) {
        throw new Error('JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be set in production.');
    }
    if (accessSecret === DEV_FALLBACK ||
        refreshSecret === 'dev-refresh-secret') {
        // eslint-disable-next-line no-console
        console.warn('[jwt.config] Using INSECURE dev fallback secrets. Set JWT_*_SECRET in production.');
    }
    return {
        accessSecret,
        refreshSecret,
        accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN ?? '15m',
        refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '7d',
    };
});
//# sourceMappingURL=jwt.config.js.map