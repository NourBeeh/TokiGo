import { Logger } from '@nestjs/common';
import Redis from 'ioredis';
import { CacheProvider } from './cache.provider';
import { InMemoryCacheProvider } from './in.memory.cache.provider';

/**
 * Redis-backed cache with an in-process fallback.
 *
 * The cache is an optimisation: if Redis is missing, slow to connect, or dies
 * mid-flight, every operation transparently falls back to the in-memory map
 * instead of failing the request. That is what makes `REDIS_HOST` safe to set
 * in an environment where Redis has not been provisioned yet.
 */
export class RedisCacheProvider implements CacheProvider {
  private readonly logger = new Logger(RedisCacheProvider.name);
  private readonly fallback = new InMemoryCacheProvider();
  private readonly client: Redis;
  private healthy = false;

  constructor() {
    const url = process.env.REDIS_URL?.trim();
    const options = {
      lazyConnect: true,
      connectTimeout: 1_500,
      // Never queue commands while disconnected: the fallback should answer
      // immediately, not wait for a socket that may never come back.
      enableOfflineQueue: false,
      maxRetriesPerRequest: 1,
      retryStrategy: (attempt: number) => Math.min(attempt * 500, 5_000),
    };

    this.client = url
      ? new Redis(url, options)
      : new Redis({
          host: process.env.REDIS_HOST ?? 'localhost',
          port: Number(process.env.REDIS_PORT ?? 6379),
          password: process.env.REDIS_PASSWORD || undefined,
          ...options,
        });

    this.client.on('ready', () => {
      this.healthy = true;
      this.logger.log('Redis cache connected');
    });
    this.client.on('error', (error: Error) => {
      if (this.healthy) {
        this.logger.warn(`Redis cache unavailable: ${error.message}`);
      }
      this.healthy = false;
    });
    this.client.on('end', () => {
      this.healthy = false;
    });

    // Connect in the background: boot must not wait for Redis.
    void this.client.connect().catch(() => undefined);
  }

  async get<T>(key: string): Promise<T | null> {
    return this.run(
      async () => {
        const value = await this.client.get(key);
        return value ? (JSON.parse(value) as T) : null;
      },
      () => this.fallback.get<T>(key),
    );
  }

  async set<T>(key: string, value: T, ttlSeconds?: number): Promise<void> {
    return this.run(
      async () => {
        const data = JSON.stringify(value);
        if (ttlSeconds) {
          await this.client.setex(key, ttlSeconds, data);
        } else {
          await this.client.set(key, data);
        }
      },
      () => this.fallback.set<T>(key, value, ttlSeconds),
    );
  }

  async delete(key: string): Promise<void> {
    return this.run(
      () => this.client.del(key).then(() => undefined),
      () => this.fallback.delete(key),
    );
  }

  async invalidate(pattern: string): Promise<void> {
    return this.run(
      async () => {
        // SCAN, not KEYS: never block Redis on a large keyspace.
        let cursor = '0';
        do {
          const [next, keys] = await this.client.scan(
            cursor,
            'MATCH',
            pattern,
            'COUNT',
            200,
          );
          cursor = next;
          if (keys.length > 0) await this.client.del(...keys);
        } while (cursor !== '0');
      },
      () => this.fallback.invalidate(pattern),
    );
  }

  /**
   * Runs [redisOp] while healthy, otherwise [fallbackOp]. Any Redis error
   * demotes the client until its `ready` event fires again.
   */
  private async run<T>(
    redisOp: () => Promise<T>,
    fallbackOp: () => Promise<T>,
  ): Promise<T> {
    if (!this.healthy) return fallbackOp();
    try {
      return await redisOp();
    } catch (error) {
      this.healthy = false;
      this.logger.warn(
        `Redis cache operation failed, using in-memory fallback: ${
          (error as Error).message
        }`,
      );
      return fallbackOp();
    }
  }
}
