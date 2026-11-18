import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Job, Queue, QueueOptions } from 'bullmq';

/**
 * Shared BullMQ queue registry (high-load refactor).
 *
 * One Redis connection per queue (BullMQ requires `maxRetriesPerRequest:
 * null` on blocking connections, so a dedicated connection is mandatory).
 * Queues are created lazily. When Redis is not provisioned the service reports
 * `enqueue` as failed and callers fall back to inline execution — background
 * work must never become a hard dependency for correctness.
 */
@Injectable()
export class BullQueueService implements OnModuleDestroy {
  private readonly logger = new Logger(BullQueueService.name);
  private readonly queues = new Map<string, Queue>();

  constructor(private readonly config: ConfigService) {}

  /** True when a Redis connection has been provisioned for queues. */
  isConfigured(): boolean {
    return Boolean(
      process.env.REDIS_URL?.trim() || process.env.REDIS_HOST?.trim(),
    );
  }

  private connection(): any {
    const url = process.env.REDIS_URL?.trim();
    if (url) {
      const parsed = new URL(url);
      return {
        host: parsed.hostname,
        port: Number(parsed.port || 6379),
        username: parsed.username || undefined,
        password: parsed.password || process.env.REDIS_PASSWORD || undefined,
        maxRetriesPerRequest: null,
        enableOfflineQueue: false,
      };
    }
    return {
      host: process.env.REDIS_HOST ?? 'localhost',
      port: Number(process.env.REDIS_PORT ?? 6379),
      password: process.env.REDIS_PASSWORD || undefined,
      maxRetriesPerRequest: null,
      enableOfflineQueue: false,
    };
  }

  getQueue(name: string): Queue {
    const existing = this.queues.get(name);
    if (existing) return existing;
    const queue = new Queue(name, {
      connection: this.connection(),
      defaultJobOptions: {
        attempts: 5,
        backoff: { type: 'exponential', delay: 2_000 },
        removeOnComplete: 1000,
        removeOnFail: 5000,
      },
    });
    this.queues.set(name, queue);
    return queue;
  }

  /**
   * Enqueue a job. Returns null when the queue is unavailable so the caller
   * can run the work inline instead of failing the request.
   */
  async enqueue<T>(
    queueName: string,
    jobName: string,
    data: T,
    opts: {
      jobId?: string;
      attempts?: number;
      backoff?: { type: 'exponential' | 'fixed'; delayMs: number };
      delayMs?: number;
      removeOnComplete?: boolean | number;
      removeOnFail?: boolean | number;
    } = {},
  ): Promise<Job<T> | null> {
    try {
      return await this.getQueue(queueName).add(jobName, data, {
        jobId: opts.jobId,
        attempts: opts.attempts,
        backoff: opts.backoff,
        delay: opts.delayMs,
        removeOnComplete: opts.removeOnComplete ?? 1000,
        removeOnFail: opts.removeOnFail ?? 5000,
      });
    } catch (error) {
      this.logger.warn(
        `Queue '${queueName}' unavailable, falling back to inline work: ${
          (error as Error).message
        }`,
      );
      return null;
    }
  }

  async isAvailable(): Promise<boolean> {
    try {
      const queue = this.getQueue('health');
      await queue.getJobCounts();
      return true;
    } catch {
      return false;
    }
  }

  async onModuleDestroy(): Promise<void> {
    for (const queue of this.queues.values()) {
      try {
        await queue.close();
      } catch {
        // Already closed/unreachable.
      }
    }
    this.queues.clear();
  }
}
