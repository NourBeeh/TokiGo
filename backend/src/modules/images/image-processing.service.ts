import { Injectable } from '@nestjs/common';
import { createHash } from 'crypto';
import { BullQueueService } from '../../common/queue/bull-queue.service';
import {
  IMAGE_PROCESSING_QUEUE,
  JOB_IMAGE_OPTIMIZE,
} from '../../common/queue/queue.constants';
import { ImageService, OptimizedImageResult } from './image.service';

/**
 * Background image processing (high-load refactor).
 *
 * The job id is derived from the source URL so a repeated request for the same
 * photo cannot enqueue duplicate work. When Redis is unavailable the work runs
 * inline — an image endpoint must never fail merely because the queue is down.
 */
@Injectable()
export class ImageProcessingService {
  constructor(
    private readonly images: ImageService,
    private readonly queues: BullQueueService,
  ) {}

  async request(input: {
    sourceUrl: string;
    hotelId?: string | null;
    width?: number;
  }): Promise<
    | { queued: true; jobId: string }
    | { queued: false; image: OptimizedImageResult }
  > {
    const sourceHash = createHash('sha256')
      .update(input.sourceUrl)
      .digest('hex');
    const jobId = `image:${sourceHash.slice(0, 32)}`;

    const job = await this.queues.enqueue<{
      sourceUrl: string;
      hotelId?: string | null;
      width?: number;
    }>(IMAGE_PROCESSING_QUEUE, JOB_IMAGE_OPTIMIZE, input, {
      jobId,
      attempts: 3,
      backoff: { type: 'exponential', delayMs: 1_000 },
      removeOnComplete: 200,
      removeOnFail: 500,
    });

    if (job) return { queued: true, jobId: job.id ?? jobId };
    return { queued: false, image: await this.images.optimizeAndUpload(input) };
  }
}
