import { Injectable, Logger, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserEvent } from '../../database/entities/user_event.entity';
import { ProfileService } from '../profile/profile.service';
import { BehavioralMemoryService } from '../memory/behavioral_memory.service';

export interface Sig {
  userId?: string;
  deviceId?: string;
  type: string;
  payload: Record<string, any>;
}

@Injectable()
export class EventsService {
  private readonly logger = new Logger(EventsService.name);

  constructor(
    @InjectRepository(UserEvent)
    private readonly events: Repository<UserEvent>,
    private readonly profiles: ProfileService,
    // Phase 2B — optional so existing tests/wiring without the memory layer
    // keep working; absent = extraction silently skipped.
    @Optional() private readonly behavioralMemory?: BehavioralMemoryService,
  ) {}

  /** Records a behavioural signal and folds it into the user profile. */
  async track(sig: Sig): Promise<void> {
    await this.events.save(
      this.events.create({
        userId: sig.userId,
        deviceId: sig.userId ? undefined : sig.deviceId,
        type: sig.type,
        payload: sig.payload ?? {},
      }),
    );

    if (!sig.userId) return; // Guests: no server memory (Phase 1C decision).

    // Fold signals into the derived profile — never let aggregation failure
    // fail the event itself.
    try {
      await this.applyToProfile(sig);
    } catch (error) {
      this.logger.warn(
        `Profile aggregation skipped (${sig.type}): ${(error as Error).message}`,
      );
    }

    // Phase 2B — derive typed behavioral memories from the same event.
    // Isolated by design: memory failure NEVER breaks the event flow (§19).
    const memory = this.behavioralMemory;
    if (memory) {
      try {
        await memory.extractFromEvent(sig.userId, sig.type, sig.payload ?? {});
      } catch (error) {
        this.logger.warn(
          `Behavioral memory extraction skipped (${sig.type}): ${(error as Error).message}`,
        );
      }
    }
  }

  async recent(userId: string, limit = 50): Promise<UserEvent[]> {
    return this.events.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: Math.min(Math.max(limit, 1), 200),
    });
  }

  async recentByDevice(deviceId: string, limit = 50): Promise<UserEvent[]> {
    return this.events.find({
      where: { deviceId },
      order: { createdAt: 'DESC' },
      take: Math.min(Math.max(limit, 1), 200),
    });
  }

  /** Derives profile signals from one event. Throws nothing by design. */
  private async applyToProfile(sig: Sig): Promise<void> {
    const userId = sig.userId!;
    const payload = sig.payload ?? {};
    switch (sig.type) {
      case 'hotel_search': {
        const searches = await this.profiles.getOrCreate(userId);
        const top = searches.derived?.topDestinations ?? [];
        const dest = payload.destination;
        if (dest && typeof dest === 'string') {
          const next = top.filter((d: string) => d !== dest);
          next.unshift(dest);
          const budget = candidateBudget(searches.derived, payload);
          await this.profiles.updateDerived(userId, {
            topDestinations: next.slice(0, 6),
            lastDestination: dest,
            budget,
          });
        }
        break;
      }
      case 'hotel_view': {
        await this.profiles.updateDerived(userId, {
          lastViewedHotel: payload.hotelId ?? payload.title,
          viewedAt: new Date().toISOString(),
        });
        break;
      }
      case 'hotel_favorite': {
        if (payload.hotelId) {
          const profile = await this.profiles.getOrCreate(userId);
          const favs = profile.derived?.favoriteHotels ?? [];
          if (!favs.includes(payload.hotelId)) {
            await this.profiles.updateDerived(userId, {
              favoriteHotels: [...favs, payload.hotelId].slice(-20),
            });
          }
        }
        break;
      }
      case 'booking_confirmed':
      case 'trip_planned': {
        const dest = payload.destination;
        if (dest) {
          await this.profiles.updateDerived(userId, {
            upcomingDestination: dest,
            plannedAt: new Date().toISOString(),
          });
        }
        break;
      }
    }
  }
}

function candidateBudget(derived: any, payload: Record<string, any>): {
  min?: number;
  max?: number;
} {
  const current = derived?.budget ?? {};
  const min = typeof payload.minPrice === 'number' ? payload.minPrice : current.min;
  const max = typeof payload.maxPrice === 'number' ? payload.maxPrice : current.max;
  return { min, max };
}
