import { EventsService } from '../src/modules/events/events.service';
import { ProfileService } from '../src/modules/profile/profile.service';

function fakeEventsRepo() {
  const rows: any[] = [];
  return {
    rows,
    async find(opts: any) {
      let out = rows.filter((r) =>
        Object.keys(opts.where ?? {}).every((k) => r[k] === opts.where[k]),
      );
      out = [...out].sort((a, b) =>
        a.createdAt > b.createdAt ? -1 : 1
      );
      return opts.take ? out.slice(0, opts.take) : out;
    },
    create(value: any) {
      return value;
    },
    async save(value: any) {
      const row = {
        id: `e-${rows.length + 1}`,
        createdAt: new Date(),
        ...value,
      };
      rows.push(row);
      return row;
    },
  } as any;
}

function fakeProfileRepo() {
  const profiles = new Map<string, any>();
  return {
    async findOne(opts: any) {
      return profiles.get(opts.where.userId) ?? null;
    },
    async find() {
      return [];
    },
    create(value: any) {
      return { id: 'p-1', preferences: {}, derived: {}, personalizationEnabled: true, ...value };
    },
    async save(value: any) {
      profiles.set(value.userId, value);
      return value;
    },
  } as any;
}

function makeDeps() {
  const events = fakeEventsRepo();
  const profileRepo = fakeProfileRepo();
  const profiles = new ProfileService(profileRepo);
  const service = new EventsService(events, profiles);
  return { service, events, profiles, profileRepo };
}

describe('EventsService — behavioural signals', () => {
  it('records a signed-in user event', async () => {
    const { service, events } = makeDeps();
    await service.track({ userId: 'u1', type: 'hotel_search', payload: { destination: 'Cairo' } });
    expect(events.rows).toHaveLength(1);
    expect(events.rows[0].userId).toBe('u1');
  });

  it('records an anonymous device event without userId', async () => {
    const { service, events } = makeDeps();
    await service.track({ deviceId: 'dev-1', type: 'hotel_view', payload: { hotelId: 'h1' } });
    expect(events.rows[0].userId).toBeUndefined();
    expect(events.rows[0].deviceId).toBe('dev-1');
  });

  it('accumulates top destinations in the derived profile', async () => {
    const { service, profiles } = makeDeps();
    await service.track({ userId: 'u1', type: 'hotel_search', payload: { destination: 'Dubai' } });
    await service.track({ userId: 'u1', type: 'hotel_search', payload: { destination: 'Cairo' } });
    await service.track({ userId: 'u1', type: 'hotel_search', payload: { destination: 'Dubai' } });
    const profile = await profiles.getView('u1');
    expect(profile.derived.topDestinations).toEqual(['Dubai', 'Cairo']);
  });

  it('records favorite hotels and budget from search payload', async () => {
    const { service, profiles } = makeDeps();
    await service.track({
      userId: 'u1',
      type: 'hotel_search',
      payload: { destination: 'Rome', minPrice: 50, maxPrice: 200 },
    });
    await service.track({ userId: 'u1', type: 'hotel_favorite', payload: { hotelId: 'h-rome' } });
    const profile = await profiles.getView('u1');
    expect(profile.derived.budget).toMatchObject({ min: 50, max: 200 });
    expect(profile.derived.favoriteHotels).toContain('h-rome');
  });

  it('stores the upcoming destination on a planned trip', async () => {
    const { service, profiles } = makeDeps();
    await service.track({ userId: 'u1', type: 'trip_planned', payload: { destination: 'Jeddah' } });
    const profile = await profiles.getView('u1');
    expect(profile.derived.upcomingDestination).toBe('Jeddah');
  });

  it('returns recent events newest-first with a cap', async () => {
    const { service } = makeDeps();
    for (let i = 0; i < 5; i++) {
      await service.track({ userId: 'u1', type: 'hotel_view', payload: { hotelId: `h${i}` } });
    }
    const recent = await service.recent('u1', 2);
    expect(recent).toHaveLength(2);
  });
});
