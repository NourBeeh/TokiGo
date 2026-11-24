import {
  boundingBox,
  centerKey,
  DEFAULT_RADIUS_STAGES_KM,
  haversineKm,
  initialRadiusKm,
  isValidCoordinate,
  radiusStagesKm,
  sevenOneNightWindows,
} from '../src/modules/nearby/geo';

describe('nearby geo helpers', () => {
  afterEach(() => {
    delete process.env.NEARBY_RADIUS_STAGES;
  });

  it('measures real great-circle distance', () => {
    expect(haversineKm(0, 0, 0, 0)).toBe(0);
    // One degree of longitude at the equator.
    expect(haversineKm(0, 0, 0, 1)).toBeCloseTo(111.19, 1);
    // Cairo → Alexandria is roughly 180 km.
    const km = haversineKm(30.0444, 31.2357, 31.2001, 29.9187);
    expect(km).toBeGreaterThan(150);
    expect(km).toBeLessThan(220);
  });

  it('rejects coordinates that cannot be a real position', () => {
    expect(isValidCoordinate(30.04, 31.23)).toBe(true);
    expect(isValidCoordinate(200, 31.23)).toBe(false);
    expect(isValidCoordinate(30.04, 400)).toBe(false);
    expect(isValidCoordinate(Number.NaN, 31.23)).toBe(false);
    expect(isValidCoordinate('30', 31)).toBe(false);
  });

  it('builds a bounding box that contains the center and covers the radius', () => {
    const box = boundingBox({ latitude: 30.0444, longitude: 31.2357 }, 5);
    expect(box.minLat).toBeLessThan(30.0444);
    expect(box.maxLat).toBeGreaterThan(30.0444);
    expect(box.minLng).toBeLessThan(31.2357);
    expect(box.maxLng).toBeGreaterThan(31.2357);
    // The latitude span is radius / 111.32, whichever way you measure it.
    expect(box.maxLat - box.minLat).toBeCloseTo(2 * (5 / 111.32), 4);
  });

  it('uses the suggested radius ladder and validates an override', () => {
    expect(DEFAULT_RADIUS_STAGES_KM).toEqual([5, 10, 20, 35, 50, 75]);
    expect(initialRadiusKm()).toBe(5);
    expect(radiusStagesKm()).toEqual([5, 10, 20, 35, 50, 75]);

    process.env.NEARBY_RADIUS_STAGES = '3,8,15';
    expect(radiusStagesKm()).toEqual([3, 8, 15]);

    process.env.NEARBY_RADIUS_STAGES = '15,8,3'; // not ascending
    expect(radiusStagesKm()).toEqual([5, 10, 20, 35, 50, 75]);

    process.env.NEARBY_RADIUS_STAGES = '0,5'; // invalid value
    expect(radiusStagesKm()).toEqual([5, 10, 20, 35, 50, 75]);

    // A market may narrow the ladder, but never search beyond the 75 km
    // product ceiling: the whole override is rejected.
    process.env.NEARBY_RADIUS_STAGES = '5,10,120';
    expect(radiusStagesKm()).toEqual([5, 10, 20, 35, 50, 75]);
    process.env.NEARBY_RADIUS_STAGES = '5,75';
    expect(radiusStagesKm()).toEqual([5, 75]);
  });

  it('produces exactly seven consecutive one-night windows', () => {
    const windows = sevenOneNightWindows('2026-03-01');
    expect(windows).toHaveLength(7);
    expect(windows[0]).toEqual({ checkIn: '2026-03-01', checkOut: '2026-03-02' });
    expect(windows[6]).toEqual({ checkIn: '2026-03-07', checkOut: '2026-03-08' });
    for (let index = 1; index < windows.length; index += 1) {
      expect(windows[index].checkIn).toBe(windows[index - 1].checkOut);
    }
  });

  it('handles month and year boundaries', () => {
    const windows = sevenOneNightWindows('2026-12-29');
    expect(windows[0].checkIn).toBe('2026-12-29');
    expect(windows[6].checkOut).toBe('2027-01-05');
  });

  it('resolves the start date in the requested timezone', () => {
    // 2026-03-08T03:00Z is still 2026-03-07 in New York (UTC-5).
    const windows = sevenOneNightWindows(new Date('2026-03-08T03:00:00Z'), 'America/New_York');
    expect(windows[0].checkIn).toBe('2026-03-07');
    // The DST jump (2026-03-08 in the US) must not skip or repeat a date.
    expect(windows.map((window) => window.checkIn)).toEqual([
      '2026-03-07',
      '2026-03-08',
      '2026-03-09',
      '2026-03-10',
      '2026-03-11',
      '2026-03-12',
      '2026-03-13',
    ]);
  });

  it('produces a stable center key', () => {
    expect(centerKey(30.04444, 31.23571)).toBe('30.0444,31.2357');
    expect(centerKey(30.04441, 31.23571)).toBe(centerKey(30.04444, 31.2357));
  });
});
