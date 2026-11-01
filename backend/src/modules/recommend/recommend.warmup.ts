import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { RecommendedHotelService } from './recommended-hotel.service';

/** Markets warmed at boot — the same set the Home defaults to. */
const WARM_MARKETS = ['EG', 'AE', 'SA', 'TR', 'GB'];

/** Let the HTTP server finish binding before spending provider budget. */
const START_DELAY_MS = 2_000;

/**
 * Optional cold-start warmer for the Home rail.
 *
 * A cold `/home/recommended` request fans out to the provider for every city
 * in the market (~0.7–5s). Warming the top markets once after deploy means the
 * first real traveller gets the warm path (~80ms) instead of the provider path.
 *
 * Off by default (`WARM_HOME_ON_BOOT=true` enables it) so tests and laptops do
 * not call a paid provider on every restart.
 */
@Injectable()
export class RecommendWarmupService implements OnApplicationBootstrap {
  private readonly logger = new Logger(RecommendWarmupService.name);

  constructor(private readonly recommended: RecommendedHotelService) {}

  onApplicationBootstrap(): void {
    if (!isEnabled(process.env.WARM_HOME_ON_BOOT)) return;

    const timer = setTimeout(() => {
      void this.warm();
    }, START_DELAY_MS);
    // Never keep the process alive for a warmup.
    timer.unref?.();
  }

  private async warm(): Promise<void> {
    for (const countryCode of WARM_MARKETS) {
      const started = Date.now();
      try {
        const result = await this.recommended.recommend({
          countryCode,
          limit: 6,
        });
        this.logger.log(
          `Home rail warmed for ${countryCode}: ${result.hotels.length} hotels in ${
            Date.now() - started
          }ms`,
        );
      } catch (error) {
        this.logger.warn(
          `Home rail warmup failed for ${countryCode}: ${
            (error as Error).message
          }`,
        );
      }
    }
  }
}

function isEnabled(value?: string | null): boolean {
  if (!value) return false;
  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase());
}
