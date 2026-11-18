import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { BullWorkerRegistry } from '../../common/queue/bull-worker.registry';
import { BullQueueService } from '../../common/queue/bull-queue.service';
import {
  HOTEL_METADATA_SYNC_QUEUE,
  JOB_HOTEL_SYNC_CITY,
} from '../../common/queue/queue.constants';
import { HotelDiscoveryService } from './hotel-discovery.service';

/**
 * BullMQ worker for hotel metadata synchronization.
 *
 * Concurrency is deliberately bounded (default 2) so a city sweep can never
 * stampede the provider. The worker only starts when Redis is configured;
 * otherwise `HotelSyncService` runs inline and nothing is lost.
 */
@Injectable()
export class HotelSyncWorker implements OnModuleInit {
  private readonly logger = new Logger(HotelSyncWorker.name);

  constructor(
    private readonly workers: BullWorkerRegistry,
    private readonly queues: BullQueueService,
    private readonly discovery: HotelDiscoveryService,
  ) {}

  onModuleInit(): void {
    if (!this.queues.isConfigured()) {
      this.logger.log('Redis not configured — hotel sync jobs run inline.');
      return;
    }

    this.workers.register<{
      city: string;
      country?: string;
      language?: string;
    }>(
      HOTEL_METADATA_SYNC_QUEUE,
      async (job) => {
        if (job.name !== JOB_HOTEL_SYNC_CITY) {
          throw new Error(`Unknown hotel sync job '${job.name}'`);
        }
        return this.discovery.syncCity(job.data);
      },
      {
        concurrency: Number(process.env.HOTEL_SYNC_CONCURRENCY ?? 2),
        attempts: 3,
        backoff: { type: 'exponential', delayMs: 5_000 },
      },
    );
  }
}
