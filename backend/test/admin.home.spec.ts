import { NotFoundException } from '@nestjs/common';
import { In } from 'typeorm';
import { ProviderRegistryImpl } from '../src/common/providers/provider.registry.impl';
import { RolesGuard } from '../src/common/guards/roles.guard';
import { AdminService } from '../src/modules/admin/admin.service';
import { ProviderInstances } from '../src/modules/providers/provider.instances';
import { RegistrySyncService } from '../src/modules/providers/registry.sync.service';
import { HomeService } from '../src/modules/home/home.service';

/* ------------------------------------------------------------------ *
 * Minimal TypeORM repository double: find/findOne/create/save/update/
 * delete over an in-memory row array — enough for AdminService flows.
 * ------------------------------------------------------------------ */
function fakeRepo(initial: any[] = []) {
  const rows: any[] = [...initial];
  const matches = (row: any, where: any) =>
    Object.keys(where).every((key) => {
      const expected = where[key];
      // TypeORM In(...) operator support (used by the home feed query).
      if (expected && typeof expected === 'object' && Array.isArray(expected.value)) {
        return expected.value.includes(row[key]);
      }
      return row[key] === expected;
    });
  return {
    rows,
    async find(opts?: any) {
      let out = rows.filter((r) => matches(r, opts?.where ?? {}));
      const order = opts?.order ?? {};
      for (const key of Object.keys(order).reverse()) {
        const dir = order[key];
        out = [...out].sort((a, b) =>
          dir === 'DESC' ? (b[key] > a[key] ? 1 : -1) : a[key] > b[key] ? 1 : -1,
        );
      }
      const take = opts?.take;
      return take === undefined ? out : out.slice(0, take);
    },
    async findOne(opts?: any) {
      return rows.find((r) => matches(r, opts?.where ?? {})) ?? null;
    },
    create(value: any) {
      return { ...value };
    },
    async save(value: any) {
      const index = rows.findIndex((r) => r.id === value.id);
      if (index >= 0) {
        rows[index] = { ...rows[index], ...value };
        return rows[index];
      }
      const created = {
        id: value.id ?? `gen-${rows.length + 1}`,
        ...value,
      };
      rows.push(created);
      return created;
    },
    async update(where: any, patch: any) {
      rows.filter((r) => matches(r, where)).forEach((r) => Object.assign(r, patch));
    },
    async delete(where: any) {
      for (let i = rows.length - 1; i >= 0; i--) {
        if (matches(rows[i], where)) rows.splice(i, 1);
      }
    },
  } as any;
}

function makeService() {
  const sections = fakeRepo();
  const cards = fakeRepo();
  const audit = fakeRepo();
  const providers = fakeRepo();
  const instances = new ProviderInstances();
  const registry = new ProviderRegistryImpl();
  const sync = new RegistrySyncService(providers, registry, instances);
  const service = new AdminService(
    sections,
    cards,
    audit,
    providers,
    instances,
    sync,
    registry,
  );
  return { service, sections, cards, audit, providers, instances, registry, sync };
}

/* ------------------------------------------------------------------ */

describe('AdminService — home content management', () => {
  it('creates a section with auto order and published default', async () => {
    const { service, sections } = makeService();
    const created = await service.createSection({
      title: 'Recommended',
      layout: 'horizontal',
    });
    expect(created.order).toBe(1);
    expect(created.status).toBe('published');
    expect(created.isVisible).toBe(true);
    expect(sections.rows).toHaveLength(1);
  });

  it('honours draft status and explicit schedule on create', async () => {
    const { service } = makeService();
    const created = await service.createSection({
      title: 'Ramadan deals',
      layout: 'grid',
      status: 'draft',
      publishAt: '2026-10-01T00:00:00.000Z',
    });
    expect(created.status).toBe('draft');
    expect(created.publishAt).toBeInstanceOf(Date);
  });

  it('auto-increments card order within its section and rejects unknown sections', async () => {
    const { service, cards } = makeService();
    const section = await service.createSection({ title: 'Hotels', layout: 'grid' });
    await service.createCard({ sectionId: section.id, cardType: 'hotel', content: { title: 'A' } });
    const second = await service.createCard({
      sectionId: section.id,
      cardType: 'hotel',
      content: { title: 'B' },
    });
    expect(second.order).toBe(2);
    expect(cards.rows).toHaveLength(2);

    await expect(
      service.createCard({ sectionId: 'missing', cardType: 'deal', content: {} }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('merges card content patches instead of replacing them', async () => {
    const { service } = makeService();
    const section = await service.createSection({ title: 'Deals', layout: 'horizontal' });
    const card = await service.createCard({
      sectionId: section.id,
      cardType: 'deal',
      content: { title: 'Old', price: 100, currency: 'EGP' },
    });
    const updated = await service.updateCard(card.id, { content: { price: 250 } });
    expect(updated.content.title).toBe('Old');
    expect(updated.content.currency).toBe('EGP');
    expect(updated.content.price).toBe(250);
  });

  it('deletes a section together with its cards', async () => {
    const { service, sections, cards } = makeService();
    const section = await service.createSection({ title: 'Gone', layout: 'grid' });
    const card = await service.createCard({
      sectionId: section.id,
      cardType: 'car',
      content: { title: 'Car' },
    });
    await service.deleteSection(section.id);
    expect(sections.rows).toHaveLength(0);
    expect(cards.rows.find((c) => c.id === card.id)).toBeUndefined();
  });

  it('reorders sections by list index', async () => {
    const { service, sections } = makeService();
    const a = await service.createSection({ title: 'A', layout: 'grid' });
    const b = await service.createSection({ title: 'B', layout: 'grid' });
    await service.reorderSections({ ids: [b.id, a.id] });
    expect(sections.rows.find((s) => s.id === b.id)?.order).toBe(1);
    expect(sections.rows.find((s) => s.id === a.id)?.order).toBe(2);
  });

  it('groups cards under their section in listSections and appends audit entries', async () => {
    const { service, audit } = makeService();
    const section = await service.createSection({ title: 'Flights', layout: 'horizontal' });
    await service.createCard({
      sectionId: section.id,
      cardType: 'flight',
      content: { title: 'CAI → DXB' },
    });
    const listed = await service.listSections();
    expect(listed).toHaveLength(1);
    expect(listed[0].cards).toHaveLength(1);
    expect(listed[0].cards[0].content.title).toBe('CAI → DXB');
    expect(audit.rows.length).toBeGreaterThanOrEqual(2);
  });

  it('caps audit log reads', async () => {
    const { service, audit } = makeService();
    for (let i = 0; i < 5; i++) {
      await service.createSection({ title: `S${i}`, layout: 'grid' });
    }
    const logs = await service.listAuditLogs(3);
    expect(logs).toHaveLength(3);
    expect(audit.rows.length).toBe(5);
  });
});

/* ------------------------------------------------------------------ */

describe('RolesGuard — admin gate', () => {
  function contextWith(user: any, roles?: string[]) {
    const reflector = {
      getAllAndOverride: (_key: string, _mods: any[]) => roles,
    } as any;
    const guard = new RolesGuard(reflector);
    return guard.canActivate({
      switchToHttp: () => ({ getRequest: () => ({ user }) }),
      getHandler: () => null,
      getClass: () => null,
    } as any);
  }

  it('passes users carrying an allowed role', () => {
    expect(contextWith({ role: 'admin' }, ['admin'])).toBe(true);
  });

  it('blocks non-admin users on admin routes', () => {
    expect(() => contextWith({ role: 'user' }, ['admin'])).toThrow();
    expect(() => contextWith(undefined, ['admin'])).toThrow();
  });

  it('passes through routes without role metadata', () => {
    expect(contextWith(undefined, undefined)).toBe(true);
  });
});

/* ------------------------------------------------------------------ */

describe('HomeService — publication window (ADM-B1)', () => {
  function homeService(sectionRepo: any, cardRepo: any) {
    return new HomeService(sectionRepo, cardRepo);
  }

  const liveSection = {
    id: 's-live',
    title: 'Live',
    layout: 'horizontal',
    order: 1,
    isVisible: true,
    status: 'published',
  };

  it('hides draft sections from the public feed', async () => {
    const sections = fakeRepo([
      liveSection,
      { ...liveSection, id: 's-draft', title: 'Draft', status: 'draft' },
    ] as any);
    const cards = fakeRepo() as any;
    const result = await homeService(sections, cards).getSections();
    expect(result.map((s) => s.id)).toEqual(['s-live']);
  });

  it('hides sections whose publishAt is in the future', async () => {
    const sections = fakeRepo([
      liveSection,
      {
        ...liveSection,
        id: 's-future',
        title: 'Scheduled',
        publishAt: new Date(Date.now() + 86_400_000),
      },
    ] as any);
    const result = await homeService(sections, fakeRepo() as any).getSections();
    expect(result.map((s) => s.id)).toEqual(['s-live']);
  });

  it('hides expired sections and expired cards', async () => {
    const sections = fakeRepo([
      liveSection,
      {
        ...liveSection,
        id: 's-expired',
        title: 'Expired',
        expiresAt: new Date(Date.now() - 1000),
      },
    ] as any);
    const cards = fakeRepo([
      {
        id: 'c-live',
        sectionId: 's-live',
        cardType: 'hotel',
        order: 1,
        isVisible: true,
        content: { title: 'Hotel' },
      },
      {
        id: 'c-expired',
        sectionId: 's-live',
        cardType: 'hotel',
        order: 2,
        isVisible: true,
        expiresAt: new Date(Date.now() - 1000),
        content: { title: 'Old hotel' },
      },
    ] as any);
    const result = await homeService(sections, cards).getSections();
    expect(result).toHaveLength(1);
    expect(result[0].cards.map((c) => c.id)).toEqual(['c-live']);
  });

  it('treats legacy rows without status/publishAt as live', async () => {
    const sections = fakeRepo([
      {
        id: 's-legacy',
        title: 'Legacy',
        layout: 'grid',
        order: 1,
        isVisible: true,
      },
    ] as any);
    const result = await homeService(sections, fakeRepo() as any).getSections();
    expect(result).toHaveLength(1);
  });
});
