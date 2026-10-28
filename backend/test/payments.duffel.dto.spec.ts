import { BadRequestException, ValidationPipe } from '@nestjs/common';
import {
  ConfirmPaymentDto,
  CreatePaymentDto,
  RefundDto,
  WebhookDto,
} from '../src/common/dto/payment.dto';
import {
  DuffelCreateBookingDto,
  DuffelFlightSearchDto,
} from '../src/common/dto/duffel.dto';

/**
 * Stage-2 refactor contracts (2026-10-25).
 *
 * Root cause pinned here: the payment DTOs were undecorated classes inside the
 * controller. The global pipe runs with `whitelist: true` +
 * `forbidNonWhitelisted: true`, so an undecorated class allowed ZERO fields and
 * every `/payments/*` call died with a 400 before reaching the handler. These
 * tests exercise the real pipe with the real Flutter payloads.
 */

// The exact configuration from src/main.ts.
const pipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});

function body(metatype: any) {
  return { type: 'body' as const, metatype };
}

/** The payload checkout_payment_service.dart actually sends. */
const INTENT_PAYLOAD = {
  bookingId: 'bk-123',
  amount: 1250.5,
  currency: 'EGP',
  market: 'EG',
  idempotencyKey: 'intent-key-1',
};

const CONFIRM_PAYLOAD = {
  paymentId: 'pay-1',
  methodReference: 'CARD_3DS',
  market: 'EG',
  idempotencyKey: 'confirm-key-1',
  bookingId: 'bk-123',
};

describe('payments DTOs — the Flutter payload passes the global pipe', () => {
  it('accepts a checkout intent and keeps every field', async () => {
    const dto = (await pipe.transform(
      INTENT_PAYLOAD,
      body(CreatePaymentDto),
    )) as CreatePaymentDto;

    expect(dto).toBeInstanceOf(CreatePaymentDto);
    expect(dto.bookingId).toBe('bk-123');
    expect(dto.amount).toBe(1250.5);
    expect(dto.currency).toBe('EGP');
    expect(dto.market).toBe('EG');
    expect(dto.idempotencyKey).toBe('intent-key-1');
  });

  it('accepts a confirm call with a real method reference', async () => {
    const dto = (await pipe.transform(
      CONFIRM_PAYLOAD,
      body(ConfirmPaymentDto),
    )) as ConfirmPaymentDto;

    expect(dto.methodReference).toBe('CARD_3DS');
    expect(dto.paymentId).toBe('pay-1');
  });

  it('accepts a refund without the optional reason', async () => {
    const dto = (await pipe.transform(
      {
        paymentId: 'pay-1',
        amount: 100,
        market: 'EG',
        idempotencyKey: 'refund-key-1',
        bookingId: 'bk-123',
      },
      body(RefundDto),
    )) as RefundDto;

    expect(dto.reason).toBeUndefined();
    expect(dto.amount).toBe(100);
  });

  it('accepts a signed webhook', async () => {
    const dto = (await pipe.transform(
      {
        id: 'evt-1',
        paymentId: 'pay-1',
        type: 'payment.succeeded',
        signature: 'sig-abc',
        occurredAt: '2026-10-25T09:00:00.000Z',
      },
      body(WebhookDto),
    )) as WebhookDto;

    expect(dto.type).toBe('payment.succeeded');
  });
});

describe('payments DTOs — bad input is rejected with a reason', () => {
  it('rejects an unknown field instead of silently forwarding it', async () => {
    await expect(
      pipe.transform(
        { ...INTENT_PAYLOAD, price: 1 },
        body(CreatePaymentDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a missing bookingId', async () => {
    const { bookingId, ...rest } = INTENT_PAYLOAD;
    await expect(
      pipe.transform(rest, body(CreatePaymentDto)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a negative amount', async () => {
    await expect(
      pipe.transform(
        { ...INTENT_PAYLOAD, amount: -1 },
        body(CreatePaymentDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a non ISO-4217 currency', async () => {
    await expect(
      pipe.transform(
        { ...INTENT_PAYLOAD, currency: 'egp' },
        body(CreatePaymentDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects an unknown payment method reference', async () => {
    await expect(
      pipe.transform(
        { ...CONFIRM_PAYLOAD, methodReference: 'BITCOIN' },
        body(ConfirmPaymentDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a webhook type the gateway never sends', async () => {
    await expect(
      pipe.transform(
        {
          id: 'evt-1',
          paymentId: 'pay-1',
          type: 'payment.exploded',
          signature: 'sig',
          occurredAt: '2026-10-25T09:00:00.000Z',
        },
        body(WebhookDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a webhook without an ISO timestamp', async () => {
    await expect(
      pipe.transform(
        {
          id: 'evt-1',
          paymentId: 'pay-1',
          type: 'payment.failed',
          signature: 'sig',
          occurredAt: 'yesterday',
        },
        body(WebhookDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});

describe('duffel DTOs — the unauthenticated any[] hole is closed', () => {
  it('normalises IATA codes and accepts a valid search', async () => {
    const dto = (await pipe.transform(
      {
        origin: ' cai ',
        destination: 'dxb',
        departureDate: '2026-11-01',
        passengers: 2,
      },
      body(DuffelFlightSearchDto),
    )) as DuffelFlightSearchDto;

    expect(dto.origin).toBe('CAI');
    expect(dto.destination).toBe('DXB');
    expect(dto.passengers).toBe(2);
  });

  it('rejects a non-IATA origin and a zero-passenger search', async () => {
    await expect(
      pipe.transform(
        {
          origin: 'Cairo',
          destination: 'DXB',
          departureDate: '2026-11-01',
          passengers: 1,
        },
        body(DuffelFlightSearchDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);

    await expect(
      pipe.transform(
        {
          origin: 'CAI',
          destination: 'DXB',
          departureDate: '2026-11-01',
          passengers: 0,
        },
        body(DuffelFlightSearchDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('accepts a provider-shaped booking body', async () => {
    const dto = (await pipe.transform(
      {
        offerId: 'off_123',
        passengers: [{ given_name: 'Ada', family_name: 'Lovelace' }],
        payments: [{ type: 'balance', amount: '120.00', currency: 'EGP' }],
      },
      body(DuffelCreateBookingDto),
    )) as DuffelCreateBookingDto;

    expect(dto.passengers).toHaveLength(1);
    expect(dto.payments[0].type).toBe('balance');
  });

  it('rejects an empty passenger list and non-object items', async () => {
    await expect(
      pipe.transform(
        { offerId: 'off_123', passengers: [], payments: [{}] },
        body(DuffelCreateBookingDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);

    await expect(
      pipe.transform(
        { offerId: 'off_123', passengers: ['Ada'], payments: [{}] },
        body(DuffelCreateBookingDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a booking without an offer id', async () => {
    await expect(
      pipe.transform(
        { passengers: [{}], payments: [{}] },
        body(DuffelCreateBookingDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
