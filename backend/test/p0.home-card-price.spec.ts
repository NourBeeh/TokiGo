import { AdminService } from '../src/modules/admin/admin.service';
import { HomeService } from '../src/modules/home/home.service';
import {
  CARD_CURRENCY_KEYS,
  CARD_GENERIC_AMOUNT_KEYS,
  CARD_PRICE_CONTAINER_KEYS,
  CARD_PRICE_KEYS,
  MAX_SANITIZE_DEPTH,
  sanitizeCardContent,
} from '../src/common/dto/home.dto';

/**
 * P0-S4 / L2 — Home cards must never carry a live price.
 *
 * `home_cards.content` is a JSONB blob served verbatim by `GET /home/sections`
 * with no TTL and no provider revalidation. `price` / `rawPrice` were therefore
 * permanent prices. They are gone from the response contract and stripped on
 * every write, so they can never be persisted again.
 */

describe('P0-S4 / L2 home card prices', () => {
  describe('sanitizeCardContent', () => {
    it('drops price keys and keeps unrelated presentation fields', () => {
      const output = sanitizeCardContent({
        title: 'Stay in Cairo',
        price: 999,
        rawPrice: 888,
        currency: 'USD',
        rating: 4.5,
        highlights: ['pool'],
      });

      expect(output).toEqual({
        title: 'Stay in Cairo',
        currency: 'USD',
        rating: 4.5,
        highlights: ['pool'],
      });
      expect(output).not.toHaveProperty('price');
      expect(output).not.toHaveProperty('rawPrice');
    });

    it('handles null, undefined and non-object input', () => {
      expect(sanitizeCardContent(null)).toEqual({});
      expect(sanitizeCardContent(undefined)).toEqual({});
      expect(sanitizeCardContent([] as any)).toEqual({});
    });
  });

  describe('nested metadata policy', () => {
    it('strips every known price alias at any depth, case-insensitively', () => {
      const output = sanitizeCardContent({
        title: 'X',
        Price: 1,
        metadata: {
          pricePerNight: 99,
          nightlyPrice: 88,
          totalPrice: 77,
          originalPrice: 66,
          customerPrice: 55,
          fare: 44,
          deep: { RAWPRICE: 5, baseFare: 4 },
        },
      } as Record<string, unknown>);

      expect(output).toEqual({ title: 'X', metadata: { deep: {} } });
    });

    it('walks arrays of objects', () => {
      const output = sanitizeCardContent({
        highlights: [
          { fare: 10, label: 'Beach' },
          { price: 5, label: 'City' },
        ],
      } as Record<string, unknown>);

      expect(output).toEqual({
        highlights: [{ label: 'Beach' }, { label: 'City' }],
      });
    });

    it('treats `amount` as a price only next to a currency', () => {
      const output = sanitizeCardContent({
        total: { amount: 10, currency: 'USD' },
        unrelated: { amount: 3, unit: 'kg' },
        plainAmount: 7,
      } as Record<string, unknown>);

      expect(output).toEqual({
        // `amount` is a price here (currency sibling); the currency stays.
        total: { currency: 'USD' },
        unrelated: { amount: 3, unit: 'kg' },
        plainAmount: 7,
      });
    });

    it('preserves unrelated descriptive metadata', () => {
      const content = {
        title: 'Stay',
        subtitle: 'Cairo',
        description: 'Nice',
        currency: 'USD',
        rating: 4.5,
        reviewCount: 12,
        badge: 'Deal',
        tags: ['a', 'b'],
        metadata: {
          city: 'Cairo',
          countryCode: 'EG',
          providerRateId: 'r1',
          checkIn: '2026-12-01',
        },
      };

      expect(sanitizeCardContent(content as Record<string, unknown>)).toEqual(
        content,
      );
    });

    it('drops cyclic references instead of looping forever', () => {
      const content: Record<string, unknown> = { title: 'X' };
      content['metadata'] = content; // cycle

      expect(() => sanitizeCardContent(content)).not.toThrow();
      expect(sanitizeCardContent(content).title).toBe('X');
    });

    it('drops pathologically deep subtrees rather than keeping them', () => {
      let deep: Record<string, unknown> = { price: 1 };
      for (let i = 0; i < 30; i++) {
        deep = { nested: deep };
      }

      const output = sanitizeCardContent({
        metadata: deep,
      } as Record<string, unknown>);

      expect(JSON.stringify(output)).not.toContain('"price"');
    });
  });

  describe('public home feed', () => {
    it('never emits price or rawPrice even when the row still has them', async () => {
      const sectionRepo = {
        find: jest.fn().mockResolvedValue([
          {
            id: 's1',
            title: 'Stays',
            subtitle: null,
            layout: 'grid',
            order: 1,
            isVisible: true,
            status: 'published',
            publishAt: null,
            expiresAt: null,
          },
        ]),
      };
      const cardRepo = {
        find: jest.fn().mockResolvedValue([
          {
            id: 'c1',
            sectionId: 's1',
            cardType: 'stay',
            order: 1,
            isVisible: true,
            status: 'published',
            publishAt: null,
            expiresAt: null,
            content: {
              title: 'X',
              price: 999,
              rawPrice: 888,
              currency: 'USD',
              metadata: {
                city: 'Cairo',
                pricePerNight: 777,
                taxesAndFees: { amount: 50, currency: 'USD' },
              },
            },
          },
        ]),
      };

      const service = new HomeService(sectionRepo as any, cardRepo as any);
      const sections = await service.getSections();
      const card = sections[0].cards[0] as Record<string, unknown>;

      expect(card.title).toBe('X');
      expect(card.currency).toBe('USD');
      expect(card).not.toHaveProperty('price');
      expect(card).not.toHaveProperty('rawPrice');
    });
  });

  describe('admin write path', () => {
    function makeAdmin() {
      const sections = { findOne: jest.fn().mockResolvedValue({ id: 's1' }) };
      const cards = {
        create: jest.fn((value) => value),
        save: jest.fn((value) => Promise.resolve({ id: 'c1', ...value })),
        find: jest.fn().mockResolvedValue([]),
        findOne: jest.fn(),
      };
      const audit = {
        create: jest.fn((value) => value),
        save: jest.fn((value) => Promise.resolve(value)),
      };
      const service = new AdminService(
        sections as any,
        cards as any,
        audit as any,
        {} as any,
        {} as any,
        {} as any,
        {} as any,
      );
      return { service, cards };
    }

    it('strips price keys on create', async () => {
      const { service, cards } = makeAdmin();

      const saved = await service.createCard({
        sectionId: 's1',
        cardType: 'stay',
        content: { title: 'X', price: 999, rawPrice: 888 },
        order: 1,
      } as any);

      expect(saved.content).toEqual({ title: 'X' });
      expect(cards.create).toHaveBeenCalledWith(
        expect.objectContaining({ content: { title: 'X' } }),
      );
    });

    it('strips price keys left on the row by an earlier write, on update', async () => {
      const { service, cards } = makeAdmin();
      cards.findOne.mockResolvedValue({
        id: 'c1',
        sectionId: 's1',
        cardType: 'stay',
        order: 1,
        isVisible: true,
        status: 'published',
        content: { title: 'X', price: 999, rawPrice: 888 },
      });

      const saved = await service.updateCard('c1', {
        content: { subtitle: 'Y' },
      } as any);

      expect(saved.content).toEqual({ title: 'X', subtitle: 'Y' });
    });
  });

  describe('table-driven price policy', () => {
    // Every alias the policy knows, in the casings a provider/admin might use.
    const exactAliases = [
      'price',
      'Price',
      'PRICE',
      'rawPrice',
      'pricePerNight',
      'nightlyPrice',
      'pricePerPerson',
      'pricePerGuest',
      'pricePerRoom',
      'pricePerDay',
      'nightlyRate',
      'ratePerNight',
      'dailyRate',
      'dailyPrice',
      'weeklyPrice',
      'monthlyPrice',
      'totalPrice',
      'subTotal',
      'subtotalPrice',
      'grandTotal',
      'totalCost',
      'totalRate',
      'totalAmount',
      'totalFare',
      'originalPrice',
      'wasPrice',
      'salePrice',
      'discountedPrice',
      'discountAmount',
      'discountedAmount',
      'priceAfterDiscount',
      'currentPrice',
      'previousPrice',
      'oldPrice',
      'newPrice',
      'strikethroughPrice',
      'listPrice',
      'regularPrice',
      'basePrice',
      'startingPrice',
      'fromPrice',
      'customerPrice',
      'providerPrice',
      'supplierPrice',
      'netPrice',
      'grossPrice',
      'sellingPrice',
      'offerPrice',
      'dealPrice',
      'finalPrice',
      'fare',
      'baseFare',
      'taxAmount',
      'feeAmount',
      'serviceCharge',
      'serviceFee',
      'costAmount',
      'unitCost',
      'unitRate',
      'hourlyRate',
      'netAmount',
      'grossAmount',
      'payableAmount',
      'dueAmount',
    ];

    it.each(exactAliases)('strips alias %s', (key) => {
      const output = sanitizeCardContent({
        title: 'X',
        [key]: 123,
      } as Record<string, unknown>);
      expect(output).toEqual({ title: 'X' });
      expect(output).not.toHaveProperty(key);
    });

    it('matches aliases case-insensitively', () => {
      const output = sanitizeCardContent({
        PrIcE: 1,
        NIGHTLYrATE: 2,
        TotalFare: 3,
      } as Record<string, unknown>);
      expect(output).toEqual({});
    });

    it('strips aliases inside nested objects and arrays', () => {
      const output = sanitizeCardContent({
        metadata: {
          pricePerPerson: 1,
          rooms: [
            { nightlyRate: 2, label: 'A' },
            { totalFare: 3, label: 'B' },
          ],
          deep: { deeper: { fromPrice: 4, keep: 'yes' } },
        },
      } as Record<string, unknown>);

      expect(output).toEqual({
        metadata: {
          rooms: [{ label: 'A' }, { label: 'B' }],
          deep: { deeper: { keep: 'yes' } },
        },
      });
    });

    it('strips a generic amount with currency context', () => {
      expect(
        sanitizeCardContent({
          total: { amount: 10, currency: 'USD' },
        } as Record<string, unknown>),
      ).toEqual({ total: { currency: 'USD' } });
    });

    it('strips a generic amount under a documented price parent', () => {
      expect(
        sanitizeCardContent({
          total: { amount: 10 },
          taxesAndFees: { amount: 5 },
        } as Record<string, unknown>),
      ).toEqual({ total: {}, taxesAndFees: {} });
    });

    it('preserves a bare amount with no currency or price parent', () => {
      const content = {
        weight: { amount: 20, unit: 'kg' },
        plainAmount: 7,
      };
      expect(sanitizeCardContent(content as Record<string, unknown>)).toEqual(
        content,
      );
    });

    it('preserves measurement and quantity metadata', () => {
      const content = {
        baggage: { weight: { amount: 23, unit: 'kg' }, pieces: 2 },
        room: { area: { amount: 32, unit: 'm2' }, floor: 4 },
        duration: { amount: 5, unit: 'nights' },
        title: 'Stay',
      };
      expect(sanitizeCardContent(content as Record<string, unknown>)).toEqual(
        content,
      );
    });

    it('preserves unrelated descriptive fields and value metadata', () => {
      const content = {
        title: 'Stay',
        subtitle: 'Cairo',
        description: 'Nice',
        currency: 'USD',
        rating: 4.5,
        reviewCount: 12,
        badge: 'Deal',
        tags: ['a', 'b'],
        selection: { value: 'sea-view' },
        metadata: {
          city: 'Cairo',
          countryCode: 'EG',
          providerRateId: 'r1',
          checkIn: '2026-12-01',
        },
      };
      expect(sanitizeCardContent(content as Record<string, unknown>)).toEqual(
        content,
      );
    });

    it('drops subtrees beyond the depth limit rather than keeping them', () => {
      let deep: Record<string, unknown> = { price: 1 };
      for (let i = 0; i < MAX_SANITIZE_DEPTH + 5; i++) {
        deep = { nested: deep };
      }

      const output = sanitizeCardContent({
        metadata: deep,
      } as Record<string, unknown>);

      expect(JSON.stringify(output)).not.toContain('"price"');
    });

    it('drops cyclic references instead of looping forever', () => {
      const content: Record<string, unknown> = { title: 'X' };
      content['metadata'] = content; // cycle

      expect(() => sanitizeCardContent(content)).not.toThrow();
      expect(sanitizeCardContent(content).title).toBe('X');
    });

    it('reads the same key lists as the plain-node seed scripts', () => {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const js = require('../scripts/lib/sanitize_card_content');
      expect([...js.PRICE_KEYS].sort()).toEqual([...CARD_PRICE_KEYS].sort());
      expect([...js.PRICE_CONTAINER_KEYS].sort()).toEqual(
        [...CARD_PRICE_CONTAINER_KEYS].sort(),
      );
      expect([...js.CURRENCY_KEYS].sort()).toEqual(
        [...CARD_CURRENCY_KEYS].sort(),
      );
      expect([...js.GENERIC_AMOUNT_KEYS].sort()).toEqual(
        [...CARD_GENERIC_AMOUNT_KEYS].sort(),
      );
      expect(js.MAX_DEPTH).toBe(MAX_SANITIZE_DEPTH);
    });

    it('strips the same content as the seed script for a mixed tree', () => {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const js = require('../scripts/lib/sanitize_card_content');
      const input = {
        title: 'X',
        pricePerPerson: 5,
        total: { amount: 9 },
        weight: { amount: 2, unit: 'kg' },
        metadata: { fare: 3, city: 'Cairo' },
      };
      expect(js.sanitizeCardContent(input)).toEqual(
        sanitizeCardContent(input as Record<string, unknown>),
      );
    });
  });

  describe('response-time sanitization of pre-existing rows', () => {
    it('strips new aliases and contextual amounts from a legacy row', async () => {
      const sectionRepo = {
        find: jest.fn().mockResolvedValue([
          {
            id: 's1',
            title: 'Stays',
            subtitle: null,
            layout: 'grid',
            order: 1,
            isVisible: true,
            status: 'published',
            publishAt: null,
            expiresAt: null,
          },
        ]),
      };
      const cardRepo = {
        find: jest.fn().mockResolvedValue([
          {
            id: 'c1',
            sectionId: 's1',
            cardType: 'stay',
            order: 1,
            isVisible: true,
            status: 'published',
            publishAt: null,
            expiresAt: null,
            content: {
              title: 'X',
              nightlyRate: 120,
              fromPrice: 99,
              metadata: {
                city: 'Cairo',
                total: { amount: 500 },
                baggage: { weight: { amount: 23, unit: 'kg' } },
              },
            },
          },
        ]),
      };

      const service = new HomeService(sectionRepo as any, cardRepo as any);
      const sections = await service.getSections();
      const card = sections[0].cards[0] as Record<string, any>;

      expect(card.title).toBe('X');
      expect(card).not.toHaveProperty('nightlyRate');
      expect(card).not.toHaveProperty('fromPrice');
      expect(card.metadata).toEqual({
        city: 'Cairo',
        total: {},
        baggage: { weight: { amount: 23, unit: 'kg' } },
      });
    });
  });
});
