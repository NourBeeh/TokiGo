import { registerAs } from '@nestjs/config';

/**
 * Meilisearch is metadata-search infrastructure. It is optional: when
 * MEILISEARCH_HOST is unset the discovery path falls back to PostgreSQL and
 * the index service reports itself disabled instead of failing requests.
 */
export default registerAs('meilisearch', () => ({
  host: process.env.MEILISEARCH_HOST ?? '',
  apiKey: process.env.MEILISEARCH_API_KEY ?? '',
  index: process.env.MEILISEARCH_HOTEL_INDEX ?? 'hotels',
}));
