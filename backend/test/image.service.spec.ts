jest.mock('../src/common/images/image-fetch.util', () => ({
  fetchAuthorizedImage: jest.fn(),
  MAX_IMAGE_BYTES: 12 * 1024 * 1024,
}));

import sharp from 'sharp';
import { fetchAuthorizedImage } from '../src/common/images/image-fetch.util';
import {
  IMAGE_CACHE_CONTROL,
  ImageService,
} from '../src/modules/images/image.service';
import { HotelImage } from '../src/database/entities/hotel-image.entity';

/**
 * Image pipeline (high-load refactor, Phase 2).
 *
 * Verifies the pipeline contract that matters for cost and safety:
 * WebP conversion, dimension/format rejection, deterministic idempotent keys,
 * CDN URL persistence (never the provider URL), dedupe before download, and
 * the immutable one-year cache policy.
 */

const PNG_200x150 = (): Promise<Buffer> =>
  sharp({
    create: {
      width: 200,
      height: 150,
      channels: 3,
      background: { r: 200, g: 160, b: 90 },
    },
  })
    .png()
    .toBuffer();

function makeRepo(initial?: Partial<HotelImage>) {
  const rows: HotelImage[] = [];
  if (initial) rows.push({ ...initial } as HotelImage);

  let captured: any;
  const executeInsert = async () => {
    const existing = rows.find((r) => r.objectKey === captured.objectKey);
    if (!existing) {
      rows.push({
        id: `row-${rows.length + 1}`,
        createdAt: new Date(),
        updatedAt: new Date(),
        ...captured,
      } as HotelImage);
    }
  };

  return {
    rows,
    findOne: jest.fn(async ({ where }: any) => {
      if (where.sourceUrlHash) {
        return rows.find((r) => r.sourceUrlHash === where.sourceUrlHash) ?? null;
      }
      if (where.objectKey) {
        return rows.find((r) => r.objectKey === where.objectKey) ?? null;
      }
      if (where.id) {
        return rows.find((r) => r.id === where.id) ?? null;
      }
      return null;
    }),
    createQueryBuilder: jest.fn(() => ({
      insert: () => ({
        into: () => ({
          values: (values: any) => {
            captured = values;
            return { orIgnore: () => ({ execute: executeInsert }) };
          },
        }),
      }),
    })),
  };
}

function makeStorage() {
  const objects = new Map<string, Buffer>();
  return {
    objects,
    exists: jest.fn(async (key: string) => objects.has(key)),
    putObject: jest.fn(async (input: { key: string; body: Buffer }) => {
      objects.set(input.key, input.body);
    }),
    cdnUrlFor: jest.fn((key: string) => `https://cdn.example.com/${key}`),
  };
}

describe('ImageService', () => {
  const mockedFetch = fetchAuthorizedImage as jest.Mock;

  beforeEach(() => jest.clearAllMocks());

  it('uses the immutable one-year cache policy', () => {
    expect(IMAGE_CACHE_CONTROL).toBe('public, max-age=31536000, immutable');
  });

  it('transcodes a valid PNG to WebP and reports dimensions', async () => {
    const service = new ImageService(makeStorage() as any, makeRepo() as any);
    const encoded = await service.transcode(await PNG_200x150(), 120);
    expect(encoded.contentType).toBe('image/webp');
    expect(encoded.width).toBe(120);
    expect(encoded.height).toBe(90);
    expect(encoded.bytes.length).toBeGreaterThan(0);
  });

  it('rejects an invalid/corrupt image', async () => {
    const service = new ImageService(makeStorage() as any, makeRepo() as any);
    await expect(service.transcode(Buffer.from('not an image'))).rejects.toThrow(
      /Unsupported or corrupt|Input buffer contains unsupported image format/i,
    );
  });

  it('uploads a deterministic object key and persists the CDN URL + metadata', async () => {
    const png = await PNG_200x150();
    mockedFetch.mockResolvedValue({ bytes: png, contentType: 'image/png' });
    const storage = makeStorage();
    const repo = makeRepo();
    const service = new ImageService(storage as any, repo as any);

    const result = await service.optimizeAndUpload({
      sourceUrl: 'https://static.cupid.travel/hotel-a.png',
      width: 480,
    });

    expect(result.reused).toBe(false);
    expect(result.cdnUrl).toMatch(/^https:\/\/cdn\.example\.com\//);
    expect(result.objectKey).toMatch(/^hotels\/[0-9a-f]{16}\/\d+x\/[0-9a-f]{64}\.webp$/);
    expect(result.cacheControl).toBe('public, max-age=31536000, immutable');
    expect(storage.putObject).toHaveBeenCalledTimes(1);
    expect(storage.putObject.mock.calls[0][0].cacheControl).toBe(
      'public, max-age=31536000, immutable',
    );

    const persisted = repo.rows[0];
    expect(persisted.cdnUrl).toBe(result.cdnUrl);
    expect(persisted.objectKey).toBe(result.objectKey);
    expect(persisted.contentType).toBe('image/webp');
  });

  it('is idempotent: the same source URL is not downloaded twice', async () => {
    const png = await PNG_200x150();
    mockedFetch.mockResolvedValue({ bytes: png, contentType: 'image/png' });
    const storage = makeStorage();
    const repo = makeRepo();
    const service = new ImageService(storage as any, repo as any);

    const first = await service.optimizeAndUpload({
      sourceUrl: 'https://static.cupid.travel/hotel-b.png',
    });
    const second = await service.optimizeAndUpload({
      sourceUrl: 'https://static.cupid.travel/hotel-b.png',
    });

    expect(mockedFetch).toHaveBeenCalledTimes(1);
    expect(second.reused).toBe(true);
    expect(second.objectKey).toBe(first.objectKey);
    expect(storage.putObject).toHaveBeenCalledTimes(1);
  });

  it('reuses an existing object instead of uploading again', async () => {
    const png = await PNG_200x150();
    mockedFetch.mockResolvedValue({ bytes: png, contentType: 'image/png' });
    const storage = makeStorage();
    const repo = makeRepo();
    const service = new ImageService(storage as any, repo as any);

    const first = await service.optimizeAndUpload({
      sourceUrl: 'https://static.cupid.travel/hotel-c.png',
    });
    // Simulate the metadata row being lost but the object still present.
    repo.rows.length = 0;
    storage.exists.mockResolvedValueOnce(true);

    const second = await service.optimizeAndUpload({
      sourceUrl: 'https://static.cupid.travel/hotel-c.png',
    });
    expect(storage.putObject).toHaveBeenCalledTimes(1);
    expect(second.objectKey).toBe(first.objectKey);
  });

  it('rejects a non-image source (content type guard)', async () => {
    mockedFetch.mockResolvedValue(null);
    const service = new ImageService(makeStorage() as any, makeRepo() as any);
    await expect(
      service.optimizeAndUpload({ sourceUrl: 'https://evil.example/x.png' }),
    ).rejects.toThrow(/authorized/);
  });
});
