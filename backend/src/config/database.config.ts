import { registerAs } from '@nestjs/config';

export default registerAs('database', () => ({
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  username: process.env.DB_USER ?? 'wetravellers',
  password: process.env.DB_PASSWORD ?? 'wetravellers',
  database: process.env.DB_NAME ?? 'wetravellers',
}));
