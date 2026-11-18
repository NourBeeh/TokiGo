/** BullMQ queue names (high-load refactor). */
export const HOTEL_METADATA_SYNC_QUEUE = 'hotel-metadata-sync';
export const IMAGE_PROCESSING_QUEUE = 'image-processing';
export const NOTIFICATIONS_QUEUE = 'notifications';
export const BOOKING_PIPELINE_QUEUE = 'booking-pipeline';
export const RECONCILIATION_QUEUE = 'reconciliation';

/** Job name constants keep producers and workers in lockstep. */
export const JOB_HOTEL_SYNC_CITY = 'sync-city';
export const JOB_IMAGE_OPTIMIZE = 'optimize-image';
export const JOB_NOTIFY_EVENT = 'notify-event';
export const JOB_BOOKING_PIPELINE = 'run-pipeline';
export const JOB_RECONCILE_ATTEMPT = 'reconcile-attempt';
