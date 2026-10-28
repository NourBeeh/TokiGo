"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("@nestjs/config");
exports.default = (0, config_1.registerAs)('database', () => ({
    host: process.env.DB_HOST ?? 'localhost',
    port: Number(process.env.DB_PORT ?? 5432),
    username: process.env.DB_USER ?? 'wetravellers',
    password: process.env.DB_PASSWORD ?? 'wetravellers',
    database: process.env.DB_NAME ?? 'wetravellers',
}));
//# sourceMappingURL=database.config.js.map