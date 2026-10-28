import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ProviderRegistryImpl } from '../../common/providers/provider.registry.impl';
import { AuditLog } from '../../database/entities/audit_log.entity';
import { HomeCard } from '../../database/entities/home_card.entity';
import { HomeSection } from '../../database/entities/home_section.entity';
import { Provider } from '../../database/entities/provider.entity';
import { ProviderInstances } from '../providers/provider.instances';
import { RegistrySyncService } from '../providers/registry.sync.service';
import {
  CreateCardDto,
  CreateSectionDto,
  ReorderDto,
  UpdateCardDto,
  UpdateSectionDto,
} from '../../common/dto/admin.dto';

/**
 * Admin content management for the Home marketplace feed.
 *
 * Every mutation is appended to the audit log (entity existed unused — this
 * wires it into a real flow). Drafts and scheduled content stay invisible to
 * the public feed: the visibility filter lives in HomeService.
 */
@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(HomeSection)
    private readonly sections: Repository<HomeSection>,
    @InjectRepository(HomeCard)
    private readonly cards: Repository<HomeCard>,
    @InjectRepository(AuditLog)
    private readonly audit: Repository<AuditLog>,
    @InjectRepository(Provider)
    private readonly providers: Repository<Provider>,
    private readonly instances: ProviderInstances,
    private readonly sync: RegistrySyncService,
    private readonly registry: ProviderRegistryImpl,
  ) {}

  // ---------- Sections ----------

  async listSections(): Promise<any[]> {
    const [sectionRows, cardRows] = await Promise.all([
      this.sections.find({ order: { order: 'ASC' } }),
      this.cards.find({ order: { order: 'ASC' } }),
    ]);
    return sectionRows.map((section) => ({
      ...section,
      cards: cardRows.filter((c) => c.sectionId === section.id),
    }));
  }

  async createSection(dto: CreateSectionDto, userId?: string): Promise<HomeSection> {
    const nextOrder =
      dto.order ?? (await this.maxOrder(this.sections, {})) + 1;
    const section = await this.sections.save(
      this.sections.create({
        title: dto.title,
        subtitle: dto.subtitle,
        layout: dto.layout,
        order: nextOrder,
        isVisible: dto.isVisible ?? true,
        status: dto.status ?? 'published',
        publishAt: toDate(dto.publishAt),
        expiresAt: toDate(dto.expiresAt),
      }),
    );
    await this.log(userId, 'section.create', { sectionId: section.id });
    return section;
  }

  async updateSection(
    id: string,
    dto: UpdateSectionDto,
    userId?: string,
  ): Promise<HomeSection> {
    const section = await this.sections.findOne({ where: { id } });
    if (!section) throw new NotFoundException('Section not found.');
    if (dto.title !== undefined) section.title = dto.title;
    if (dto.subtitle !== undefined) section.subtitle = dto.subtitle;
    if (dto.layout !== undefined) section.layout = dto.layout;
    if (dto.order !== undefined) section.order = dto.order;
    if (dto.isVisible !== undefined) section.isVisible = dto.isVisible;
    if (dto.status !== undefined) section.status = dto.status;
    if (dto.publishAt !== undefined) section.publishAt = toDate(dto.publishAt);
    if (dto.expiresAt !== undefined) section.expiresAt = toDate(dto.expiresAt);
    const saved = await this.sections.save(section);
    await this.log(userId, 'section.update', { sectionId: id, patch: dto });
    return saved;
  }

  async deleteSection(id: string, userId?: string): Promise<void> {
    const section = await this.sections.findOne({ where: { id } });
    if (!section) throw new NotFoundException('Section not found.');
    // Cards are removed with their section: they have no meaning alone.
    await this.cards.delete({ sectionId: id });
    await this.sections.delete({ id });
    await this.log(userId, 'section.delete', { sectionId: id });
  }

  async reorderSections(dto: ReorderDto, userId?: string): Promise<void> {
    await this.reorder(this.sections, dto.ids);
    await this.log(userId, 'section.reorder', { ids: dto.ids });
  }

  // ---------- Cards ----------

  async createCard(dto: CreateCardDto, userId?: string): Promise<HomeCard> {
    const section = await this.sections.findOne({ where: { id: dto.sectionId } });
    if (!section) throw new NotFoundException('Section not found.');
    const nextOrder =
      dto.order ??
      (await this.maxOrder(this.cards, { sectionId: dto.sectionId })) + 1;
    const card = await this.cards.save(
      this.cards.create({
        sectionId: dto.sectionId,
        cardType: dto.cardType,
        content: dto.content ?? {},
        order: nextOrder,
        isVisible: dto.isVisible ?? true,
        status: dto.status ?? 'published',
        publishAt: toDate(dto.publishAt),
        expiresAt: toDate(dto.expiresAt),
      }),
    );
    await this.log(userId, 'card.create', {
      cardId: card.id,
      sectionId: dto.sectionId,
    });
    return card;
  }

  async updateCard(id: string, dto: UpdateCardDto, userId?: string): Promise<HomeCard> {
    const card = await this.cards.findOne({ where: { id } });
    if (!card) throw new NotFoundException('Card not found.');
    if (dto.cardType !== undefined) card.cardType = dto.cardType;
    if (dto.content !== undefined) {
      // Partial patch: admin sends only the edited fields, the rest survive.
      card.content = { ...(card.content ?? {}), ...dto.content };
    }
    if (dto.order !== undefined) card.order = dto.order;
    if (dto.isVisible !== undefined) card.isVisible = dto.isVisible;
    if (dto.status !== undefined) card.status = dto.status;
    if (dto.publishAt !== undefined) card.publishAt = toDate(dto.publishAt);
    if (dto.expiresAt !== undefined) card.expiresAt = toDate(dto.expiresAt);
    const saved = await this.cards.save(card);
    await this.log(userId, 'card.update', { cardId: id, patch: dto });
    return saved;
  }

  async deleteCard(id: string, userId?: string): Promise<void> {
    const card = await this.cards.findOne({ where: { id } });
    if (!card) throw new NotFoundException('Card not found.');
    await this.cards.delete({ id });
    await this.log(userId, 'card.delete', { cardId: id });
  }

  async reorderCards(dto: ReorderDto, userId?: string): Promise<void> {
    await this.reorder(this.cards, dto.ids);
    await this.log(userId, 'card.reorder', { ids: dto.ids });
  }

  // ---------- Audit ----------

  async listAuditLogs(limit = 50): Promise<AuditLog[]> {
    const capped = Math.min(Math.max(limit, 1), 200);
    return this.audit.find({ order: { createdAt: 'DESC' }, take: capped });
  }

  // ---------- Helpers ----------

  private async maxOrder(
    repo: Repository<HomeSection> | Repository<HomeCard>,
    where: Record<string, any>,
  ): Promise<number> {
    const rows = await repo.find({ where });
    return rows.reduce((max, row) => Math.max(max, row.order ?? 0), 0);
  }

  private async reorder(
    repo: Repository<HomeSection> | Repository<HomeCard>,
    ids: string[],
  ): Promise<void> {
    for (let index = 0; index < ids.length; index++) {
      await repo.update({ id: ids[index] }, { order: index + 1 });
    }
  }

  private async log(
    userId: string | undefined,
    action: string,
    metadata?: Record<string, any>,
  ): Promise<void> {
    try {
      await this.audit.save(
        this.audit.create({ userId, action, metadata }),
      );
    } catch (_) {
      // Audit failures must never fail the admin operation itself.
    }
  }

  // ---------- Provider management (ADM-B1) ----------

  async listProviders(): Promise<Provider[]> {
    return this.providers.find({
      order: { vertical: 'ASC', priority: 'ASC' },
    });
  }

  async setProviderStatus(
    key: string,
    isActive: boolean,
    userId?: string,
  ): Promise<Provider> {
    const row = await this.providers.findOne({ where: { providerKey: key } });
    if (!row) throw new NotFoundException('Provider not found.');
    row.isActive = isActive;
    const saved = await this.providers.save(row);
    await this.sync.refresh();
    await this.log(userId, isActive ? 'provider.enable' : 'provider.disable', {
      providerKey: key,
    });
    return saved;
  }

  async setProviderPriority(
    key: string,
    priority: number,
    userId?: string,
  ): Promise<Provider> {
    const row = await this.providers.findOne({ where: { providerKey: key } });
    if (!row) throw new NotFoundException('Provider not found.');
    row.priority = priority;
    const saved = await this.providers.save(row);
    await this.sync.refresh();
    await this.log(userId, 'provider.priority', {
      providerKey: key,
      priority,
    });
    return saved;
  }

  async setProviderConfig(
    key: string,
    config: Record<string, any>,
    userId?: string,
  ): Promise<Provider> {
    const row = await this.providers.findOne({ where: { providerKey: key } });
    if (!row) throw new NotFoundException('Provider not found.');
    row.config = { ...(row.config ?? {}), ...config };
    const saved = await this.providers.save(row);
    await this.log(userId, 'provider.config', {
      providerKey: key,
      keys: Object.keys(config),
    });
    return saved;
  }

  /** Probes one provider and persists the outcome (status + latency). */
  async runHealthCheck(key: string, userId?: string): Promise<Provider> {
    const row = await this.providers.findOne({ where: { providerKey: key } });
    if (!row) throw new NotFoundException('Provider not found.');
    const instance = this.instances.get(key);
    if (!instance) throw new NotFoundException('Provider instance not registered.');

    const started = Date.now();
    let healthy = false;
    try {
      await Promise.race([this.probe(instance), this.timeout(10_000)]);
      healthy = true;
    } catch (_) {
      healthy = false;
    }
    row.healthStatus = healthy ? 'healthy' : 'unhealthy';
    row.latencyMs = Date.now() - started;
    row.lastCheckedAt = new Date();
    const saved = await this.providers.save(row);
    await this.log(userId, 'provider.health-check', {
      providerKey: key,
      healthStatus: saved.healthStatus,
      latencyMs: saved.latencyMs,
    });
    return saved;
  }

  async refreshRegistry(userId?: string): Promise<{ flight: number; hotel: number; car: number }> {
    await this.sync.refresh();
    const counts = {
      flight: this.registry.getFlightProviders().length,
      hotel: this.registry.getHotelProviders().length,
      car: this.registry.getCarProviders().length,
    };
    await this.log(userId, 'provider.registry-refresh', counts);
    return counts;
  }

  private async probe(instance: any): Promise<void> {
    const method = ['searchFlights', 'searchHotels', 'searchCars']
      .map((name) => instance[name])
      .find((fn) => typeof fn === 'function');
    if (!method) throw new Error('Provider exposes no search method.');
    await method.call(instance, {});
  }

  private timeout(ms: number): Promise<never> {
    return new Promise((_, reject) =>
      setTimeout(() => reject(new Error('Health check timed out.')), ms),
    );
  }
}

function toDate(value?: string): Date | undefined {
  return value === undefined ? undefined : new Date(value);
}
