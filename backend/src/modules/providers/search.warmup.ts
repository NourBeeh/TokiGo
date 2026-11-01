import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { SearchService } from './search.service';
import { COUNTRY_CITIES } from '../../common/market/popular-cities';

/** Markets warmed by default — the same launch set the Home rail uses. */
const DEFAULT_MARKETS = ['EG', 'AE', 'SA', 'TR', 'GB'];

/** Let the HTTP server bind before spending provider budget. */
const START_DELAY_MS = 5_000;

/** Gap between two provider calls: Nuitee rate-limits bursts. */
const BETWEEN_CALLS_MS = 400;

/** How far ahead the weekend windows start (this weekend + next). */
const DEFAULT_WEEKS = 2;

/** Cities per tick, so one tick cannot cost 20 provider calls. */
const DEFAULT_BATCH = 4;

const DAY_MS = 24 * 60 * 60 * 1000;

export interface WarmupTarget {
  city: string;
  country: string;
  checkIn: string;
  checkOut: string;
}

/**
 * Optional search-cache warmer.
 *
 * A cold `POST /search/hotels` costs 3.5–5s because that is Nuitee's own
 * latency; no cache can make the FIRST call faster. What a warmer can do is
 * make sure the first *traveller* is not the one paying for it: it runs the
 * same search for the popular cities of the launch markets over the next
 * weekend windows and leaves a warm entry behind.
 *
 * Off by default (`WARM_SEARCH_ON_BOOT=true` enables it) so tests, laptops and
 * CI never call a paid provider. `SEARCH_WARM_INTERVAL_MINUTES` re-runs it on a
 * timer (e.g. 60) with a rotating batch of cities.
 *
 * The warmed params are deliberately identical to what the app sends, and the
 * cache key is canonical, so `Cairo` / `cairo ` / `CAIRO` all hit the same
 * entry regardless of field order.
 */
@Injectable()
export class SearchWarmupService
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(SearchWarmupService.name);

  private timer?: NodeJS.Timeout;
  private startTimer?: NodeJS.Timeout;
  private running = false;
  private cursor = 0;

  constructor(private readonly search: SearchService) {}

  onApplicationBootstrap(): void {
    if (!isEnabled(process.env.WARM_SEARCH_ON_BOOT)) return;

    this.startTimer = setTimeout(() => {
      void this.tick();
      const minutes = Number(process.env.SEARCH_WARM_INTERVAL_MINUTES);
      if (Number.isFinite(minutes) && minutes > 0) {
        this.timer = setInterval(() => void this.tick(), minutes * 60_000);
        // Never keep the process alive just to warm a cache.
        this.timer.unref?.();
      }
    }, START_DELAY_MS);
    this.startTimer.unref?.();
  }

  onApplicationShutdown(): void {
    if (this.startTimer) clearTimeout(this.startTimer);
    if (this.timer) clearInterval(this.timer);
  }

  /** One warmup pass. Public so a script or a test can drive it directly. */
  async tick(): Promise<void> {
    if (this.running) return;
    this.running = true;

    const started = Date.now();
    const targets = this.targetsForTick();
    let warmed = 0;

    try {
      for (const target of targets) {
        const began = Date.now();
        try {
          const result = await this.search.searchHotels(
            {
              city: target.city,
              country: target.country,
              checkIn: target.checkIn,
              checkOut: target.checkOut,
              guests: 2,
              rooms: 1,
              market: target.country,
            },
            target.country,
          );
          // `failures` non-empty means the entry was NOT cached; say so
          // instead of reporting a warm success that will be paid again.
          const failures = (result as { failures?: unknown[] })?.failures ?? [];
          const offers = countOffers(result);
          if (failures.length === 0) {
            warmed += 1;
            this.logger.log(
              `Warmed ${target.city}/${target.country} ${target.checkIn}: ` +
                `${offers} offers in ${Date.now() - began}ms`,
            );
          } else {
            this.logger.warn(
              `Warmup for ${target.city}/${target.country} had ${failures.length} ` +
                `provider failure(s) — not cached (${Date.now() - began}ms)`,
            );
          }
        } catch (error) {
          this.logger.warn(
            `Warmup failed for ${target.city}/${target.country}: ${
              (error as Error).message
            }`,
          );
        }
        await sleep(BETWEEN_CALLS_MS);
      }
    } finally {
      this.running = false;
      this.logger.log(
        `Search warmup pass: ${warmed}/${targets.length} cached in ${
          Date.now() - started
        }ms`,
      );
    }
  }

  /**
   * Rotating slice of (city × weekend) targets. The cursor advances every tick
   * so a long-running instance covers every city without a thundering herd of
   * provider calls at boot.
   */
  private targetsForTick(): WarmupTarget[] {
    const all = allTargets();
    if (all.length === 0) return [];

    const batch = Math.min(
      Math.max(Number(process.env.SEARCH_WARM_BATCH) || DEFAULT_BATCH, 1),
      all.length,
    );

    const slice: WarmupTarget[] = [];
    for (let i = 0; i < batch; i += 1) {
      slice.push(all[(this.cursor + i) % all.length]);
    }
    this.cursor = (this.cursor + batch) % all.length;
    return slice;
  }
}

/** Every (city × upcoming weekend) pair the warmer may use. */
export function allTargets(now: Date = new Date()): WarmupTarget[] {
  const markets = (process.env.SEARCH_WARM_MARKETS || DEFAULT_MARKETS.join(','))
    .split(',')
    .map((code) => code.trim().toUpperCase())
    .filter((code) => /^[A-Z]{2}$/.test(code));

  const weeks = Math.max(
    Number(process.env.SEARCH_WARM_WEEKS) || DEFAULT_WEEKS,
    1,
  );

  const targets: WarmupTarget[] = [];
  for (let week = 0; week < weeks; week += 1) {
    const { checkIn, checkOut } = weekendWindow(week, now);
    for (const country of markets) {
      for (const city of COUNTRY_CITIES[country] ?? []) {
        targets.push({ city, country, checkIn, checkOut });
      }
    }
  }
  return targets;
}

/**
 * Friday → Sunday of the upcoming weekend, `weeksAhead` weeks from now.
 * Weekend stays are the demand peak, so warming them helps the most people
 * per provider call.
 */
export function weekendWindow(
  weeksAhead: number,
  now: Date = new Date(),
): { checkIn: string; checkOut: string } {
  const today = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
  // 0 = Sunday … 6 = Saturday. `|| 7` keeps "today is Friday" in the future.
  const untilFriday = (5 - today.getUTCDay() + 7) % 7 || 7;
  const friday = new Date(
    today.getTime() + (untilFriday + weeksAhead * 7) * DAY_MS,
  );
  const sunday = new Date(friday.getTime() + 2 * DAY_MS);
  return { checkIn: isoDay(friday), checkOut: isoDay(sunday) };
}

function isoDay(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function countOffers(result: unknown): number {
  const successes = (result as { successes?: Array<{ data?: unknown[] }> })
    ?.successes;
  if (!Array.isArray(successes)) return 0;
  return successes.reduce(
    (sum, entry) => sum + (Array.isArray(entry?.data) ? entry.data.length : 0),
    0,
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    const timer = setTimeout(resolve, ms);
    timer.unref?.();
  });
}

function isEnabled(value?: string | null): boolean {
  if (!value) return false;
  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase());
}
