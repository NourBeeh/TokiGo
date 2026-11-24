import {
  HotelMetadataService,
  mapProviderHotel,
} from '../src/modules/discovery/hotel-metadata.service';

describe('mapProviderHotel — real provider field shapes', () => {
  it('coerces numeric strings and maps facilityIds / hotelDescription', () => {
    const mapped = mapProviderHotel(
      {
        id: 'H1',
        name: 'Grand Hotel',
        rating: '8.6',
        review_count: '1234',
        latitude: '30.04',
        longitude: '31.23',
        facilityIds: ['wifi', 5],
        hotelDescription: 'Riverside stay',
      },
      'nuitee',
    );

    expect(mapped).not.toBeNull();
    expect(mapped!.rating).toBe(4.3); // 10-point provider score → 5-point display
    expect(mapped!.reviewCount).toBe(1234);
    expect(mapped!.latitude).toBe(30.04);
    expect(mapped!.longitude).toBe(31.23);
    expect(mapped!.facilities).toEqual(['wifi', '5']);
    expect(mapped!.description).toBe('Riverside stay');
  });

  it('treats an impossible score or coordinate as absent', () => {
    const mapped = mapProviderHotel(
      {
        id: 'H2',
        name: 'Odd',
        rating: 11,
        reviewCount: -3,
        latitude: 200,
        longitude: 'not-a-number',
      },
      'nuitee',
    );

    expect(mapped!.rating).toBeUndefined();
    expect(mapped!.reviewCount).toBeUndefined();
    expect(mapped!.latitude).toBeUndefined();
    expect(mapped!.longitude).toBeUndefined();
  });

  it('does not invent a name when the provider sent none', () => {
    const mapped = mapProviderHotel({ id: 'H3' }, 'nuitee');

    expect(mapped).not.toBeNull();
    // A fabricated "Hotel H3" would overwrite a real stored name on upsert.
    expect(mapped!.name).toBeUndefined();
  });
});

describe('HotelMetadataService.upsert — non-destructive sync', () => {
  function existingRow() {
    return {
      id: 'row-1',
      providerId: 'nuitee',
      providerHotelId: 'H1',
      name: 'Old name',
      nameLocal: 'الاسم القديم',
      city: 'Cairo',
      countryCode: 'EG',
      address: '1 Nile Corniche',
      description: 'Old description',
      descriptionLocal: 'وصف قديم',
      facilities: ['Pool'],
      category: '5',
      latitude: 30.0444,
      longitude: 31.2357,
      rating: 4.5,
      reviewCount: 200,
      imageObjectKey: 'hotels/h1.jpg',
      imageUrl: 'https://example.com/h1.jpg',
      isActive: true,
      isDeleted: false,
      lastSyncedAt: new Date('2026-01-01'),
    };
  }

  it('a sparse payload preserves every previously valid field', async () => {
    const existing = existingRow();
    const repo = {
      findOne: jest.fn(async () => existing),
      update: jest.fn(async () => ({ affected: 1 })),
      create: jest.fn((value: any) => value),
      save: jest.fn(async (value: any) => value),
    };
    const service = new HotelMetadataService(repo as any);

    await service.upsert({
      providerId: 'nuitee',
      providerHotelId: 'H1',
      name: 'New name',
    });

    expect(repo.update).toHaveBeenCalledTimes(1);
    const values = repo.update.mock.calls[0][1];
    expect(values.name).toBe('New name');
    expect(values.nameLocal).toBe('الاسم القديم');
    expect(values.city).toBe('Cairo');
    expect(values.countryCode).toBe('EG');
    expect(values.address).toBe('1 Nile Corniche');
    expect(values.description).toBe('Old description');
    expect(values.descriptionLocal).toBe('وصف قديم');
    expect(values.facilities).toEqual(['Pool']);
    expect(values.category).toBe('5');
    expect(values.latitude).toBe(30.0444);
    expect(values.longitude).toBe(31.2357);
    expect(values.rating).toBe(4.5);
    expect(values.reviewCount).toBe(200);
    expect(values.imageObjectKey).toBe('hotels/h1.jpg');
    expect(values.imageUrl).toBe('https://example.com/h1.jpg');
    expect(values.isActive).toBe(true);
    expect(values.isDeleted).toBe(false);
    expect(values.lastSyncedAt).toBeInstanceOf(Date);
  });

  it('a fresh record is inserted once, with an honest fallback name', async () => {
    const repo = {
      findOne: jest.fn(async () => null),
      update: jest.fn(),
      create: jest.fn((value: any) => value),
      save: jest.fn(async (value: any) => value),
    };
    const service = new HotelMetadataService(repo as any);

    const saved = await service.upsert({
      providerId: 'nuitee',
      providerHotelId: 'H9',
    });

    expect(repo.update).not.toHaveBeenCalled();
    expect(repo.save).toHaveBeenCalledTimes(1);
    expect(saved.name).toBe('Hotel H9');
  });

  it('a nameless provider payload preserves the stored name', async () => {
    const existing = existingRow();
    const repo = {
      findOne: jest.fn(async () => existing),
      update: jest.fn(async () => ({ affected: 1 })),
      create: jest.fn((value: any) => value),
      save: jest.fn(async (value: any) => value),
    };
    const service = new HotelMetadataService(repo as any);

    const mapped = mapProviderHotel({ id: 'H1', latitude: 30.05 }, 'nuitee');
    expect(mapped).not.toBeNull();
    await service.upsert(mapped!);

    const values = repo.update.mock.calls[0][1];
    expect(values.name).toBe('Old name');
  });
});
