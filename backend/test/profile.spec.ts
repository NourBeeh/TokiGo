import { NotFoundException } from '@nestjs/common';
import { ProfileService } from '../src/modules/profile/profile.service';

function fakeProfileRepo(initial: any[] = []) {
  const rows = [...initial];
  return {
    rows,
    async findOne(opts: any) {
      return rows.find((r) => r.userId === opts.where.userId) ?? null;
    },
    async find(opts: any) {
      return rows.filter((r) => r.countryCode === opts.where.countryCode);
    },
    create(value: any) {
      return { id: 'profile-1', preferences: {}, derived: {}, personalizationEnabled: true, ...value };
    },
    async save(value: any) {
      const idx = rows.findIndex((r) => r.id === value.id || r.userId === value.userId);
      if (idx >= 0) {
        rows[idx] = { ...rows[idx], ...value };
        return rows[idx];
      }
      rows.push(value);
      return value;
    },
  } as any;
}

describe('ProfileService — user profile for personalization', () => {
  it('creates a default profile on first access', async () => {
    const repo = fakeProfileRepo();
    const service = new ProfileService(repo);
    const view = await service.getView('user-1');
    expect(view.userId).toBe('user-1');
    expect(view.preferences).toEqual({});
    expect(view.personalizationEnabled).toBe(true);
    expect(repo.rows).toHaveLength(1);
  });

  it('merges explicit preference patches instead of replacing', async () => {
    const repo = fakeProfileRepo();
    const service = new ProfileService(repo);
    await service.updatePreferences('user-1', {
      preferences: { budgetMax: 300, preferredStars: 4 },
    });
    const updated = await service.updatePreferences('user-1', {
      preferences: { amenities: ['pool'] },
    });
    expect(updated.preferences).toEqual({
      budgetMax: 300,
      preferredStars: 4,
      amenities: ['pool'],
    });
  });

  it('respects the personalization opt-out', async () => {
    const repo = fakeProfileRepo();
    const service = new ProfileService(repo);
    const view = await service.updatePreferences('user-1', {
      personalizationEnabled: false,
    });
    expect(view.personalizationEnabled).toBe(false);
  });

  it('stores derived signals for the recommendation engine', async () => {
    const repo = fakeProfileRepo();
    const service = new ProfileService(repo);
    await service.updateDerived('user-1', { topDestinations: ['Cairo', 'Dubai'] });
    await service.updateDerived('user-1', { avgPriceBand: 250 });
    const view = await service.getView('user-1');
    expect(view.derived).toEqual({ topDestinations: ['Cairo', 'Dubai'], avgPriceBand: 250 });
  });

  it('keeps the higher-confidence country detection', async () => {
    const repo = fakeProfileRepo();
    const service = new ProfileService(repo);
    await service.setCountryIfMoreConfident('user-1', 'US', 'low');
    await service.setCountryIfMoreConfident('user-1', 'EG', 'high');
    const view = await service.getView('user-1');
    expect(view.countryCode).toBe('EG');
    expect(view.countryConfidence).toBe('high');
    // A later low-confidence value must not downgrade.
    await service.setCountryIfMoreConfident('user-1', 'FR', 'low');
    const view2 = await service.getView('user-1');
    expect(view2.countryCode).toBe('EG');
  });

  it('finds profiles by country', async () => {
    const repo = fakeProfileRepo([
      { id: 'p1', userId: 'u1', countryCode: 'EG', preferences: {}, derived: {} },
      { id: 'p2', userId: 'u2', countryCode: 'EG', preferences: {}, derived: {} },
    ]);
    const service = new ProfileService(repo);
    const found = await service.findByCountry('EG');
    expect(found).toHaveLength(2);
  });
});
