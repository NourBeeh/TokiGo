import { Logger } from '@nestjs/common';
import Redis from 'ioredis';

/**
 * Cache stampede protection (high-load refactor, Phase 1).
 *
 * Two complementary mechanisms:
 *
 *  1. `singleFlight` — an in-process map that lets concurrent identical work
 *     share ONE promise. This is the fast path and works even with no Redis.
 *
 *  2. `acquire`/`release` — a short-lived distributed lock (Redis `SET NX PX`
 *     + token-checked Lua release) so several application instances cannot
 *     stampede the same external provider call at once. Without Redis it
 *     degrades to a per-process map; correctness never depends on the lock.
 *
 * Locks are always released with their ownership token and always expire, so
 * a crashed worker can never hold one forever.
 */
export class CacheLockService {
  private readonly logger = new Logger(CacheLockService.name);
  private readonly flights = new Map<string, Promise<unknown>>();
  private readonly memoryLocks = new Map<string, { token: string; expireAt: number }>();

  private readonly client: Redis | null = null;
  private redisHealthy = false;

  /** Atomic compare-and-delete: only the lock owner releases it. */
  private static readonly RELEASE_SCRIPT = `
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("del", KEYS[1])
    else
      return 0
    end`;

  constructor() {
    const url = process.env.REDIS_URL?.trim();
    if (!url && !process.env.REDIS_HOST?.trim()) return;

    const options = {
      lazyConnect: true,
      connectTimeout: 1_500,
      enableOfflineQueue: false,
      maxRetriesPerRequest: 1,
      retryStrategy: (attempt: number) => Math.min(attempt * 500, 5_000),
    };

    try {
      this.client = url
        ? new Redis(url, options)
        : new Redis({
            host: process.env.REDIS_HOST ?? 'localhost',
            port: Number(process.env.REDIS_PORT ?? 6379),
            password: process.env.REDIS_PASSWORD || undefined,
            ...options,
          });
      this.client.on('ready', () => {
        this.redisHealthy = true;
      });
      this.client.on('error', () => {
        this.redisHealthy = false;
      });
      this.client.on('end', () => {
        this.redisHealthy = false;
      });
      void this.client.connect().catch(() => undefined);
    } catch {
      this.client = null;
    }
  }

  /**
   * Run [fn] as the single in-flight execution for [key]. Concurrent callers
   * receive the same promise; the map entry is removed when it settles.
   */
  singleFlight<T>(key: string, fn: () => Promise<T>): Promise<T> {
    const existing = this.flights.get(key);
    if (existing !== undefined) return existing as Promise<T>;

    const job = fn().finally(() => {
      this.flights.delete(key);
    });
    this.flights.set(key, job);
    return job;
  }

  /**
   * Try to acquire the distributed lock for [key].
   * Returns an ownership token, or null when another holder owns it.
   */
  async acquire(key: string, ttlMs: number): Promise<string | null> {
    const token = `${process.pid}-${Date.now()}-${Math.random()
      .toString(36)
      .slice(2)}`;

    if (this.client && this.redisHealthy) {
      try {
        const result = await this.client.set(key, token, 'PX', ttlMs, 'NX');
        return result === 'OK' ? token : null;
      } catch (error) {
        this.redisHealthy = false;
        this.logger.debug(
          `Redis lock acquire failed, using in-process lock: ${
            (error as Error).message
          }`,
        );
      }
    }

    const now = Date.now();
    const held = this.memoryLocks.get(key);
    if (held && held.expireAt > now) return null;
    this.memoryLocks.set(key, { token, expireAt: now + ttlMs });
    return token;
  }

  /** Release the lock only if [token] still owns it. */
  async release(key: string, token: string): Promise<void> {
    const held = this.memoryLocks.get(key);
    if (held && held.token === token) this.memoryLocks.delete(key);

    if (this.client && this.redisHealthy) {
      try {
        await this.client.eval(CacheLockService.RELEASE_SCRIPT, 1, key, token);
      } catch (error) {
        this.redisHealthy = false;
        this.logger.debug(
          `Redis lock release failed: ${(error as Error).message}`,
        );
      }
    }
  }

  /**
   * Execute [fn] under the distributed lock. When the lock is not acquired,
   * returns null immediately — callers decide how to wait/fall back.
   */
  async withLock<T>(
    key: string,
    ttlMs: number,
    fn: () => Promise<T>,
  ): Promise<{ acquired: true; value: T } | { acquired: false }> {
    const token = await this.acquire(key, ttlMs);
    if (token === null) return { acquired: false };
    try {
      return { acquired: true, value: await fn() };
    } finally {
      await this.release(key, token);
    }
  }
}
