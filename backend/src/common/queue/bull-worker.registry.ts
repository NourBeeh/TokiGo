import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { Processor, Worker, WorkerOptions } from 'bullmq';

/**
 * Registry of BullMQ workers owned by the process.
 *
 * Workers are created with deliberately BOUNDED concurrency (never unbounded
 * against an external API) and closed together on shutdown so a deploy never
 * leaves a half-processed job behind without a redelivery path.
 */
@Injectable()
export class BullWorkerRegistry implements OnModuleDestroy {
  private readonly logger = new Logger(BullWorkerRegistry.name);
  private readonly workers: Worker[] = [];

  register<T>(
    queueName: string,
    processor: Processor<T>,
    options: {
      concurrency?: number;
      attempts?: number;
      backoff?: { type: 'exponential' | 'fixed'; delayMs: number };
      lockDurationMs?: number;
    } = {},
  ): Worker<T> {
    const url = process.env.REDIS_URL?.trim();
    const connection = url
      ? (() => {
          const parsed = new URL(url);
          return {
            host: parsed.hostname,
            port: Number(parsed.port || 6379),
            username: parsed.username || undefined,
            password: parsed.password || process.env.REDIS_PASSWORD || undefined,
            maxRetriesPerRequest: null,
            enableOfflineQueue: false,
          };
        })()
      : {
          host: process.env.REDIS_HOST ?? 'localhost',
          port: Number(process.env.REDIS_PORT ?? 6379),
          password: process.env.REDIS_PASSWORD || undefined,
          maxRetriesPerRequest: null,
          enableOfflineQueue: false,
        };

    const worker = new Worker<T>(queueName, processor as any, {
      connection,
      concurrency: Math.max(1, Math.floor(options.concurrency ?? 2)),
      lockDuration: options.lockDurationMs ?? 30_000,
    });

    worker.on('failed', (job, error) => {
      this.logger.error(
        `Job ${job?.id ?? '?'} (${job?.name ?? '?'}) on '${queueName}' failed: ${error.message}`,
      );
    });
    worker.on('completed', (job) => {
      this.logger.debug(`Job ${job.id} (${job.name}) on '${queueName}' completed`);
    });

    this.workers.push(worker);
    return worker;
  }

  async onModuleDestroy(): Promise<void> {
    await Promise.all(
      this.workers.map((worker) =>
        worker.close().catch(() => undefined),
      ),
    );
    this.workers.length = 0;
  }
}
