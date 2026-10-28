import { Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { CacheProvider } from './cache.provider';

@Injectable()
export class RedisCacheProvider implements CacheProvider {
  private client: Redis;

  constructor() {
    this.client = new Redis({
      host: process.env.REDIS_HOST ?? 'localhost',
      port: Number(process.env.REDIS_PORT ?? 6379),
    });
  }

  async get<T>(key: string): Promise<T | null> {
    const val = await this.client.get(key);
    return val ? (JSON.parse(val) as T) : null;
  }

  async set<T>(key: string, value: T, ttlSeconds?: number): Promise<void> {
    const data = JSON.stringify(value);
    if (ttlSeconds) {
      await this.client.setex(key, ttlSeconds, data);
    } else {
      await this.client.set(key, data);
    }
  }

  async delete(key: string): Promise<void> {
    await this.client.del(key);
  }

  async invalidate(pattern: string): Promise<void> {
    const keys = await this.client.keys(pattern);
    if (keys.length) await this.client.del(...keys);
  }
}
