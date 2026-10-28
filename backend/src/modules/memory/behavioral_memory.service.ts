import { Injectable, Logger } from '@nestjs/common';

import { BehavioralFactKind, behavioralFactKey, nextConfidence, validateBehavioralFact } from './behavioral_facts';
import { MemoryService } from './memory.service';
import { UserMemory } from '../../database/entities/user_memory.entity';

/**
 * Behavioral Memory extraction (Phase 2B).
 *
 * Turns ONE incoming behavioural event into typed, whitelisted memory facts
 * and upserts them through the Phase 2A MemoryService — never a new row per
 * event, never raw payloads, never AI-computed confidence.
 *
 * Failure contract (§19): extraction problems are logged and swallowed by
 * the CALLER (EventsService). An event succeeding must never depend on
 * memory derivation succeeding.
 */
@Injectable()
export class BehavioralMemoryService {
  private readonly logger = new Logger(BehavioralMemoryService.name);

  constructor(private readonly memories: MemoryService) {}

  /**
   * Extracts the typed facts for one event. Returns [] when the payload
   * cannot support any fact (absence is NOT a negative signal — §10).
   * THROWS on invalid facts so the caller's catch can isolate the failure.
   */
  async extractFromEvent(
    userId: string,
    type: string,
    payload: Record<string, any>,
  ): Promise<UserMemory[]> {
    switch (type) {
      case 'hotel_search':
        return this._fromHotelSearch(userId, payload);
      case 'hotel_view':
        return this._fromHotelView(userId, payload);
      case 'hotel_favorite':
        return this._fromHotelFavorite(userId, payload);
      case 'trip_planned':
        return this._fromTripPlanned(userId, payload);
      case 'booking_confirmed':
        return this._fromBookingConfirmed(userId, payload);
      default:
        return [];
    }
  }

  private async _fromHotelSearch(
    userId: string,
    payload: Record<string, any>,
  ): Promise<UserMemory[]> {
    // Validate EVERYTHING first — extraction is atomic: either all the
    // event's facts are recorded or none are (a bad price never leaves a
    // half-written destination fact behind).
    const destination = asString(payload?.destination);
    const min = payload?.minPrice !== undefined || payload?.maxPrice !== undefined
        ? asPrice(payload?.minPrice)
        : undefined;
    const max = payload?.maxPrice !== undefined || payload?.minPrice !== undefined
        ? asPrice(payload?.maxPrice)
        : undefined;

    const out: UserMemory[] = [];
    if (destination) {
      out.push(
        await this._upsertFact(userId, 'preferred_destination', destination, {
          destination,
        }),
      );
    }
    if (payload?.minPrice !== undefined || payload?.maxPrice !== undefined) {
      out.push(await this._upsertBudget(userId, { min, max }));
    }
    return out;
  }

  private async _fromHotelView(
    userId: string,
    payload: Record<string, any>,
  ): Promise<UserMemory[]> {
    const hotelId = asString(payload?.hotelId);
    const title = asString(payload?.title);
    if (!hotelId && !title) return [];
    const subject = hotelId || title!;
    return [
      await this._upsertFact(
        userId,
        'recent_viewed_hotel',
        subject,
        { ...(hotelId ? { hotelId } : {}), ...(title ? { title } : {}) },
        0.35,
      ),
    ];
  }

  private async _fromHotelFavorite(
    userId: string,
    payload: Record<string, any>,
  ): Promise<UserMemory[]> {
    const hotelId = asString(payload?.hotelId);
    const title = asString(payload?.title);
    if (!hotelId && !title) return [];
    const subject = hotelId || title!;
    return [
      await this._upsertFact(
        userId,
        'favorite_hotel',
        subject,
        { ...(hotelId ? { hotelId } : {}), ...(title ? { title } : {}) },
        0.6,
      ),
    ];
  }

  private async _fromTripPlanned(
    userId: string,
    payload: Record<string, any>,
  ): Promise<UserMemory[]> {
    const destination = asString(payload?.destination);
    if (!destination) return [];
    return [
      await this._upsertFact(userId, 'planned_destination', destination, {
        destination,
      }),
    ];
  }

  private async _fromBookingConfirmed(
    userId: string,
    payload: Record<string, any>,
  ): Promise<UserMemory[]> {
    // The STRONGEST behavioural signal (§7): a confirmed booking reinforces
    // the destination preference at booking-level confidence. Only
    // payload-present data is used — no checkout fields that do not exist
    // in the event.
    const destination = asString(payload?.destination);
    if (!destination) return [];
    return [
      await this._upsertFact(
        userId,
        'preferred_destination',
        destination,
        { destination },
        0.9,
      ),
    ];
  }

  /** Budget facts merge with the existing memory (new price wins per side). */
  private async _upsertBudget(
    userId: string,
    patch: { min?: number; max?: number },
  ): Promise<UserMemory> {
    const key = behavioralFactKey('preferred_budget', 'main');
    const existing = await this.memories.findBehavioral(userId, key);
    const current = (existing?.value ?? {}) as Record<string, number>;
    const merged = {
      ...(current.min !== undefined ? { min: current.min } : {}),
      ...(current.max !== undefined ? { max: current.max } : {}),
      ...(patch.min !== undefined ? { min: patch.min } : {}),
      ...(patch.max !== undefined ? { max: patch.max } : {}),
    };
    const validation = validateBehavioralFact('preferred_budget', merged);
    if (!validation.valid) {
      throw new Error(validation.error);
    }
    const confidence = nextConfidence(existing?.confidence, 0.5);
    return this.memories.upsert(userId, {
      type: 'behavior',
      key,
      value: merged,
      source: 'behavior_event',
      confidence,
    });
  }

  private async _upsertFact(
    userId: string,
    kind: BehavioralFactKind,
    subject: string,
    value: Record<string, any>,
    baseConfidence?: number,
  ): Promise<UserMemory> {
    const validation = validateBehavioralFact(kind, value);
    if (!validation.valid) {
      throw new Error(validation.error);
    }
    const key = behavioralFactKey(kind, subject);
    const existing = await this.memories.findBehavioral(userId, key);
    const confidence = nextConfidence(
      existing?.confidence,
      baseConfidence ?? defaultBase(kind),
    );
    return this.memories.upsert(userId, {
      type: 'behavior',
      key,
      value,
      source: 'behavior_event',
      confidence,
    });
  }
}

/** Default base confidence when a fact kind has no per-event override. */
function defaultBase(kind: BehavioralFactKind): number {
  switch (kind) {
    case 'preferred_destination':
      return 0.3; // search-level default
    case 'recent_viewed_hotel':
      return 0.35;
    case 'favorite_hotel':
      return 0.6;
    case 'planned_destination':
      return 0.75;
    case 'preferred_budget':
      return 0.5;
  }
}

function asString(raw: unknown): string | undefined {
  if (typeof raw !== 'string') return undefined;
  const trimmed = raw.trim();
  return trimmed.length > 0 && trimmed.length <= 120 ? trimmed : undefined;
}

/** Present-but-wrongly-typed price fields are a hard error (never silent). */
function asPrice(raw: unknown): number | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== 'number' || !Number.isFinite(raw)) {
    throw new Error('Price fields must be numbers.');
  }
  return raw;
}
