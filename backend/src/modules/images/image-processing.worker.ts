import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { BullWorkerRegistry } from '../../common/queue/bull-worker.registry';
import { BullQueueService } from '../../common/queue/bull-queue.service';
import {
  IMAGE_PROCESSING_QUEUE,
  JOB_IMAGE_OPTIMIZE,
} from '../../common/queue/queue.constants';
import { ImageService } from './image.service';

/**
 * Bounded-concurrency image worker. Two workers by default: enough to keep the
 * pipeline moving, never enough to stampede an upstream image host.
 */
@Injectable()
export class ImageProcessingWorker implements OnModuleInit {
  private readonly logger = new Logger(ImageProcessingWorker.name);

  constructor(
    private readonly workers: BullWorkerRegistry,
    private readonly queues: BullQueueService,
    private readonly images: ImageService,
  ) {}

  onModuleInit(): void {
    if (!this.queues.isConfigured()) {
      this.logger.log('Redis not configured — image jobs run inline.');
      return;
    }

    this.workers.register<{
      sourceUrl: string;
      hotelId?: string | null;
      width?: number;
    }>(
      IMAGE_PROCESSING_QUEUE,
      async (job) => {
        if (job.name !== JOB_IMAGE_OPTIMIZE) {
          throw new Error(`Unknown image job '${job.name}'`);
        }
        return this.images.optimizeAndUpload(job.data);
      },
      {
        concurrency: Number(process.env.IMAGE_WORKER_CONCURRENCY ?? 2),
        lockDurationMs: 60_000,
      },
    );
  }
}
