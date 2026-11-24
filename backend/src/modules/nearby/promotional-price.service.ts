import { Logger } from '@nestjs/common';
import { NightWindow } from './geo';

/**
 * Promotional one-night price discovery (R3).
 *
 * The provider's `/hotels/min-rates` returns the cheapest rate for a list of
 * hotels over ONE window. The Home price is the minimum across exactly seven
 * consecutive ONE-NIGHT windows, so the service makes one bounded call per
 * window and keeps the minimum itself. A multi-night total is never divided by
 * a window.
 *
 * Failure policy: a failed window/chunk is recorded and skipped; prices from
 * the successful windows still produce an honest promotional figure. A hotel
 * with no valid price in any window is absent — never replaced by 0 or a
 * guess. `partialFailure` is surfaced so the API can avoid caching an
 * incomplete snapshot.
 */

export interface PromotionalPriceProvider {
  minRates(input: {
    hotelIds: string[];
    checkIn: string;
    checkOut: string;
    currency: string;
    guestNationality: string;
    occupancies: Array<{ adults: number; children?: number[] }>;
    timeout?: number;
  }): Promise<{ success: boolean; data?: Array<{ hotelId: string; price: number }>; error?: string }>;
}

export interface PromotionalPriceParams {
  hotelIds: string[];
  windows: NightWindow[];
  currency: string;
  nationality: string;
  occupancy: number;
  rooms: number;
  /** Overall per-call timeout in milliseconds. */
  timeoutMs?: number;
}

export interface PromotionalPriceResult {
  /** hotelId → minimum valid one-night price. */
  prices: Map<string, number>;
  searchedFromDate: string;
  searchedToDate: string;
  windowsSucceeded: number;
  windowsFailed: number;
  partialFailure: boolean;
}

const DEFAULT_CHUNK_SIZE = 20;
const DEFAULT_CONCURRENCY = 3;
const DEFAULT_TIMEOUT_MS = 20_000;

function intFromEnv(name: string, fallback: number, max: number): number {
  const value = Number(process.env[name]);
  if (!Number.isFinite(value) || value <= 0) return fallback;
  return Math.min(Math.floor(value), max);
}

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    out.push(items.slice(index, index + size));
  }
  return out;
}

/** Bounded parallelism; results keep their input order. */
async function mapLimit<T, R>(
  items: T[],
  limit: number,
  worker: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let next = 0;
  const runners = Array.from(
    { length: Math.max(1, Math.min(limit, items.length)) },
    async () => {
      while (next < items.length) {
        const index = next++;
        results[index] = await worker(items[index]);
      }
    },
  );
  await Promise.all(runners);
  return results;
}

function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => {
      const timer = setTimeout(
        () => reject(new Error(`${label} timed out after ${ms}ms`)),
        ms,
      );
      if (typeof timer.unref === 'function') timer.unref();
    }),
  ]);
}

export class PromotionalPriceService {
  private readonly logger = new Logger(PromotionalPriceService.name);

  constructor(private readonly provider: PromotionalPriceProvider) {}

  async discoverMinimumOneNightRates(
    params: PromotionalPriceParams,
  ): Promise<PromotionalPriceResult> {
    const hotelIds = [...new Set(params.hotelIds)].filter(Boolean).slice(0, 100);
    const windows = params.windows.slice(0, 7);
    const searchedFromDate = windows[0]?.checkIn ?? '';
    const searchedToDate = windows[windows.length - 1]?.checkOut ?? '';

    const empty: PromotionalPriceResult = {
      prices: new Map(),
      searchedFromDate,
      searchedToDate,
      windowsSucceeded: 0,
      windowsFailed: 0,
      partialFailure: false,
    };
    if (hotelIds.length === 0 || windows.length === 0) return empty;

    const chunkSize = intFromEnv('NEARBY_MIN_RATES_CHUNK', DEFAULT_CHUNK_SIZE, 50);
    const concurrency = intFromEnv('NEARBY_PROMO_CONCURRENCY', DEFAULT_CONCURRENCY, 6);
    const timeoutMs = params.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    const occupancies = Array.from({ length: Math.max(1, params.rooms) }, () => ({
      adults: Math.max(1, params.occupancy),
      children: [],
    }));

    interface Job {
      window: NightWindow;
      hotelIds: string[];
      windowIndex: number;
    }
    const jobs: Job[] = [];
    windows.forEach((window, windowIndex) => {
      for (const hotelIdsChunk of chunk(hotelIds, chunkSize)) {
        jobs.push({ window, hotelIds: hotelIdsChunk, windowIndex });
      }
    });

    const settled = await mapLimit(jobs, concurrency, async (job) => {
      try {
        const result = await withTimeout(
          this.provider.minRates({
            hotelIds: job.hotelIds,
            checkIn: job.window.checkIn,
            checkOut: job.window.checkOut,
            currency: params.currency,
            guestNationality: params.nationality,
            occupancies,
            timeout: Math.ceil(timeoutMs / 1000),
          }),
          timeoutMs,
          `min-rates ${job.window.checkIn}`,
        );
        if (!result?.success) {
          return { job, ok: false as const, error: result?.error ?? 'provider error' };
        }
        const prices = (result.data ?? []).filter(
          (entry) =>
            entry &&
            entry.hotelId.length > 0 &&
            Number.isFinite(entry.price) &&
            entry.price > 0,
        );
        return { job, ok: true as const, prices };
      } catch (error) {
        return { job, ok: false as const, error: (error as Error)?.message ?? String(error) };
      }
    });

    const prices = new Map<string, number>();
    const windowOk = new Array<boolean>(windows.length).fill(false);
    let windowsFailed = 0;

    for (const result of settled) {
      if (!result.ok) {
        windowsFailed += 1;
        this.logger.warn(
          `Promotional window ${result.job.window.checkIn} chunk failed: ${result.error}`,
        );
        continue;
      }
      windowOk[result.job.windowIndex] = true;
      for (const entry of result.prices) {
        const existing = prices.get(entry.hotelId);
        if (existing === undefined || entry.price < existing) {
          prices.set(entry.hotelId, entry.price);
        }
      }
    }

    const windowsSucceeded = windowOk.filter(Boolean).length;
    return {
      prices,
      searchedFromDate,
      searchedToDate,
      windowsSucceeded,
      windowsFailed,
      partialFailure: windowsFailed > 0,
    };
  }
}
