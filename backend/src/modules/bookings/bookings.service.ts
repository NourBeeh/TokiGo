import { Inject, Injectable, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, QueryFailedError, Repository } from 'typeorm';

import { Booking } from './booking.entity';
import { BookingProviderRegistry } from './booking-provider.registry';
import { BookingException } from './booking.exception';
import {
  BookingProvider,
  BookingRevalidation,
  CreatedBooking,
} from '../../common/providers/booking-provider.interface';
import {
  CreateBookingDto,
  PrepareBookingDto,
  PriceChangeDecisionDto,
  ReconcileBookingDto,
} from '../../common/dto/booking.dto';
import { isDefinitiveBookingFailure } from '../../common/providers/booking-failure';
import { confirmationStateOfStatus } from '../../common/providers/booking-confirmation';
import {
  diffOfferTerms,
  OfferTermsSnapshot,
  priceChangePercent,
  priceDifference,
  termsVersionOf,
} from '../../common/pricing/offer-terms';
import { priceVersionOf } from '../../common/pricing/price-version';
import {
  isProductionRuntime,
  isTestRuntime,
} from '../../common/runtime/runtime';
import { AuditLog } from '../../database/entities/audit_log.entity';
import { PaymentAttempt } from '../../database/entities/payment-attempt.entity';
import {
  ProviderOperation,
  ProviderOperationStatus,
} from '../../database/entities/provider-operation.entity';

/** Wire shape of the price-change confirmation, bound to the exact offer. */
export interface PriceChangeSummary {
  providerId: string;
  offerId: string;
  offerType: string;
  previousPrice: number | null;
  currentPrice: number;
  currency: string;
  priceDifference: number;
  priceChangePercent: number | null;
  priceChanged: boolean;
  termsChanged: boolean;
  changedTerms: string[];
  previousTerms: OfferTermsSnapshot | null;
  currentTerms: OfferTermsSnapshot | null;
  termsVersion: string;
  requiresAcceptance: boolean;
  accepted: boolean;
  decision: 'accepted' | 'declined' | null;
  decidedAt: string | null;
  checkedAt: string;
  expiresAt: string | null;
}

/** Wire shape returned to the client — never leaks the provider snapshot. */
export interface BookingResponse {
  id: string;
  userId: string;
  searchId: string | null;
  offerId: string;
  providerId: string;
  providerName: string;
  type: string;
  status: string;
  currency: string;
  authoritativePrice: number;
  previousPrice: number | null;
  priceChanged: boolean;
  available: boolean;
  bookingReference: string | null;
  travelers: any[];
  expiresAt: Date | null;
  priceChange: PriceChangeSummary | null;
  createdAt: Date;
  updatedAt: Date;
}

const PRICE_TOLERANCE = 0.01;

/** Result of comparing one live provider revalidation to the accepted state. */
interface LiveRevalidationOutcome {
  requiresAcceptance: boolean;
  /** True only when this call detected a NEW price/terms state. */
  firstDetection: boolean;
  priceChanged: boolean;
  termsChanged: boolean;
  changedTerms: string[];
  previousPrice: number | null;
  previousTerms: OfferTermsSnapshot | null;
  currentPrice: number;
  currency: string;
  terms: OfferTermsSnapshot | null;
  termsVersion: string;
}

/** Outcome of claiming the durable `create_booking` provider operation. */
interface ProviderCreateAttempt {
  /** Deterministic operation key: `<bookingId>:<client idempotency key>`. */
  operationKey: string;
  operationId?: string;
  /** Definitive success already recorded for this exact logical attempt. */
  replay?: CreatedBooking;
  /**
   * An earlier attempt for this logical booking has no conclusive outcome
   * (pending/unknown) or claims success without a usable reference. The
   * provider MUST NOT be called again.
   */
  blockedBy?: ProviderOperation;
}

interface UnknownOutcomeEvidence {
  operationId?: string;
  operationKey?: string;
  error?: string;
  priorOperationStatus?: ProviderOperationStatus;
  /**
   * Provider evidence recorded even when it is not enough to confirm. It is
   * what an operator uses to reconcile the booking with the provider.
   */
  providerReference?: string | null;
  providerBookingId?: string | null;
  providerStatus?: string | null;
}

/**
 * Result of a provider-operation ledger write.
 *
 * `applied: false` means the compare-and-set matched zero rows because another
 * actor already resolved the operation (normally the admin reconciliation).
 * `currentStatus` is the durable state read back from the ledger; callers must
 * preserve it and never perform an unconditional fallback write.
 */
interface ProviderOperationWriteOutcome {
  applied: boolean;
  currentStatus?: ProviderOperationStatus;
}

/**
 * Booking foundation service (Phase 4A).
 *
 * Rules enforced here:
 *  - provider identity is mandatory and capabilities are checked first;
 *  - the authoritative price ALWAYS comes from a provider revalidation, never
 *    from the client or a Hive snapshot;
 *  - a provider-backed offer is revalidated again immediately before commit;
 *  - create is idempotent on (userId, idempotencyKey) — retries cannot
 *    double-book;
 *  - failures are normalised to a stable `code` (BookingException).
 *
 * No payment, no provider credentials, no secret are handled here.
 */
@Injectable()
export class BookingsService {
  constructor(
    @InjectRepository(Booking)
    private readonly bookings: Repository<Booking>,
    private readonly registry: BookingProviderRegistry,
    @Optional()
    @InjectRepository(AuditLog)
    private readonly audit?: Repository<AuditLog>,
    /**
     * Durable provider-operation ledger. Present in production (wired in
     * BookingsModule); optional so pure unit tests can omit it. When absent,
     * the booking row itself still carries the reconciliation state and the
     * provider is never retried automatically.
     */
    @Optional()
    @InjectRepository(ProviderOperation)
    private readonly operations?: Repository<ProviderOperation>,
    /**
     * Verified customer-payment evidence. Present in production (wired in
     * BookingsModule). Optional only so pre-payment unit tests can construct
     * the service; a production runtime without it fails closed.
     */
    @Optional()
    @InjectRepository(PaymentAttempt)
    private readonly paymentAttempts?: Repository<PaymentAttempt>,
  ) {}

  async prepare(userId: string, dto: PrepareBookingDto): Promise<BookingResponse> {
    const provider = this.requireCapability(dto.providerId, 'book');

    const revalidation = await provider.revalidateBooking(dto.offerId);
    if (!revalidation.success || !revalidation.data) {
      throw new BookingException(
        'provider_unavailable',
        revalidation.error ?? 'Provider revalidation failed',
      );
    }
    const { price, currency, available, expiresAt, handoff } = revalidation.data;
    if (!available || price <= 0) {
      throw new BookingException(
        'no_availability',
        'This offer is no longer available',
      );
    }

    const type = dto.offerType ?? this.inferType(provider.providerId);
    const terms = revalidation.data.terms ?? null;
    const termsVersion =
      revalidation.data.termsVersion ?? termsVersionOf(terms ?? {});
    const checkedAt = new Date().toISOString();
    // Selecting an offer at its displayed price is the customer's baseline
    // acceptance. The version binds that exact commercial state to any later
    // payment.
    const priceVersion = priceVersionOf({
      providerId: provider.providerId,
      offerId: dto.offerId,
      offerType: type,
      amount: price,
      currency,
      termsVersion,
    });
    const revalidationMeta = {
      providerId: provider.providerId,
      offerId: dto.offerId,
      offerType: type,
      // The accepted state is what every later revalidation is compared to.
      // It is kept even while a pending change is awaiting a decision, so a
      // second revalidation still reports the ORIGINAL accepted amount.
      acceptedPrice: price,
      acceptedTerms: terms,
      acceptedTermsVersion: termsVersion,
      previousPrice: null,
      currentPrice: price,
      currency,
      terms,
      previousTerms: null,
      termsVersion,
      changedTerms: [],
      pending: false,
      checkedAt,
      expiresAt: expiresAt ?? null,
    };
    // Selecting an offer at its displayed price is the customer's baseline
    // acceptance. Every later change replaces it with a new, explicitly
    // confirmed acceptance (or removes it).
    const acceptance = {
      decision: 'accepted',
      providerId: provider.providerId,
      offerId: dto.offerId,
      offerType: type,
      price,
      currency,
      termsVersion,
      terms,
      acceptedAt: checkedAt,
      source: 'selection',
    };

    const booking = this.bookings.create({
      userId,
      searchId: dto.searchId ?? null,
      offerId: dto.offerId,
      providerId: provider.providerId,
      providerName: dto.providerName ?? provider.providerName,
      type,
      status: 'prepared',
      currency,
      authoritativePrice: price,
      priceVersion,
      offerSnapshot: { offerId: dto.offerId, ...(handoff ?? {}) },
      providerMetadata: {
        priceRevalidation: revalidationMeta,
        priceAcceptance: acceptance,
      },
      travelers: [],
      expiresAt: expiresAt ? new Date(expiresAt) : null,
    });
    return this.toResponse(await this.bookings.save(booking));
  }

  async revalidate(userId: string, bookingId: string): Promise<BookingResponse> {
    const booking = await this.findOwn(userId, bookingId);
    if (!['prepared', 'revalidated'].includes(booking.status)) {
      throw new BookingException(
        'validation_failed',
        `Booking cannot be revalidated in status '${booking.status}'`,
      );
    }

    const provider = this.requireCapability(booking.providerId, 'revalidate');
    // P3-D7: hand the persisted snapshot to the provider so a Nuitee flight
    // review can REUSE the existing prebook instead of creating another hold.
    const revalidation = await provider.revalidateBooking(booking.offerId, {
      offerSnapshot: booking.offerSnapshot,
    });
    if (!revalidation.success || !revalidation.data) {
      throw new BookingException(
        'provider_unavailable',
        revalidation.error ?? 'Provider revalidation failed',
      );
    }
    const live = revalidation.data;
    if (!live.available || !(live.price > 0) || !live.currency) {
      throw new BookingException(
        'no_availability',
        'This offer is no longer available',
      );
    }

    const outcome = this.applyLiveRevalidation(booking, live);
    booking.status = 'revalidated';
    booking.offerSnapshot = {
      ...booking.offerSnapshot,
      ...(live.handoff ?? {}),
    };
    if (live.expiresAt) booking.expiresAt = new Date(live.expiresAt);

    await this.bookings.save(booking);
    if (outcome.firstDetection) {
      await this.auditBooking(
        'booking.price_change.detected',
        userId,
        booking,
        this.priceChangeAuditMetadata(booking, outcome),
      );
    }
    return this.toResponse(booking);
  }

  async create(userId: string, dto: CreateBookingDto): Promise<BookingResponse> {
    const booking = await this.findOwn(userId, dto.bookingId);

    // Idempotent replay: the same key already confirmed this booking.
    if (booking.idempotencyKey === dto.idempotencyKey && booking.status === 'confirmed') {
      return this.toResponse(booking);
    }
    // An unknown provider outcome outranks every retry: the same attempt may
    // already exist at the provider. No key (old or new) may reopen it until
    // an authorized reconciliation resolves it.
    if (booking.status === 'reconciliation_pending') {
      throw await this.unknownOutcomeException(booking);
    }
    if (booking.status === 'confirming') {
      // Recovery: a previous process may have completed the provider call but
      // lost the booking-row save. A confirmed/unknown operation row is
      // durable evidence; use it instead of a blind duplicate rejection or a
      // second provider submission. A still-pending operation means the first
      // request is genuinely in flight.
      const operation = await this.findCreateOperation(booking);
      if (operation?.status === 'confirmed') {
        const replay = this.createdBookingFromOperation(operation);
        if (replay) {
          return this.finalizeConfirmed(booking, replay, operation.id);
        }
      }
      if (operation?.status === 'unknown') {
        await this.markReconciliationPending(booking, {
          operationId: operation.id,
          operationKey: operation.idempotencyKey,
          priorOperationStatus: operation.status,
          error:
            'The provider operation was recorded as unknown before the booking row was updated',
        });
        throw await this.unknownOutcomeException(booking, operation);
      }
      throw new BookingException(
        'duplicate_request',
        'A booking confirmation is already in progress',
      );
    }
    if (['cancelled', 'expired'].includes(booking.status)) {
      throw new BookingException(
        'booking_expired',
        `Booking can no longer be confirmed (status '${booking.status}')`,
      );
    }

    // Payment evidence is resolved and verified BEFORE the provider is called.
    // The attempt must be server-verified and bound to this booking, user,
    // amount, currency and accepted price version.
    const evidence = await this.resolvePaymentEvidence(userId, booking, dto);
    const consumedAt = evidence ? new Date() : undefined;

    // Reserve the idempotency key before any provider call. The reservation is
    // a CONDITIONAL update: it only matches while the row is still in a
    // confirmable state. Two concurrent calls that both read 'prepared' race
    // here — the loser waits on the row lock, then matches zero rows and fails
    // closed. A plain save would let both through and submit two bookings; the
    // unique index cannot help because both writers update the SAME row.
    //
    // The payment link is reserved in the SAME conditional update, so a
    // booking can never reach the provider without its exact attempt. The
    // partial unique index on `paymentAttemptId` is the cross-booking backstop.
    const reserve = await this.bookings
      .update(
        {
          id: booking.id,
          status: In(['prepared', 'revalidated', 'failed']),
        },
        {
          status: 'confirming',
          idempotencyKey: dto.idempotencyKey,
          travelers: dto.travelers ?? [],
          ...(evidence
            ? {
                paymentAttemptId: evidence.id,
                paymentStatus: 'verified',
                consumedAt,
              }
            : {}),
        },
      )
      .catch((error) => {
        if (this.isPaymentAttemptUniqueViolation(error)) {
          throw new BookingException(
            'payment_not_verified',
            'This payment has already been used for another booking.',
          );
        }
        if (this.isUniqueViolation(error)) {
          throw new BookingException(
            'duplicate_request',
            'Duplicate booking request',
          );
        }
        throw error;
      });
    if (!reserve.affected) {
      throw new BookingException(
        'duplicate_request',
        'A booking confirmation is already in progress',
      );
    }
    booking.status = 'confirming';
    booking.idempotencyKey = dto.idempotencyKey;
    booking.travelers = dto.travelers ?? [];
    if (evidence) {
      booking.paymentAttemptId = evidence.id;
      booking.paymentStatus = 'verified';
      booking.consumedAt = consumedAt ?? null;
    }
    const provider = this.registry.resolve(booking.providerId);
    if (!provider || !provider.bookingCapability.book) {
      await this.fail(booking);
      throw new BookingException(
        'capability_unsupported',
        `Provider '${booking.providerId}' cannot create bookings`,
      );
    }

    // Revalidate immediately before commit — never book a stale price.
    // P3-D6: the persisted travellers are passed too, so a provider whose
    // prebook carries passenger data (Nuitee) prebooks the REAL party here
    // instead of a second, sandbox prebook inside `createBooking`.
    const revalidation = await provider.revalidateBooking(booking.offerId, {
      travelers: booking.travelers,
      offerSnapshot: booking.offerSnapshot,
    });
    if (!revalidation.success || !revalidation.data) {
      await this.fail(booking);
      throw new BookingException(
        'provider_unavailable',
        revalidation.error ?? 'Provider revalidation failed',
      );
    }
    const live = revalidation.data;
    // P3-D5: refresh the provider handoff on EVERY revalidation, not only
    // when the price moved. Duffel's offer passenger ids live in that handoff
    // and the confirm step reads them from the snapshot — a stale snapshot
    // would send the wrong (or no) passenger ids to the provider.
    booking.offerSnapshot = {
      ...booking.offerSnapshot,
      ...(live.handoff ?? {}),
    };
    if (!live.available || !(live.price > 0) || !live.currency) {
      await this.fail(booking);
      throw new BookingException(
        'no_availability',
        'This offer is no longer available',
      );
    }

    // Compare the LIVE provider state with the exact state the customer last
    // accepted. A price move OR a fare/room/cancellation/baggage change both
    // stop the booking until a new explicit acceptance is recorded.
    const outcome = this.applyLiveRevalidation(booking, live);
    if (outcome.requiresAcceptance) {
      booking.status = 'revalidated';
      booking.idempotencyKey = null;
      // The provider was never asked to create this booking, so the payment
      // reserved moments ago is not consumed. Detach it (without touching the
      // verified attempt itself) or a later, newly-priced payment could never
      // be attached.
      booking.paymentAttemptId = null;
      booking.paymentStatus = 'unverified';
      booking.consumedAt = null;
      if (live.expiresAt) booking.expiresAt = new Date(live.expiresAt);
      await this.bookings.save(booking);
      if (outcome.firstDetection) {
        await this.auditBooking(
          'booking.price_change.detected',
          userId,
          booking,
          this.priceChangeAuditMetadata(booking, outcome),
        );
      }
      throw new BookingException(
        'price_changed',
        'The offer changed; please review and accept the updated price and conditions',
        {
          bookingId: booking.id,
          providerId: booking.providerId,
          offerId: booking.offerId,
          offerType: booking.type,
          previousPrice: outcome.previousPrice,
          currentPrice: outcome.currentPrice,
          currency: outcome.currency,
          priceChanged: outcome.priceChanged,
          termsChanged: outcome.termsChanged,
          changedTerms: outcome.changedTerms,
          termsVersion: outcome.termsVersion,
          requiresAcceptance: true,
        },
      );
    }

    // Claim the durable provider operation BEFORE calling the provider. A
    // conditional booking update already guarantees only one request reaches
    // this point; the operation row adds a second, provider-scoped identity so
    // a crash or an operator retry can never be mistaken for a fresh booking.
    let attempt: ProviderCreateAttempt;
    try {
      attempt = await this.beginProviderCreate(booking, dto.idempotencyKey);
    } catch (error) {
      // Nothing was sent to the provider, so failing is definitive and safe.
      await this.fail(booking);
      throw new BookingException(
        'unknown_error',
        'Could not record the provider booking operation',
        { bookingId: booking.id, providerId: booking.providerId },
      );
    }

    if (attempt.replay) {
      // The provider operation ledger already proves this exact attempt
      // succeeded (e.g. the booking row save was lost). Confirm from recorded
      // evidence — never submit a second provider booking.
      return this.finalizeConfirmed(booking, attempt.replay, attempt.operationId);
    }

    if (attempt.blockedBy) {
      // A prior attempt for this logical booking is still pending/unknown, or
      // claims success without a usable reference. Fail closed and expose the
      // explicit reconciliation path.
      await this.markReconciliationPending(booking, {
        operationId: attempt.blockedBy.id,
        operationKey: attempt.operationKey,
        priorOperationStatus: attempt.blockedBy.status,
        error:
          'A previous provider create attempt for this booking has no conclusive outcome',
      });
      await this.auditBooking(
        'booking.provider_create.reconciliation_required',
        userId,
        booking,
        this.reconciliationAuditMetadata(booking, attempt.operationId),
      );
      throw await this.unknownOutcomeException(booking, attempt.blockedBy);
    }

    let created;
    try {
      created = await provider.createBooking({
        offerId: booking.offerId,
        offerSnapshot: booking.offerSnapshot,
        travelers: booking.travelers,
        // Bind the provider call to this exact TokiGo booking and to the
        // accepted commercial version. Adapters use these only as provider
        // metadata/idempotency labels — never as payment credentials.
        bookingId: booking.id,
        amount: live.price,
        currency: live.currency,
        amountText: live.amountText,
        priceVersion: booking.priceVersion ?? undefined,
        paymentAttemptId: booking.paymentAttemptId ?? undefined,
      });
    } catch (error) {
      // A thrown transport error is ambiguous by definition: the request may
      // still have reached the provider. Never classify it as a rejection.
      created = {
        success: false as const,
        providerId: provider.providerId,
        providerName: provider.providerName,
        error:
          (error as Error)?.message ?? 'Provider booking call threw an error',
        failureKind: 'ambiguous' as const,
        timestamp: new Date(),
      };
    }

    const createdData =
      created.success && created.data ? created.data : undefined;
    const reference = createdData
      ? String(createdData.reference ?? '').trim()
      : '';
    if (createdData && reference.length > 0) {
      // Provider TRUTH decides whether this is a booking. A created record
      // that the provider has not confirmed (awaiting payment, PENDING,
      // CANCELLED, unknown status) must never become a confirmed booking.
      // Adapters that publish only `status` are normalized here as well.
      const confirmationState =
        createdData.confirmationState ??
        confirmationStateOfStatus(createdData.status);
      const amountMismatch = this.providerAmountMismatch(booking, createdData);

      if (confirmationState === 'confirmed' && !amountMismatch) {
        await this.completeProviderOperation(
          attempt.operationId,
          'confirmed',
          {
            reference,
            providerBookingId: createdData.providerBookingId ?? null,
            status: createdData.status ?? null,
            amount: createdData.amount ?? null,
            currency: createdData.currency ?? null,
            confirmationState,
            confirmedAt: new Date().toISOString(),
          },
          createdData.providerBookingId ?? reference,
          ['pending'],
        );
        return this.finalizeConfirmed(
          booking,
          createdData,
          attempt.operationId,
        );
      }

      if (confirmationState === 'failed') {
        // The provider established that no live booking exists (cancelled /
        // rejected). This is the only success-shaped outcome that may reopen
        // the booking; record the provider evidence before releasing it.
        await this.completeProviderOperation(
          attempt.operationId,
          'failed',
          {
            reference,
            providerBookingId: createdData.providerBookingId ?? null,
            status: createdData.status ?? null,
            confirmationState,
            failedAt: new Date().toISOString(),
          },
          createdData.providerBookingId ?? reference,
          ['pending'],
        );
        await this.auditBooking(
          'booking.provider_create.failed',
          userId,
          booking,
          {
            bookingId: booking.id,
            providerId: booking.providerId,
            offerId: booking.offerId,
            providerReference: reference,
            providerBookingId: createdData.providerBookingId ?? null,
            providerStatus: createdData.status ?? null,
            reason: 'provider_status_failed',
            timestamp: new Date().toISOString(),
          },
        );
        await this.fail(booking);
        throw new BookingException(
          'provider_error',
          `Provider reported the booking as '${createdData.status ?? 'failed'}'`,
        );
      }

      // Confirmed by no one: awaiting payment, pending confirmation, unknown
      // status, or a confirmed status whose amount/currency does not match
      // what the customer accepted. Persist the provider evidence and keep
      // every retry blocked until an operator reconciles it.
      const reason =
        amountMismatch ??
        `Provider has not confirmed the booking (status '${createdData.status ?? 'unknown'}')`;
      await this.markReconciliationPending(booking, {
        operationId: attempt.operationId,
        operationKey: attempt.operationKey,
        providerReference: reference,
        providerBookingId: createdData.providerBookingId ?? null,
        providerStatus: createdData.status ?? null,
        error: reason,
      });
      await this.completeProviderOperation(
        attempt.operationId,
        'unknown',
        {
          reference,
          providerBookingId: createdData.providerBookingId ?? null,
          status: createdData.status ?? null,
          confirmationState,
          amount: createdData.amount ?? null,
          currency: createdData.currency ?? null,
          error: this.safeError(reason),
          outcome: 'ambiguous',
          recordedAt: new Date().toISOString(),
        },
        undefined,
        ['pending'],
      );
      await this.auditBooking(
        'booking.provider_create.reconciliation_required',
        userId,
        booking,
        this.reconciliationAuditMetadata(booking, attempt.operationId, reason),
      );
      throw await this.unknownOutcomeException(booking);
    }

    // Only an explicitly classified DEFINITIVE rejection may reopen the
    // booking. Missing/malformed classification is treated as ambiguous.
    if (created.success === false && isDefinitiveBookingFailure(created)) {
      await this.completeProviderOperation(
        attempt.operationId,
        'failed',
        {
          error: this.safeError(created.error),
          failedAt: new Date().toISOString(),
        },
        undefined,
        ['pending'],
      );
      await this.fail(booking);
      throw new BookingException(
        'provider_error',
        created.error ?? 'Provider booking failed',
      );
    }

    // Ambiguous outcome: the provider may already have created the booking.
    // Persist the unknown state durably, keep the idempotency key, and expose
    // only a non-retryable machine-readable result.
    const ambiguousError =
      created.error ??
      (created.success
        ? 'Provider reported success without a usable booking reference'
        : 'Provider booking outcome is unknown');
    await this.markReconciliationPending(booking, {
      operationId: attempt.operationId,
      operationKey: attempt.operationKey,
      error: ambiguousError,
      providerReference: createdData?.reference ?? null,
      providerBookingId: createdData?.providerBookingId ?? null,
      providerStatus: createdData?.status ?? null,
    });
    // Conditional on `pending`: an operator may already have reconciled the
    // booking after its reconciliation_pending save (the window between that
    // save and this ledger write). A late ambiguous write must never downgrade
    // a recorded confirmation/not_found result.
    await this.completeProviderOperation(
      attempt.operationId,
      'unknown',
      {
        reference: createdData?.reference ?? null,
        providerBookingId: createdData?.providerBookingId ?? null,
        status: createdData?.status ?? null,
        amount: createdData?.amount ?? null,
        currency: createdData?.currency ?? null,
        error: this.safeError(ambiguousError),
        outcome: 'ambiguous',
        recordedAt: new Date().toISOString(),
      },
      undefined,
      ['pending'],
    );
    await this.auditBooking(
      'booking.provider_create.reconciliation_required',
      userId,
      booking,
      this.reconciliationAuditMetadata(booking, attempt.operationId, ambiguousError),
    );
    throw await this.unknownOutcomeException(booking);
  }

  /**
   * Explicit, admin-authorized resolution of a `reconciliation_pending`
   * booking.
   *
   * The backend does NOT invent a provider lookup call. An operator records
   * evidence gathered from the provider:
   *  - `confirmed` requires a provider reference/id and confirms the booking
   *    without a second create call;
   *  - `not_found` releases the retained idempotency key and marks the attempt
   *    failed, which is the ONLY path that allows a new explicit create.
   */
  async reconcile(
    adminUserId: string,
    bookingId: string,
    dto: ReconcileBookingDto,
  ): Promise<BookingResponse> {
    const booking = await this.bookings.findOne({ where: { id: bookingId } });
    if (!booking) {
      throw new BookingException('booking_not_found', 'Booking not found');
    }
    const previousAttempt = (booking.providerMetadata?.providerBookingAttempt ??
      {}) as Record<string, any>;
    const reconciledAt = new Date().toISOString();

    if (dto.outcome === 'confirmed') {
      if (booking.status === 'confirmed') {
        return this.toResponse(booking);
      }
      if (booking.status !== 'reconciliation_pending') {
        throw new BookingException(
          'validation_failed',
          `Booking cannot be reconciled as confirmed in status '${booking.status}'`,
        );
      }
      const reference = dto.providerReference ?? dto.providerBookingId;
      if (!reference) {
        throw new BookingException(
          'validation_failed',
          'A provider reference or provider booking id is required to confirm a reconciled booking',
        );
      }

      // Reconciliation may not bypass payment containment: confirming a
      // provider booking still requires the exact verified customer payment.
      await this.requirePaymentEvidenceForBooking(booking);

      const operation = await this.findCreateOperation(booking);
      const providerBookingId =
        dto.providerBookingId ??
        (typeof previousAttempt.providerBookingId === 'string'
          ? previousAttempt.providerBookingId
          : undefined);

      booking.status = 'confirmed';
      booking.bookingReference = reference;
      booking.confirmingSince = null;
      booking.providerMetadata = {
        ...(booking.providerMetadata ?? {}),
        ...(providerBookingId ? { providerBookingId } : {}),
        providerBookingAttempt: {
          ...previousAttempt,
          providerId: booking.providerId,
          offerId: booking.offerId,
          idempotencyKey: booking.idempotencyKey,
          outcome: 'confirmed',
          reconciledAt,
          reconciliation: {
            outcome: 'confirmed',
            reference,
            providerBookingId: providerBookingId ?? null,
            note: dto.note ?? null,
            reconciledBy: adminUserId,
            source: 'admin_endpoint',
          },
          requiresReconciliation: false,
          retryable: false,
        },
      };
      const saved = await this.bookings.save(booking);

      await this.completeProviderOperation(
        operation?.id,
        'confirmed',
        {
          reference,
          providerBookingId: providerBookingId ?? null,
          reconciledAt,
          reconciledBy: adminUserId,
          note: dto.note ?? null,
          evidenceSource: 'admin_reconciliation',
        },
        providerBookingId ?? reference,
      );
      await this.auditBooking('booking.reconciliation.confirmed', adminUserId, booking, {
        bookingId: booking.id,
        providerId: booking.providerId,
        reference,
        providerBookingId: providerBookingId ?? null,
        reconciledAt,
        note: dto.note ?? null,
      });
      return this.toResponse(saved);
    }

    // not_found — explicit evidence that no provider booking exists.
    const alreadyNotFound =
      booking.status === 'failed' &&
      previousAttempt.reconciliationOutcome === 'not_found';
    if (alreadyNotFound) {
      return this.toResponse(booking);
    }
    if (booking.status !== 'reconciliation_pending') {
      throw new BookingException(
        'validation_failed',
        `Booking cannot be reconciled as not found in status '${booking.status}'`,
      );
    }

    const operation = await this.findCreateOperation(booking);
    if (operation?.status === 'confirmed') {
      // Never overwrite recorded proof of a provider booking with a "not
      // found" investigation result.
      throw new BookingException(
        'validation_failed',
        'The provider operation already records a confirmed booking',
      );
    }
    if (operation?.status === 'pending') {
      // A pending operation may still be in flight; declaring "not found"
      // now could race a provider booking into existence after the operator
      // released the key. Fail closed until the attempt settles.
      throw new BookingException(
        'validation_failed',
        'The provider operation is still pending; wait for it to settle before declaring it not found',
      );
    }

    // Mark the operation not_found FIRST: if the booking save then fails, the
    // booking is still reconciliation_pending and a retry remains blocked.
    const ledger = await this.completeProviderOperation(
      operation?.id,
      'not_found',
      {
        outcome: 'not_found',
        reconciledAt,
        reconciledBy: adminUserId,
        note: dto.note ?? null,
        evidenceSource: 'admin_reconciliation',
      },
      undefined,
      ['unknown', 'not_found'],
    );

    // Releasing the key is only safe when the not-found evidence is durably
    // recorded. A failed or lost compare-and-set means another actor changed
    // the operation (or the ledger is unavailable), so keep the booking
    // blocked and the key retained.
    if (operation && !ledger) {
      throw new BookingException(
        'unknown_error',
        'Could not record the provider not-found evidence; the booking stays blocked for reconciliation',
        {
          bookingId: booking.id,
          operationId: operation.id,
          operationStatus: operation.status,
          retryable: true,
        },
      );
    }
    if (operation && ledger && !ledger.applied && ledger.currentStatus !== 'not_found') {
      throw new BookingException(
        'validation_failed',
        `The provider operation changed to '${ledger.currentStatus ?? 'missing'}' while reconciling; the booking stays blocked`,
        {
          bookingId: booking.id,
          operationId: operation.id,
          operationStatus: ledger.currentStatus ?? null,
        },
      );
    }

    booking.status = 'failed';
    booking.idempotencyKey = null;
    booking.confirmingSince = null;
    booking.providerMetadata = {
      ...(booking.providerMetadata ?? {}),
      providerBookingAttempt: {
        ...previousAttempt,
        providerId: booking.providerId,
        offerId: booking.offerId,
        outcome: 'not_found',
        reconciliationOutcome: 'not_found',
        reconciledAt,
        reconciliation: {
          outcome: 'not_found',
          note: dto.note ?? null,
          reconciledBy: adminUserId,
          source: 'admin_endpoint',
        },
        requiresReconciliation: false,
        // A new explicit create is now safe because the provider is proven to
        // have no booking for this attempt.
        retryable: true,
      },
    };
    const saved = await this.bookings.save(booking);
    await this.auditBooking('booking.reconciliation.not_found', adminUserId, booking, {
      bookingId: booking.id,
      providerId: booking.providerId,
      reconciledAt,
      note: dto.note ?? null,
    });
    return this.toResponse(saved);
  }

  /**
   * Records the customer's explicit decision on a pending price/terms change.
   *
   * Acceptance is written SERVER-SIDE from the stored revalidated snapshot —
   * never from the request body — and is bound to provider + offer + amount +
   * currency + terms version. The optional `expected*` fields reject a stale
   * decision when the offer changed again between display and tap.
   */
  async decidePriceChange(
    userId: string,
    bookingId: string,
    dto: PriceChangeDecisionDto,
  ): Promise<BookingResponse> {
    const booking = await this.findOwn(userId, bookingId);
    if (!['prepared', 'revalidated'].includes(booking.status)) {
      throw new BookingException(
        'validation_failed',
        `Booking cannot accept a price change in status '${booking.status}'`,
      );
    }

    const metadata = { ...(booking.providerMetadata ?? {}) };
    const pending = metadata.priceRevalidation as
      | Record<string, any>
      | undefined;
    if (!pending || typeof pending.currentPrice !== 'number') {
      throw new BookingException(
        'validation_failed',
        'There is no revalidated offer to decide on',
      );
    }

    const currentPrice = pending.currentPrice;
    const currency =
      typeof pending.currency === 'string'
        ? pending.currency
        : booking.currency;
    const termsVersion =
      typeof pending.termsVersion === 'string'
        ? pending.termsVersion
        : termsVersionOf(pending.terms ?? {});
    const stale =
      (dto.expectedPrice !== undefined &&
        Math.abs(dto.expectedPrice - currentPrice) > PRICE_TOLERANCE) ||
      (dto.expectedCurrency !== undefined &&
        dto.expectedCurrency !== currency) ||
      (dto.expectedTermsVersion !== undefined &&
        dto.expectedTermsVersion !== termsVersion);
    if (stale) {
      throw new BookingException(
        'price_changed',
        'The offer changed again; please review the latest price and conditions',
        this.priceChangeDetails(booking),
      );
    }

    const decidedAt = new Date().toISOString();
    const previousPrice =
      typeof pending.previousPrice === 'number' ? pending.previousPrice : null;
    const changedTerms = Array.isArray(pending.changedTerms)
      ? pending.changedTerms.filter(
          (entry: unknown): entry is string => typeof entry === 'string',
        )
      : [];
    const decision = dto.decision === 'accept' ? 'accepted' : 'declined';
    const decisionRecord = {
      decision,
      providerId: booking.providerId,
      offerId: booking.offerId,
      offerType: booking.type,
      previousPrice,
      currentPrice,
      currency,
      termsVersion,
      changedTerms,
      decidedAt,
    };

    if (decision === 'accepted') {
      metadata.priceAcceptance = {
        decision: 'accepted',
        providerId: booking.providerId,
        offerId: booking.offerId,
        offerType: booking.type,
        price: currentPrice,
        currency,
        termsVersion,
        terms: pending.terms ?? null,
        acceptedAt: decidedAt,
        source: 'price-change',
      };
      metadata.priceRevalidation = {
        ...pending,
        acceptedPrice: currentPrice,
        acceptedTerms: pending.terms ?? null,
        acceptedTermsVersion: termsVersion,
        previousPrice: null,
        previousTerms: null,
        changedTerms: [],
        pending: false,
      };
      // Acceptance binds the exact amount/currency/terms the customer saw.
      booking.priceVersion = priceVersionOf({
        providerId: booking.providerId,
        offerId: booking.offerId,
        offerType: booking.type,
        amount: currentPrice,
        currency,
        termsVersion,
      });
    } else {
      // Declining never books the changed offer. The acceptance stays absent
      // so any confirm attempt must revalidate and ask again.
      metadata.priceAcceptance = null;
      booking.priceVersion = null;
    }
    metadata.priceChangeDecision = decisionRecord;
    booking.providerMetadata = metadata;

    await this.bookings.save(booking);
    await this.auditBooking(
      decision === 'accepted'
        ? 'booking.price_change.accepted'
        : 'booking.price_change.declined',
      userId,
      booking,
      decisionRecord,
    );
    return this.toResponse(booking);
  }

  async get(userId: string, bookingId: string): Promise<BookingResponse> {
    return this.toResponse(await this.findOwn(userId, bookingId));
  }

  async getStatus(userId: string, bookingId: string): Promise<BookingResponse> {
    return this.toResponse(await this.findOwn(userId, bookingId));
  }

  async cancel(userId: string, bookingId: string): Promise<BookingResponse> {
    const booking = await this.findOwn(userId, bookingId);
    const provider = this.registry.resolve(booking.providerId);
    if (
      !provider ||
      !provider.bookingCapability.cancel ||
      typeof provider.cancelBooking !== 'function'
    ) {
      throw new BookingException(
        'capability_unsupported',
        `Provider '${booking.providerId}' does not support cancellation`,
      );
    }
    if (booking.status === 'cancelled') {
      return this.toResponse(booking);
    }
    const result = await provider.cancelBooking({
      bookingReference: booking.bookingReference ?? undefined,
      offerSnapshot: booking.offerSnapshot,
    });
    if (!result.success) {
      throw new BookingException(
        'provider_error',
        result.error ?? 'Provider cancellation failed',
      );
    }
    booking.status = 'cancelled';
    return this.toResponse(await this.bookings.save(booking));
  }

  // ------------------------------------------------------------------

  /**
   * Compares a LIVE provider revalidation with the exact state the customer
   * last accepted and persists the resulting pending change.
   *
   * The accepted snapshot is retained while a change is pending, so repeated
   * revalidations keep reporting the ORIGINAL accepted price rather than the
   * intermediate one. Acceptance is cleared on any change; it is never
   * silently refreshed.
   */
  private applyLiveRevalidation(
    booking: Booking,
    live: BookingRevalidation,
  ): LiveRevalidationOutcome {
    const metadata = { ...(booking.providerMetadata ?? {}) };
    const prior = (metadata.priceRevalidation ?? {}) as Record<string, any>;
    const acceptance = (metadata.priceAcceptance ?? null) as
      | Record<string, any>
      | null;

    const liveTerms =
      live.terms && typeof live.terms === 'object' ? live.terms : null;
    const liveVersion = liveTerms
      ? live.termsVersion ?? termsVersionOf(liveTerms)
      : null;

    const acceptedPrice =
      typeof prior.acceptedPrice === 'number' &&
      Number.isFinite(prior.acceptedPrice)
        ? prior.acceptedPrice
        : typeof acceptance?.price === 'number' &&
            Number.isFinite(acceptance.price)
          ? acceptance.price
          : Number.isFinite(booking.authoritativePrice)
            ? booking.authoritativePrice
            : null;
    const acceptedTerms =
      prior.acceptedTerms && typeof prior.acceptedTerms === 'object'
        ? prior.acceptedTerms
        : acceptance?.terms && typeof acceptance.terms === 'object'
          ? acceptance.terms
          : null;
    const acceptedVersion =
      typeof prior.acceptedTermsVersion === 'string'
        ? prior.acceptedTermsVersion
        : typeof acceptance?.termsVersion === 'string'
          ? acceptance.termsVersion
          : null;

    // A provider that does not return terms keeps the previously known ones.
    // Absence of a fact is never treated as a changed fact.
    const terms = liveTerms ?? acceptedTerms;
    const termsVersion = liveTerms
      ? (liveVersion as string)
      : acceptedVersion ?? termsVersionOf({});

    const providerChanged = Array.isArray(live.changedTerms)
      ? live.changedTerms.filter(
          (entry: unknown): entry is string =>
            typeof entry === 'string' && entry.length > 0,
        )
      : [];
    const changedTerms = [
      ...new Set([
        ...providerChanged,
        ...diffOfferTerms(acceptedTerms, liveTerms),
      ]),
    ].sort();

    const priceChanged =
      acceptedPrice !== null &&
      Math.abs(acceptedPrice - live.price) > PRICE_TOLERANCE;
    const termsChanged = changedTerms.length > 0;

    const accepted =
      acceptance?.decision === 'accepted' &&
      acceptance.providerId === booking.providerId &&
      acceptance.offerId === booking.offerId &&
      acceptance.offerType === booking.type &&
      typeof acceptance.price === 'number' &&
      Math.abs(acceptance.price - live.price) <= PRICE_TOLERANCE &&
      acceptance.currency === live.currency &&
      typeof acceptance.termsVersion === 'string' &&
      acceptance.termsVersion === termsVersion;

    const requiresAcceptance = !accepted;
    const pendingChanged =
      requiresAcceptance &&
      (prior.pending !== true ||
        typeof prior.currentPrice !== 'number' ||
        Math.abs(prior.currentPrice - live.price) > PRICE_TOLERANCE ||
        prior.currency !== live.currency ||
        prior.termsVersion !== termsVersion);
    const firstDetection =
      pendingChanged && (priceChanged || termsChanged);

    booking.authoritativePrice = live.price;
    booking.currency = live.currency;
    // Only an accepted live state carries a payable version. A pending or
    // declined change clears it, which blocks payment creation until the
    // customer explicitly accepts the new price/terms.
    booking.priceVersion = accepted
      ? priceVersionOf({
          providerId: booking.providerId,
          offerId: booking.offerId,
          offerType: booking.type,
          amount: live.price,
          currency: live.currency,
          termsVersion,
        })
      : null;
    if (requiresAcceptance && priceChanged) {
      booking.previousPrice = acceptedPrice;
    }
    booking.providerMetadata = {
      ...metadata,
      priceRevalidation: {
        providerId: booking.providerId,
        offerId: booking.offerId,
        offerType: booking.type,
        acceptedPrice,
        acceptedTerms,
        acceptedTermsVersion: acceptedVersion,
        previousPrice: requiresAcceptance ? acceptedPrice : null,
        previousTerms: requiresAcceptance ? acceptedTerms : null,
        currentPrice: live.price,
        currency: live.currency,
        terms,
        termsVersion,
        changedTerms: requiresAcceptance ? changedTerms : [],
        pending: requiresAcceptance,
        checkedAt: new Date().toISOString(),
        expiresAt: live.expiresAt ?? booking.expiresAt?.toISOString() ?? null,
      },
      priceAcceptance: accepted ? acceptance : null,
      ...(pendingChanged ? { priceChangeDecision: null } : {}),
    };

    return {
      requiresAcceptance,
      firstDetection,
      priceChanged,
      termsChanged,
      changedTerms,
      previousPrice: requiresAcceptance ? acceptedPrice : null,
      previousTerms: requiresAcceptance ? acceptedTerms : null,
      currentPrice: live.price,
      currency: live.currency,
      terms,
      termsVersion,
    };
  }

  private priceChangeAuditMetadata(
    booking: Booking,
    outcome: LiveRevalidationOutcome,
  ): Record<string, any> {
    return {
      bookingId: booking.id,
      providerId: booking.providerId,
      offerId: booking.offerId,
      offerType: booking.type,
      previousPrice: outcome.previousPrice,
      currentPrice: outcome.currentPrice,
      currency: outcome.currency,
      priceChanged: outcome.priceChanged,
      termsChanged: outcome.termsChanged,
      changedTerms: outcome.changedTerms,
      termsVersion: outcome.termsVersion,
      timestamp: new Date().toISOString(),
    };
  }

  private async auditBooking(
    action: string,
    userId: string,
    booking: Booking,
    metadata: Record<string, any>,
  ): Promise<void> {
    if (!this.audit) return;
    try {
      await this.audit.save(
        this.audit.create({
          userId,
          action,
          metadata: { ...metadata, bookingId: booking.id },
        }),
      );
    } catch {
      // Audit persistence must never block or corrupt a booking transition.
    }
  }

  private priceChangeDetails(booking: Booking): Record<string, any> {
    const summary = this.toPriceChange(booking);
    return summary ? { ...summary } : {};
  }

  /** Wire summary of the pending/accepted price-and-terms state. */
  private toPriceChange(booking: Booking): PriceChangeSummary | null {
    const metadata = booking.providerMetadata ?? {};
    const meta = metadata.priceRevalidation as
      | Record<string, any>
      | undefined;
    if (
      !meta ||
      typeof meta.currentPrice !== 'number' ||
      !Number.isFinite(meta.currentPrice) ||
      meta.currentPrice <= 0
    ) {
      return null;
    }
    const currency =
      typeof meta.currency === 'string' ? meta.currency : booking.currency;
    if (!currency) return null;

    const acceptance = metadata.priceAcceptance as
      | Record<string, any>
      | undefined;
    const decision = metadata.priceChangeDecision as
      | Record<string, any>
      | undefined;
    const termsVersion =
      typeof meta.termsVersion === 'string'
        ? meta.termsVersion
        : termsVersionOf(meta.terms ?? {});
    const accepted =
      acceptance?.decision === 'accepted' &&
      acceptance.providerId === booking.providerId &&
      acceptance.offerId === booking.offerId &&
      acceptance.offerType === booking.type &&
      typeof acceptance.price === 'number' &&
      Math.abs(acceptance.price - meta.currentPrice) <= PRICE_TOLERANCE &&
      acceptance.currency === currency &&
      acceptance.termsVersion === termsVersion;

    const previousPrice =
      typeof meta.previousPrice === 'number' ? meta.previousPrice : null;
    const changedTerms = Array.isArray(meta.changedTerms)
      ? meta.changedTerms.filter(
          (entry: unknown): entry is string => typeof entry === 'string',
        )
      : [];
    const priceChanged =
      previousPrice !== null &&
      Math.abs(previousPrice - meta.currentPrice) > PRICE_TOLERANCE;
    const termsChanged = changedTerms.length > 0;
    const requiresAcceptance =
      (meta.pending === true || priceChanged || termsChanged) && !accepted;

    return {
      providerId: booking.providerId,
      offerId: booking.offerId,
      offerType: booking.type,
      previousPrice,
      currentPrice: meta.currentPrice,
      currency,
      priceDifference:
        previousPrice !== null
          ? priceDifference(previousPrice, meta.currentPrice)
          : 0,
      priceChangePercent:
        previousPrice !== null
          ? priceChangePercent(previousPrice, meta.currentPrice)
          : null,
      priceChanged,
      termsChanged,
      changedTerms,
      previousTerms: meta.previousTerms ?? null,
      currentTerms: meta.terms ?? null,
      termsVersion,
      requiresAcceptance,
      accepted,
      decision:
        decision?.decision === 'accepted' || decision?.decision === 'declined'
          ? decision.decision
          : null,
      decidedAt:
        typeof decision?.decidedAt === 'string' ? decision.decidedAt : null,
      checkedAt:
        typeof meta.checkedAt === 'string'
          ? meta.checkedAt
          : new Date().toISOString(),
      expiresAt:
        typeof meta.expiresAt === 'string'
          ? meta.expiresAt
          : booking.expiresAt?.toISOString() ?? null,
    };
  }

  private async findOwn(userId: string, bookingId: string): Promise<Booking> {
    const booking = await this.bookings.findOne({
      where: { id: bookingId, userId },
    });
    if (!booking) {
      throw new BookingException('booking_not_found', 'Booking not found');
    }
    return booking;
  }

  /**
   * Resolve the exact payment attempt that authorizes this booking.
   *
   * An explicit `paymentAttemptId` is still fully verified. Without one, the
   * server auto-selects only when EXACTLY ONE verified attempt matches this
   * booking, user, amount, currency and accepted price version — never the
   * client's claim, and never a cheaper old-price attempt.
   *
   * The missing repository is tolerated only in the test runtime so legacy
   * booking unit tests can construct the service without a database. Any
   * production runtime without it fails closed.
   */
  private async resolvePaymentEvidence(
    userId: string,
    booking: Booking,
    dto: CreateBookingDto,
  ): Promise<PaymentAttempt | null> {
    if (!this.paymentAttempts) {
      if (isTestRuntime()) return null;
      throw new BookingException(
        'payment_required',
        'Verified payment evidence is unavailable; booking confirmation is disabled.',
      );
    }

    if (typeof booking.priceVersion !== 'string' || !booking.priceVersion) {
      throw new BookingException(
        'payment_required',
        'No accepted price version is recorded for this booking.',
      );
    }

    if (dto.paymentAttemptId) {
      const attempt = await this.paymentAttempts.findOne({
        where: { id: dto.paymentAttemptId },
      });
      this.assertPaymentEvidence(booking, attempt);
      this.assertNoDifferentAttachedAttempt(booking, attempt);
      return attempt;
    }

    const candidates = await this.paymentAttempts.find({
      where: { bookingId: booking.id, userId, status: 'succeeded' },
    });
    const matching = candidates.filter(
      attempt => this.paymentEvidenceProblem(booking, attempt) === null,
    );
    if (matching.length === 0) {
      throw new BookingException(
        'payment_required',
        'A verified payment is required before this booking can be confirmed.',
      );
    }
    if (matching.length > 1) {
      throw new BookingException(
        'payment_not_verified',
        'More than one verified payment matches this booking; specify the exact payment attempt.',
      );
    }
    this.assertNoDifferentAttachedAttempt(booking, matching[0]);
    return matching[0];
  }

  private assertNoDifferentAttachedAttempt(
    booking: Booking,
    attempt: PaymentAttempt,
  ): void {
    if (booking.paymentAttemptId && booking.paymentAttemptId !== attempt.id) {
      throw new BookingException(
        'payment_not_verified',
        'A different payment is already attached to this booking.',
        { bookingId: booking.id, paymentAttemptId: attempt.id },
      );
    }
  }

  /**
   * Re-verify the payment attached to a booking immediately before it becomes
   * confirmed (normal completion and admin reconciliation).
   */
  private async requirePaymentEvidenceForBooking(
    booking: Booking,
  ): Promise<void> {
    if (!this.paymentAttempts) {
      if (isTestRuntime()) return;
      throw new BookingException(
        'payment_required',
        'Verified payment evidence is unavailable; booking confirmation is disabled.',
      );
    }

    if (!booking.paymentAttemptId) {
      throw new BookingException(
        'payment_required',
        'No verified payment is attached to this booking.',
      );
    }
    const attempt = await this.paymentAttempts.findOne({
      where: { id: booking.paymentAttemptId },
    });
    this.assertPaymentEvidence(booking, attempt);
  }

  private assertPaymentEvidence(
    booking: Booking,
    attempt: PaymentAttempt | null,
  ): asserts attempt is PaymentAttempt {
    const problem = this.paymentEvidenceProblem(booking, attempt);
    if (problem) {
      throw new BookingException('payment_not_verified', problem, {
        bookingId: booking.id,
        paymentAttemptId: attempt?.id ?? null,
      });
    }
  }

  /** Returns a human-readable reason, or null when the attempt is valid proof. */
  private paymentEvidenceProblem(
    booking: Booking,
    attempt: PaymentAttempt | null,
  ): string | null {
    if (!attempt) {
      return 'Payment not found.';
    }
    if (
      attempt.bookingId !== booking.id ||
      attempt.userId !== booking.userId
    ) {
      return 'Payment does not belong to this booking.';
    }
    if (attempt.status !== 'succeeded') {
      return `Payment is not successful (status '${attempt.status}').`;
    }
    // Client-declared success never sets `verifiedAt`; only the server-side
    // confirm/webhook transitions do.
    if (!attempt.verifiedAt) {
      return 'Payment has no server-verified success evidence.';
    }
    if (
      !booking.priceVersion ||
      attempt.priceVersion !== booking.priceVersion
    ) {
      return 'Payment was made for a different price version.';
    }
    if (
      typeof attempt.amount !== 'number' ||
      Math.abs(attempt.amount - booking.authoritativePrice) > PRICE_TOLERANCE ||
      attempt.currency !== booking.currency
    ) {
      return 'Payment amount or currency does not match the booking.';
    }
    if (
      isProductionRuntime() &&
      (!attempt.gatewayId || attempt.gatewayId.startsWith('mock-'))
    ) {
      return 'A mock payment gateway cannot authorize a production booking.';
    }
    return null;
  }

  private isPaymentAttemptUniqueViolation(error: unknown): boolean {
    const e = error as {
      constraint?: string;
      driverError?: { constraint?: string };
    };
    const constraint = e?.constraint ?? e?.driverError?.constraint;
    return constraint === 'uq_bookings_payment_attempt';
  }

  private requireCapability(
    providerId: string,
    action: 'book' | 'revalidate' | 'cancel',
  ): BookingProvider {
    const provider = this.registry.resolve(providerId);
    if (!provider || !provider.bookingCapability[action]) {
      throw new BookingException(
        'capability_unsupported',
        `Provider '${providerId}' does not support ${action}`,
      );
    }
    return provider;
  }

  private async fail(booking: Booking): Promise<void> {
    // Conditional on `confirming`: if another actor already moved this booking
    // (e.g. an operator reconciliation), a late definitive failure from this
    // attempt must not overwrite that newer, authoritative state.
    try {
      const result = await this.bookings.update(
        { id: booking.id, status: 'confirming' },
        {
          status: 'failed',
          idempotencyKey: null,
          // No provider booking exists on this path, so the reserved payment
          // is not consumed. Releasing the link keeps the verified attempt
          // reusable for a retry/refund instead of stranding the booking.
          paymentAttemptId: null,
          paymentStatus: 'unverified',
          consumedAt: null,
        },
      );
      if (result.affected) {
        booking.status = 'failed';
        booking.idempotencyKey = null;
        booking.paymentAttemptId = null;
        booking.paymentStatus = 'unverified';
        booking.consumedAt = null;
      }
    } catch {
      // Persisting the failure must never mask the original error.
    }
  }

  // ------------------------------------------------------------------
  // Provider create-operation ledger and unknown-outcome handling
  // ------------------------------------------------------------------

  /**
   * Claims the durable `create_booking` operation for this logical attempt.
   *
   * The booking-row reservation already serialises concurrent create calls.
   * This ledger adds the provider-scoped identity (`<bookingId>:<key>`) so a
   * retried or recovered request can see that a provider call already exists
   * and MUST NOT submit again. `failed` / `not_found` are the only statuses
   * that allow a new call, and `not_found` is reachable only through the
   * explicit admin reconciliation.
   */
  private async beginProviderCreate(
    booking: Booking,
    idempotencyKey: string,
  ): Promise<ProviderCreateAttempt> {
    const operationKey = `${booking.id}:${idempotencyKey}`;
    if (!this.operations) {
      return { operationKey };
    }

    const findExisting = () =>
      this.operations!.findOne({
        where: { providerId: booking.providerId, idempotencyKey: operationKey },
      });

    let existing = await findExisting();
    if (!existing) {
      const row = this.operations.create({
        bookingId: booking.id,
        providerId: booking.providerId,
        operation: 'create_booking',
        idempotencyKey: operationKey,
        providerRef: null,
        status: 'pending',
        startedAt: new Date(),
        requestMetadata: {
          bookingId: booking.id,
          offerId: booking.offerId,
          idempotencyKey,
          attempt: 1,
        },
      });
      try {
        const saved = await this.operations.save(row);
        return { operationId: saved.id, operationKey };
      } catch (error) {
        if (!this.isUniqueViolation(error)) throw error;
        // Another writer won the (providerId, idempotencyKey) insert. Re-read
        // and apply the same fail-closed rules instead of calling the vendor.
        existing = await findExisting();
        if (!existing) throw error;
      }
    }

    if (existing.status === 'confirmed') {
      const replay = this.createdBookingFromOperation(existing);
      return replay
        ? { operationId: existing.id, operationKey, replay }
        : { operationId: existing.id, operationKey, blockedBy: existing };
    }

    if (existing.status === 'failed' || existing.status === 'not_found') {
      const previousAttempt = Number(existing.requestMetadata?.attempt ?? 1);
      existing.status = 'pending';
      existing.providerRef = null;
      existing.startedAt = new Date();
      existing.completedAt = null;
      existing.requestMetadata = {
        ...(existing.requestMetadata ?? {}),
        bookingId: booking.id,
        offerId: booking.offerId,
        idempotencyKey,
        attempt: Number.isFinite(previousAttempt) ? previousAttempt + 1 : 2,
        retriedAt: new Date().toISOString(),
      };
      const saved = await this.operations.save(existing);
      return { operationId: saved.id ?? existing.id, operationKey };
    }

    // pending | unknown: the provider may already have acted. Never call it.
    return { operationId: existing.id, operationKey, blockedBy: existing };
  }

  /** Reconstruct definitive success evidence from a confirmed operation row. */
  private createdBookingFromOperation(
    operation: ProviderOperation,
  ): CreatedBooking | null {
    const meta = operation.responseMetadata ?? {};
    const reference =
      (typeof operation.providerRef === 'string' && operation.providerRef.trim()) ||
      (typeof meta.reference === 'string' && meta.reference.trim()) ||
      '';
    if (!reference) return null;
    return {
      reference,
      providerBookingId:
        typeof meta.providerBookingId === 'string'
          ? meta.providerBookingId
          : undefined,
      status: typeof meta.status === 'string' ? meta.status : undefined,
      amount: typeof meta.amount === 'number' ? meta.amount : undefined,
      currency: typeof meta.currency === 'string' ? meta.currency : undefined,
    };
  }

  /**
   * Compare the amount/currency the provider reports on a successful booking
   * with what the customer actually accepted. A difference means the provider
   * charged (or booked) something other than the accepted commercial version,
   * so the booking must be reconciled rather than confirmed. Absent provider
   * figures are not a mismatch; they are simply not independent evidence.
   */
  private providerAmountMismatch(
    booking: Booking,
    data: CreatedBooking,
  ): string | null {
    const bookingCurrency = String(booking.currency ?? '').trim().toUpperCase();
    if (typeof data.amount === 'number' && Number.isFinite(data.amount)) {
      if (Math.abs(data.amount - booking.authoritativePrice) > PRICE_TOLERANCE) {
        return (
          `Provider amount ${data.amount} ${data.currency ?? bookingCurrency} ` +
          `does not match the accepted amount ${booking.authoritativePrice} ${bookingCurrency}`
        );
      }
    }
    if (typeof data.currency === 'string' && data.currency.trim()) {
      if (data.currency.trim().toUpperCase() !== bookingCurrency) {
        return (
          `Provider currency ${data.currency} does not match the accepted ` +
          `currency ${bookingCurrency}`
        );
      }
    }
    return null;
  }

  /** Persist a definitive success and preserve the investigation trail. */
  private async finalizeConfirmed(
    booking: Booking,
    data: CreatedBooking,
    operationId?: string,
  ): Promise<BookingResponse> {
    // Re-verify at the LAST moment before the booking becomes confirmed. A
    // refund or state change that happened while the provider call was in
    // flight must stop the confirmation.
    await this.requirePaymentEvidenceForBooking(booking);

    const previousAttempt = (booking.providerMetadata?.providerBookingAttempt ??
      {}) as Record<string, any>;
    booking.status = 'confirmed';
    booking.bookingReference = data.reference;
    booking.confirmingSince = null;
    booking.providerMetadata = {
      ...(booking.providerMetadata ?? {}),
      providerBookingId: data.providerBookingId,
      providerStatus: data.status,
      amount: data.amount,
      currency: data.currency,
      providerBookingAttempt: {
        ...previousAttempt,
        providerId: booking.providerId,
        offerId: booking.offerId,
        idempotencyKey: booking.idempotencyKey,
        operationId: operationId ?? previousAttempt.operationId ?? null,
        outcome: 'confirmed',
        confirmedAt: new Date().toISOString(),
        requiresReconciliation: false,
        retryable: false,
      },
    };
    return this.toResponse(await this.bookings.save(booking));
  }

  /**
   * Record the provider-call outcome. Best-effort: the booking row is the
   * safety authority, so an operation-ledger write failure must never change
   * a fail-closed decision, reopen the booking, or release its key.
   *
   * `onlyFrom` makes the write a compare-and-set. When it matches zero rows,
   * the current operation state is read back purely so the caller/operator can
   * see that a newer reconciliation won; the row is PRESERVED and there is no
   * unconditional fallback write.
   */
  private async completeProviderOperation(
    operationId: string | undefined,
    status: ProviderOperationStatus,
    responseMetadata: Record<string, any>,
    providerRef?: string,
    onlyFrom?: ProviderOperationStatus[],
  ): Promise<ProviderOperationWriteOutcome | undefined> {
    if (!this.operations || !operationId) return undefined;
    try {
      const result = await this.operations.update(
        {
          id: operationId,
          ...(onlyFrom && onlyFrom.length > 0
            ? { status: In(onlyFrom) }
            : {}),
        },
        {
          status,
          responseMetadata,
          completedAt: new Date(),
          ...(providerRef ? { providerRef } : {}),
        },
      );

      if (onlyFrom && onlyFrom.length > 0 && result.affected === 0) {
        // The compare-and-set lost: an admin reconciliation (or another
        // writer) already resolved this operation. Read it back and preserve
        // it. Never retry the write without the condition.
        const current = await this.operations.findOne({
          where: { id: operationId },
        });
        return { applied: false, currentStatus: current?.status };
      }

      return { applied: true, currentStatus: status };
    } catch {
      // Undefined means the ledger write could not be recorded. Callers keep
      // the fail-closed booking state; `reconcile(not_found)` explicitly
      // refuses to release the key in this case.
      return undefined;
    }
  }

  /**
   * Persist the durable unknown state. The idempotency key is intentionally
   * RETAINED: it is the logical identity of the one provider call that may
   * have succeeded.
   */
  private async markReconciliationPending(
    booking: Booking,
    evidence: UnknownOutcomeEvidence,
  ): Promise<void> {
    const previousAttempt = (booking.providerMetadata?.providerBookingAttempt ??
      {}) as Record<string, any>;
    booking.status = 'reconciliation_pending';
    booking.confirmingSince = null;
    booking.providerMetadata = {
      ...(booking.providerMetadata ?? {}),
      providerBookingAttempt: {
        ...previousAttempt,
        providerId: booking.providerId,
        offerId: booking.offerId,
        idempotencyKey: booking.idempotencyKey,
        operationId: evidence.operationId ?? previousAttempt.operationId ?? null,
        operationKey: evidence.operationKey ?? previousAttempt.operationKey ?? null,
        outcome: 'unknown',
        failureKind: 'ambiguous',
        priorOperationStatus: evidence.priorOperationStatus ?? null,
        providerReference: evidence.providerReference ?? null,
        providerBookingId: evidence.providerBookingId ?? null,
        providerStatus: evidence.providerStatus ?? null,
        error: this.safeError(evidence.error),
        attemptedAt: new Date().toISOString(),
        requiresReconciliation: true,
        retryable: false,
      },
    };
    try {
      await this.bookings.save(booking);
    } catch {
      // If this write is lost, the row stays `confirming`, which still blocks
      // every retry. Never reopen the key because persistence failed.
    }
  }

  /**
   * The stable, non-2xx machine-readable response for an unknown outcome.
   * Never says the booking failed: failure would wrongly invite a retry.
   */
  private async unknownOutcomeException(
    booking: Booking,
    operation?: ProviderOperation,
  ): Promise<BookingException> {
    const recorded = operation ?? (await this.findCreateOperation(booking));
    return new BookingException(
      'booking_outcome_unknown',
      'The provider booking outcome is not confirmed yet. This booking is pending reconciliation; do not retry or make another payment.',
      {
        bookingId: booking.id,
        status: booking.status,
        providerId: booking.providerId,
        offerId: booking.offerId,
        idempotencyKey: booking.idempotencyKey,
        operationId: recorded?.id ?? null,
        operationKey: recorded?.idempotencyKey ?? null,
        operationStatus: recorded?.status ?? null,
        requiresReconciliation: true,
        retryable: false,
        reconciliation: {
          method: 'POST',
          path: `/bookings/${booking.id}/reconcile`,
          adminOnly: true,
        },
      },
    );
  }

  private async findCreateOperation(
    booking: Booking,
  ): Promise<ProviderOperation | undefined> {
    if (!this.operations) return undefined;
    const attempted = (booking.providerMetadata?.providerBookingAttempt ??
      {}) as Record<string, any>;
    const operationKey =
      typeof attempted.operationKey === 'string' && attempted.operationKey
        ? attempted.operationKey
        : booking.idempotencyKey
          ? `${booking.id}:${booking.idempotencyKey}`
          : null;
    if (!operationKey) return undefined;
    try {
      return (
        (await this.operations.findOne({
          where: { providerId: booking.providerId, idempotencyKey: operationKey },
        })) ?? undefined
      );
    } catch {
      return undefined;
    }
  }

  private reconciliationAuditMetadata(
    booking: Booking,
    operationId?: string,
    error?: string,
  ): Record<string, any> {
    return {
      bookingId: booking.id,
      providerId: booking.providerId,
      offerId: booking.offerId,
      idempotencyKey: booking.idempotencyKey,
      operationId: operationId ?? null,
      outcome: 'unknown',
      requiresReconciliation: true,
      retryable: false,
      error: this.safeError(error),
      timestamp: new Date().toISOString(),
    };
  }

  private safeError(error: unknown): string | null {
    if (error === undefined || error === null) return null;
    const text = typeof error === 'string' ? error : String(error);
    return text.length > 500 ? `${text.slice(0, 500)}…` : text;
  }

  private isUniqueViolation(error: unknown): boolean {
    return (
      error instanceof QueryFailedError &&
      (error as any)?.driverError?.code === '23505'
    );
  }

  private inferType(providerId: string): string {
    if (providerId.includes('flight')) return 'flight';
    if (providerId.includes('hotel') || providerId === 'nuitee') return 'hotel';
    if (providerId.includes('car')) return 'car';
    return 'flight';
  }

  private toResponse(booking: Booking): BookingResponse {
    return {
      id: booking.id,
      userId: booking.userId,
      searchId: booking.searchId ?? null,
      offerId: booking.offerId,
      providerId: booking.providerId,
      providerName: booking.providerName,
      type: booking.type,
      status: booking.status,
      currency: booking.currency,
      authoritativePrice: booking.authoritativePrice,
      previousPrice: booking.previousPrice ?? null,
      priceChanged:
        booking.previousPrice != null &&
        Math.abs(booking.previousPrice - booking.authoritativePrice) > PRICE_TOLERANCE,
      available: !['failed', 'expired', 'cancelled'].includes(booking.status),
      bookingReference: booking.bookingReference ?? null,
      travelers: booking.travelers ?? [],
      expiresAt: booking.expiresAt ?? null,
      priceChange: this.toPriceChange(booking),
      createdAt: booking.createdAt,
      updatedAt: booking.updatedAt,
    };
  }
}
