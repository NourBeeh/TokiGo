import { registerAs } from '@nestjs/config';

export default registerAs('database', () => {
  const password = process.env.DB_PASSWORD;
  if (!password) {
    throw new Error('DB_PASSWORD must be set.');
  }
  const username = process.env.DB_USER;
  if (!username) {
    throw new Error('DB_USER must be set.');
  }
  const database = process.env.DB_NAME;
  if (!database) {
    throw new Error('DB_NAME must be set.');
  }
  return {
    host: process.env.DB_HOST ?? 'localhost',
    port: Number(process.env.DB_PORT ?? 5432),
    username,
    password,
    database,
  };
});
