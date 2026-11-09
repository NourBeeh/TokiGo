import 'reflect-metadata';
import { config as loadEnv } from 'dotenv';
import { join } from 'path';
import { DataSource } from 'typeorm';

/**
 * TypeORM DataSource for the migration CLI.
 *
 * The NestJS runtime builds its own connection in `app.module.ts`; this file
 * exists so `typeorm migration:run|revert|show|generate` has a single, honest
 * source of connection settings. It always runs with `synchronize: false` —
 * schema changes come from migrations only.
 *
 * Connection settings come from the same `DB_*` environment variables the
 * runtime uses (see `src/config/database.config.ts`), loaded from `.env` in
 * the backend directory or the repository root.
 */
loadEnv({ path: join(process.cwd(), '.env') });
loadEnv({ path: join(process.cwd(), '..', '.env') });

for (const key of ['DB_PASSWORD', 'DB_USER', 'DB_NAME']) {
  if (!process.env[key]) {
    throw new Error(`${key} must be set to run migrations.`);
  }
}

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  username: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  // All entities, so `migration:generate` can diff against the real schema.
  entities: [join(__dirname, '..', '**', '*.entity.{ts,js}')],
  migrations: [join(__dirname, 'migrations', '*.{ts,js}')],
  migrationsTableName: 'migrations',
  synchronize: false,
});
