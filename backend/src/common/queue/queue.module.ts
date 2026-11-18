import { Global, Module } from '@nestjs/common';
import { BullQueueService } from './bull-queue.service';
import { BullWorkerRegistry } from './bull-worker.registry';

/**
 * Global queue infrastructure. Feature modules inject `BullQueueService` to
 * enqueue and `BullWorkerRegistry` to host their worker; both are closed on
 * shutdown so a deploy never orphans an open Redis connection.
 */
@Global()
@Module({
  providers: [BullQueueService, BullWorkerRegistry],
  exports: [BullQueueService, BullWorkerRegistry],
})
export class QueueModule {}
