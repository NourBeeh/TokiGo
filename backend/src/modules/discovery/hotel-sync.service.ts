import { Injectable } from '@nestjs/common';
import { createHash } from 'crypto';
import { BullQueueService } from '../../common/queue/bull-queue.service';
import {
  HOTEL_METADATA_SYNC_QUEUE,
  JOB_HOTEL_SYNC_CITY,
} from '../../common/queue/queue.constants';
import { HotelDiscoveryService } from './hotel-discovery.service';

/**
 * Background hotel-metadata synchronization (high-load refactor).
 *
 * Enqueues an idempotent job per city; when the queue is unavailable (no
 * Redis) it runs inline so discovery still converges instead of failing.
 */
@Injectable()
export class HotelSyncService {
  constructor(
    private readonly discovery: HotelDiscoveryService,
    private readonly queues: BullQueueService,
  ) {}

  async requestCitySync(input: {
    city: string;
    country?: string;
    language?: string;
  }): Promise<
    | { queued: true; jobId: string }
    | { queued: false; synced: number; indexed: number }
  > {
    const canonical = `${input.city.trim().toLowerCase()}|${(input.country ?? '')
      .trim()
      .toUpperCase()}|${input.language ?? ''}`;
    const jobId = `sync-city:${createHash('sha256').update(canonical).digest('hex').slice(0, 32)}`;

    const job = await this.queues.enqueue<{
      city: string;
      country?: string;
      language?: string;
    }>(HOTEL_METADATA_SYNC_QUEUE, JOB_HOTEL_SYNC_CITY, input, {
      jobId,
      attempts: 3,
      backoff: { type: 'exponential', delayMs: 5_000 },
      removeOnComplete: 200,
      removeOnFail: 500,
    });

    if (job) return { queued: true, jobId: job.id ?? jobId };
    return { queued: false, ...(await this.discovery.syncCity(input)) };
  }
}
