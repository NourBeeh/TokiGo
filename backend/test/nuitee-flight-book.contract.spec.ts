import { NuiteeFlightService } from '../src/modules/nuitee/nuitee.flight.service';
import { classifyBookingTransportFailure } from '../src/common/providers/booking-failure';

/**
 * LiteAPI `POST /flights/bookings` contract (Phase 3C).
 *
 * The documented success shape is `data: [{ booking: FlightBooking, message }]`.
 * The booking carries the provider reference/status and the journey price;
 * anything else must stay absent instead of being fabricated.
 */
function response(body: any, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => JSON.stringify(body),
  };
}

function makeService() {
  const config = { get: () => 'sand_test-key' };
  return new NuiteeFlightService(config as any);
}

const realFetch = global.fetch;

beforeEach(() => {
  (global as any).fetch = jest.fn();
});

afterAll(() => {
  (global as any).fetch = realFetch;
});

describe('NuiteeFlightService.bookFlight — documented contract', () => {
  it('sends customTags and parses data[0].booking with the journey price', async () => {
    const fetch = jest.fn().mockResolvedValue(
      response({
        data: [
          {
            booking: {
              bookingId: 'bk_1',
              bookingRef: 'FH-1',
              status: 'CONFIRMED',
              journey: { price: { total: 812.5, currency: 'usd' } },
            },
            message: 'Booking confirmed',
          },
        ],
      }),
    );
    (global as any).fetch = fetch;

    const result = await makeService().bookFlight({
      prebookId: 'pb_1',
      payment: { method: 'ACC_CREDIT_CARD' },
      customTags: {
        BOOKING_ID: 'booking-1',
        AMOUNT: '812.5',
        CURRENCY: 'USD',
      },
    });

    const body = JSON.parse(fetch.mock.calls[0][1].body);
    expect(body).toEqual({
      prebookId: 'pb_1',
      payment: { method: 'ACC_CREDIT_CARD' },
      customTags: {
        BOOKING_ID: 'booking-1',
        AMOUNT: '812.5',
        CURRENCY: 'USD',
      },
    });
    expect(result).toMatchObject({
      success: true,
      bookingId: 'bk_1',
      bookingRef: 'FH-1',
      status: 'CONFIRMED',
      amount: 812.5,
      currency: 'USD',
    });
  });

  it('keeps CREATED pending and never fabricates 0 USD', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      response({
        data: [
          {
            booking: {
              bookingId: 'bk_2',
              bookingRef: 'FH-2',
              status: 'CREATED',
              // No journey price yet: the booking is not confirmed.
            },
          },
        ],
      }),
    );

    const result = await makeService().bookFlight({
      prebookId: 'pb_2',
      payment: { method: 'ACC_CREDIT_CARD' },
    });

    expect(result.success).toBe(true);
    expect(result.status).toBe('CREATED');
    expect(result.amount).toBeUndefined();
    expect(result.currency).toBeUndefined();
  });

  it('tolerates a legacy flat data object without inventing values', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      response({
        data: {
          bookingId: 'bk_3',
          status: 'PENDING_CONFIRMATION',
        },
      }),
    );

    const result = await makeService().bookFlight({
      prebookId: 'pb_3',
      payment: { method: 'ACC_CREDIT_CARD' },
    });

    expect(result).toMatchObject({
      success: true,
      bookingId: 'bk_3',
      status: 'PENDING_CONFIRMATION',
    });
    expect(result.bookingRef).toBeUndefined();
    expect(result.amount).toBeUndefined();
    expect(result.currency).toBeUndefined();
  });

  it('surfaces the duplicate code 45035 and classifies it as ambiguous', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      response(
        {
          error: {
            code: 45035,
            message: 'A booking for this prebookId is already in progress',
          },
        },
        409,
      ),
    );

    const result = await makeService().bookFlight({
      prebookId: 'pb_4',
      payment: { method: 'ACC_CREDIT_CARD' },
    });

    expect(result.success).toBe(false);
    expect(result.error).toContain('[45035]');
    expect(
      classifyBookingTransportFailure({ error: result.error }),
    ).toBe('ambiguous');
  });

  it('classifies a well-formed 400 rejection as definitive', async () => {
    (global as any).fetch = jest.fn().mockResolvedValue(
      response({ error: { message: 'invalid passenger' } }, 400),
    );

    const result = await makeService().bookFlight({
      prebookId: 'pb_5',
      payment: { method: 'ACC_CREDIT_CARD' },
    });

    expect(result.success).toBe(false);
    expect(
      classifyBookingTransportFailure({ error: result.error }),
    ).toBe('definitive');
  });
});
