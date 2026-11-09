import { Injectable } from '@nestjs/common';
import {
  BookingProvider,
  BookingRevalidation,
  CancelBookingInput,
  CreatedBooking,
  CreateBookingInput,
  RevalidationContext,
} from '../../../common/providers/booking-provider.interface';
import { ProviderResult } from '../../../common/providers/provider.result';
import { NuiteeFlightService } from '../../nuitee/nuitee.flight.service';

/** LiteAPI's integer passenger types (`0=adult, 1=child, 2=infant`). */
const NUITEE_PASSENGER_TYPE: Record<string, number> = {
  adult: 0,
  child: 1,
  infant: 2,
  infant_without_seat: 2,
};

/**
 * LiteAPI's accepted identity-document types, mapped from the tokens the
 * funnel collects. `national_id` maps to LiteAPI's `id`; anything the
 * provider does not accept is omitted (never rewritten into a guess).
 */
const NUITEE_DOCUMENT_TYPE: Record<string, string> = {
  passport: 'passport',
  national_id: 'id',
};

/** LiteAPI's accepted titles (uppercase). */
const NUITEE_TITLES = new Set(['MR', 'MS', 'MRS', 'MISS']);

/** LiteAPI's accepted gender values. */
const NUITEE_GENDERS = new Set(['M', 'F', 'X']);

/**
 * Prepare-time placeholder. Travellers do not exist yet at prepare time, and
 * the prebook response is the ONLY provider-side price source for a flight
 * offer — so a quote prebook is unavoidable. These values are NEVER ticketed:
 * `createBooking` refuses to book unless the real party produced the prebook.
 */
type NuiteeContact = {
  firstName: string;
  lastName: string;
  email: string;
  phoneCountryCode: string;
  phoneNumber: string;
};

const SANDBOX_CONTACT: NuiteeContact = {
  firstName: 'Test',
  lastName: 'Guest',
  email: 'test@tokigo.app',
  phoneCountryCode: '+20',
  phoneNumber: '1234567890',
};

type NuiteePassenger = {
  passengerType: number;
  firstName: string;
  lastName: string;
  birthday?: string;
  gender?: string;
  nationality?: string;
  documentType?: string;
  documentNumber?: string;
  documentIssueCountry?: string;
  documentExpiry?: string;
};

const SANDBOX_PASSENGER: NuiteePassenger = {
  // LiteAPI requires an INTEGER passenger type; 'ADT' is rejected.
  passengerType: 0,
  firstName: 'Test',
  lastName: 'Guest',
  birthday: '1990-01-01',
  gender: 'M',
  nationality: 'EG',
};

function _nonEmpty(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

/** Maps ONE internal traveller onto LiteAPI's exact passenger shape. */
function toNuiteePassenger(traveler: any): Record<string, unknown> | null {
  const firstName = traveler?.firstName ?? traveler?.given_name;
  const lastName = traveler?.lastName ?? traveler?.family_name;
  const birthday =
    traveler?.birthday ?? traveler?.dateOfBirth ?? traveler?.born_on;
  const gender = _nonEmpty(traveler?.gender)
    ? String(traveler.gender).trim().toUpperCase()
    : '';
  const nationality = _nonEmpty(traveler?.nationality)
    ? String(traveler.nationality).trim().toUpperCase()
    : '';
  const type =
    NUITEE_PASSENGER_TYPE[
      String(traveler?.passengerType ?? traveler?.type ?? '')
        .trim()
        .toLowerCase()
    ];

  // Every required field must have a real source. A missing one drops the
  // passenger so the caller fails closed instead of sending a payload the
  // provider would reject.
  if (
    !_nonEmpty(firstName) ||
    !_nonEmpty(lastName) ||
    !_nonEmpty(birthday) ||
    !NUITEE_GENDERS.has(gender) ||
    !_nonEmpty(nationality) ||
    type == null
  ) {
    return null;
  }

  const passenger: Record<string, unknown> = {
    passengerType: type,
    firstName: String(firstName).trim(),
    lastName: String(lastName).trim(),
    birthday: String(birthday).trim(),
    gender,
    nationality,
  };

  const title = _nonEmpty(traveler?.title)
    ? String(traveler.title).trim().toUpperCase()
    : '';
  if (NUITEE_TITLES.has(title)) passenger.title = title;

  const documentType = _nonEmpty(traveler?.documentType)
    ? NUITEE_DOCUMENT_TYPE[String(traveler.documentType).trim().toLowerCase()]
    : undefined;
  if (documentType) {
    if (_nonEmpty(traveler?.documentNumber)) {
      passenger.documentType = documentType;
      passenger.documentNumber = String(traveler.documentNumber).trim();
    }
    if (_nonEmpty(traveler?.documentIssueCountry)) {
      passenger.documentIssueCountry = String(
        traveler.documentIssueCountry,
      )
        .trim()
        .toUpperCase();
    }
    if (_nonEmpty(traveler?.documentExpiry)) {
      passenger.documentExpiry = String(traveler.documentExpiry).trim();
    }
  }

  return passenger;
}

/**
 * Booking adapter for Nuitee flight provider (Phase 4B — simplified sandbox).
 * Uses sandbox simulated payment (ACC_CREDIT_CARD) and simplified passenger data.
 */
@Injectable()
export class NuiteeFlightBookingProvider implements BookingProvider {
  constructor(private readonly flightService: NuiteeFlightService) {}

  readonly providerId = 'nuitee-flight';

  get providerName(): string {
    return 'Nuitee Flights';
  }

  readonly bookingCapability = {
    book: true,
    cancel: false,
    revalidate: true,
  } as const;

  /**
   * P3-D8 — exactly ONE prebook per logical booking.
   *
   *  - CONFIRM time (travellers present): prebook the REAL party ONCE. This is
   *    the hold `createBooking` tickets; it never prebooks again (P3-D6). A
   *    retry with the same persisted `travelerFingerprint` reuses that hold.
   *  - REVIEW time (a snapshot exists): reuse/validate the recorded prebook if
   *    there is one (legacy rows) and read the live offer price with
   *    `POST /flights/verify` — both read-only, so a review creates ZERO
   *    prebooks and an expired/invalid prebook is never silently reused.
   *  - PREPARE time (no snapshot yet): `POST /flights/verify` only. Travellers
   *    do not exist yet, so prebooking would reserve inventory for a party that
   *    cannot be named — and LiteAPI exposes NO prebook cancel/release endpoint
   *    (cancellations exist only for confirmed bookings), so that hold could
   *    never be recovered. Verify is the provider's documented pre-booking
   *    price check, so no hold is needed to obtain an authoritative price.
   */
  async revalidateBooking(
    offerId: string,
    context?: RevalidationContext,
  ): Promise<ProviderResult<BookingRevalidation>> {
    const travelers = context?.travelers;
    const snapshot = (context?.offerSnapshot ?? {}) as Record<string, any>;

    if (Array.isArray(travelers) && travelers.length > 0) {
      // CONFIRM time. The real party exists, so the prebook must carry it —
      // but a RETRY of the same attempt must reuse the hold it already made
      // instead of creating a second one. The persisted traveler fingerprint
      // is what distinguishes "same attempt" from "a new party".
      const fingerprint = this.travelerFingerprint(travelers);
      const existingPrebookId = snapshot.prebookId;
      if (
        existingPrebookId &&
        snapshot.travelerFingerprint === fingerprint
      ) {
        const existing = await this.flightService.getFlightPrebook(
          String(existingPrebookId),
        );
        if (!existing.success) {
          // The hold is gone — never silently re-prebook a party the provider
          // no longer holds. Fail closed; the client can re-enter the party.
          return this.failure(
            existing.error ??
              'The Nuitee flight prebook for this party is no longer valid',
          );
        }
        return {
          success: true,
          providerId: this.providerId,
          providerName: this.providerName,
          data: {
            price: Number(existing.price ?? 0),
            currency: existing.currency ?? 'USD',
            available: Boolean(existing.available),
            expiresAt: existing.expiresAt,
            handoff: {
              prebookId: String(existingPrebookId),
              transactionId: existing.transactionId ?? String(snapshot.transactionId ?? ''),
              offerId,
              travelerFingerprint: fingerprint,
            },
          },
          timestamp: new Date(),
        };
      }
      const prebook = await this.prebookOnce(offerId, travelers);
      if (prebook.success && prebook.data) {
        prebook.data.handoff = {
          ...prebook.data.handoff,
          travelerFingerprint: fingerprint,
        };
      }
      return prebook;
    }

    // REVIEW time — a snapshot exists. Never prebook again: if a prebook is
    // already recorded (legacy rows), validate it; either way read the live
    // offer price so a moved fare surfaces as a price change instead of being
    // silently accepted at the old amount.
    if (context?.offerSnapshot !== undefined) {
      const prebookId = snapshot.prebookId;
      let existing: Awaited<
        ReturnType<NuiteeFlightService['getFlightPrebook']>
      > | null = null;
      if (prebookId) {
        existing = await this.flightService.getFlightPrebook(String(prebookId));
        if (!existing.success) {
          return this.failure(
            existing.error ??
              'The existing Nuitee flight prebook is no longer valid',
          );
        }
      }
      const verified = await this.flightService.verifyFlightOffer(offerId);
      if (!verified.success) {
        return this.failure(
          verified.error ?? 'Nuitee flight price check failed',
        );
      }
      const price = Number(verified.price ?? existing?.price ?? 0);
      return {
        success: true,
        providerId: this.providerId,
        providerName: this.providerName,
        data: {
          price,
          currency: verified.currency ?? existing?.currency ?? 'USD',
          available: Boolean(verified.available) && price > 0,
          priceChanged: verified.priceChanged,
          oldPrice: verified.oldPrice,
          expiresAt: existing?.expiresAt ?? verified.expiresAt,
          handoff: {
            ...(prebookId
              ? {
                  prebookId: String(prebookId),
                  transactionId:
                    existing?.transactionId ??
                    (snapshot.transactionId != null
                      ? String(snapshot.transactionId)
                      : undefined),
                }
              : {}),
            offerId,
          },
        },
        timestamp: new Date(),
      };
    }

    // PREPARE time — no snapshot yet, no travellers. P3-D8: the documented
    // pre-booking check is `POST /flights/verify`, a READ-ONLY price
    // snapshot. Prebooking here would reserve inventory for a party that does
    // not exist yet, and LiteAPI exposes NO prebook cancel/release endpoint
    // (only booking cancellations), so that hold could never be recovered.
    return this.verifyOnly(offerId);
  }

  /**
   * The ONE prebook of a logical booking attempt. Prepare time uses the
   * sandbox party; confirm time uses the real collected party.
   */
  private async prebookOnce(
    offerId: string,
    travelers?: any[],
  ): Promise<ProviderResult<BookingRevalidation>> {
    const { contact, passengers } = this.buildPrebookPayload(travelers);
    const prebook = await this.flightService.prebookFlight({
      offerId,
      contact,
      passengers,
      usePaymentSdk: false,
    });
    if (!prebook.success) {
      return this.failure(prebook.error ?? 'Nuitee flight prebook failed');
    }
    const price = Number(prebook.price ?? 0);
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        // The prebook response is the ONLY provider-side price source for a
        // flight offer. The previous hardcoded `price: 0` made
        // `BookingsService.prepare` reject EVERY Nuitee flight offer with
        // `no_availability`.
        price,
        currency: prebook.currency ?? 'USD',
        available: price > 0,
        // The services-attachment window is the only expiry the prebook
        // exposes; an invented 30-minute quote would be fabricated data.
        expiresAt: prebook.servicesAttachable?.expiresAt,
        handoff: {
          prebookId: String(prebook.prebookId),
          transactionId: String(prebook.transactionId),
          offerId,
        },
      },
      timestamp: new Date(),
    };
  }

  /**
   * Read-only prepare-time price check (`POST /flights/verify`). Creates no
   * inventory hold — this is what makes the lifecycle exactly one prebook.
   */
  private async verifyOnly(
    offerId: string,
  ): Promise<ProviderResult<BookingRevalidation>> {
    const verified = await this.flightService.verifyFlightOffer(offerId);
    if (!verified.success) {
      return this.failure(
        verified.error ?? 'Nuitee flight price check failed',
      );
    }
    const price = Number(verified.price ?? 0);
    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        price,
        currency: verified.currency ?? 'USD',
        available: Boolean(verified.available) && price > 0,
        priceChanged: verified.priceChanged,
        oldPrice: verified.oldPrice,
        expiresAt: verified.expiresAt,
        handoff: { offerId },
      },
      timestamp: new Date(),
    };
  }

  private failure(error: string): ProviderResult<BookingRevalidation> {
    return {
      success: false,
      providerId: this.providerId,
      providerName: this.providerName,
      error,
      timestamp: new Date(),
    };
  }

  /**
   * Builds the LiteAPI prebook payload.
   *
   * With travellers (confirm time) the REAL collected party is used — the
   * prebook is passenger-specific, so a sandbox prebook cannot ticket a real
   * booking. Without travellers (prepare time) the sandbox contact and a
   * single adult are used: the traveller form has not been filled yet, and the
   * prebook response is the only provider-side price source.
   */
  private buildPrebookPayload(travelers?: any[]): {
    contact: NuiteeContact;
    passengers: NuiteePassenger[];
  } {
    const mapped = (travelers ?? []).map(toNuiteePassenger);
    const hasRealParty =
      Array.isArray(travelers) &&
      travelers.length > 0 &&
      mapped.every((passenger) => passenger !== null) &&
      this.leadContact(travelers[0]) !== null;

    if (hasRealParty) {
      return {
        contact: this.leadContact(travelers![0])!,
        passengers: mapped as NuiteePassenger[],
      };
    }
    return {
      contact: { ...SANDBOX_CONTACT },
      passengers: [{ ...SANDBOX_PASSENGER }],
    };
  }

  /**
   * A stable fingerprint of the REAL party, persisted in the booking snapshot.
   * It is what tells a retry of the SAME booking attempt (reuse the existing
   * prebook) apart from a NEW attempt with a different party (prebook again).
   * Derived only from provider-mapped fields — never from object identity.
   */
  private travelerFingerprint(travelers: any[]): string {
    const passengers = travelers.map(toNuiteePassenger);
    return JSON.stringify({
      passengers,
      contact: this.leadContact(travelers[0]),
    });
  }

  /**
   * The lead traveller as LiteAPI's contact. Null when any required piece is
   * missing — a guessed calling code or a fabricated address is forbidden.
   */
  private leadContact(lead: any): NuiteeContact | null {
    const contact: NuiteeContact = {
      firstName: String(lead?.firstName ?? '').trim(),
      lastName: String(lead?.lastName ?? '').trim(),
      email: String(lead?.email ?? '').trim(),
      phoneCountryCode: _nonEmpty(lead?.phoneCountryCode)
        ? String(lead.phoneCountryCode).replace(/^\+/, '').trim()
        : '',
      phoneNumber: String(lead?.phone ?? '').replace(/^\+/, '').trim(),
    };
    if (
      !contact.firstName ||
      !contact.lastName ||
      !contact.email ||
      !contact.phoneCountryCode ||
      !contact.phoneNumber
    ) {
      return null;
    }
    return contact;
  }

  async createBooking(input: CreateBookingInput): Promise<ProviderResult<CreatedBooking>> {
    const travelers = (input.travelers ?? []) as any[];
    const passengers = travelers.map(toNuiteePassenger);
    if (
      travelers.length === 0 ||
      passengers.some((passenger) => passenger === null) ||
      this.leadContact(travelers[0]) === null
    ) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error:
          'Nuitee flight booking requires a complete party: every passenger ' +
          'needs firstName, lastName, birthday, gender, nationality and ' +
          'passengerType, and the lead contact needs a first name, last name, ' +
          'email, phone country code and phone number. Collect them in the ' +
          'passenger form — no values are invented.',
        timestamp: new Date(),
      };
    }

    // P3-D6: the prebook was already created by the confirm-time
    // `revalidateBooking`, which received these travellers. Prebooking again
    // here would create a duplicate provider inventory hold for one logical
    // booking — the previous implementation did exactly that.
    const snapshot = (input.offerSnapshot ?? {}) as any;
    const prebookId = snapshot.prebookId;
    if (!prebookId) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: 'Missing Nuitee flight prebookId in snapshot',
        timestamp: new Date(),
      };
    }

    const bookResult = await this.flightService.bookFlight({
      prebookId: String(prebookId),
      payment: { method: 'ACC_CREDIT_CARD' },
    });

    if (!bookResult.success) {
      return {
        success: false,
        providerId: this.providerId,
        providerName: this.providerName,
        error: bookResult.error ?? 'Nuitee flight booking failed',
        timestamp: new Date(),
      };
    }

    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data: {
        reference:
          bookResult.bookingRef ??
          bookResult.bookingId ??
          String(prebookId),
        providerBookingId: bookResult.bookingId,
        status: bookResult.status ?? 'CREATED',
        amount: 0,
        currency: 'USD',
        raw: bookResult,
      },
      timestamp: new Date(),
    };
  }

  async cancelBooking(
    _input: CancelBookingInput,
  ): Promise<ProviderResult<{ cancelled: boolean }>> {
    return {
      success: false,
      providerId: this.providerId,
      providerName: this.providerName,
      error: 'Nuitee flight cancellation not supported',
      timestamp: new Date(),
    };
  }
}
