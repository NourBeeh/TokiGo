"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AdminService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const provider_registry_impl_1 = require("../../common/providers/provider.registry.impl");
const audit_log_entity_1 = require("../../database/entities/audit_log.entity");
const home_card_entity_1 = require("../../database/entities/home_card.entity");
const home_section_entity_1 = require("../../database/entities/home_section.entity");
const provider_entity_1 = require("../../database/entities/provider.entity");
const provider_instances_1 = require("../providers/provider.instances");
const registry_sync_service_1 = require("../providers/registry.sync.service");
/**
 * Admin content management for the Home marketplace feed.
 *
 * Every mutation is appended to the audit log (entity existed unused — this
 * wires it into a real flow). Drafts and scheduled content stay invisible to
 * the public feed: the visibility filter lives in HomeService.
 */
let AdminService = class AdminService {
    sections;
    cards;
    audit;
    providers;
    instances;
    sync;
    registry;
    constructor(sections, cards, audit, providers, instances, sync, registry) {
        this.sections = sections;
        this.cards = cards;
        this.audit = audit;
        this.providers = providers;
        this.instances = instances;
        this.sync = sync;
        this.registry = registry;
    }
    // ---------- Sections ----------
    async listSections() {
        const [sectionRows, cardRows] = await Promise.all([
            this.sections.find({ order: { order: 'ASC' } }),
            this.cards.find({ order: { order: 'ASC' } }),
        ]);
        return sectionRows.map((section) => ({
            ...section,
            cards: cardRows.filter((c) => c.sectionId === section.id),
        }));
    }
    async createSection(dto, userId) {
        const nextOrder = dto.order ?? (await this.maxOrder(this.sections, {})) + 1;
        const section = await this.sections.save(this.sections.create({
            title: dto.title,
            subtitle: dto.subtitle,
            layout: dto.layout,
            order: nextOrder,
            isVisible: dto.isVisible ?? true,
            status: dto.status ?? 'published',
            publishAt: toDate(dto.publishAt),
            expiresAt: toDate(dto.expiresAt),
        }));
        await this.log(userId, 'section.create', { sectionId: section.id });
        return section;
    }
    async updateSection(id, dto, userId) {
        const section = await this.sections.findOne({ where: { id } });
        if (!section)
            throw new common_1.NotFoundException('Section not found.');
        if (dto.title !== undefined)
            section.title = dto.title;
        if (dto.subtitle !== undefined)
            section.subtitle = dto.subtitle;
        if (dto.layout !== undefined)
            section.layout = dto.layout;
        if (dto.order !== undefined)
            section.order = dto.order;
        if (dto.isVisible !== undefined)
            section.isVisible = dto.isVisible;
        if (dto.status !== undefined)
            section.status = dto.status;
        if (dto.publishAt !== undefined)
            section.publishAt = toDate(dto.publishAt);
        if (dto.expiresAt !== undefined)
            section.expiresAt = toDate(dto.expiresAt);
        const saved = await this.sections.save(section);
        await this.log(userId, 'section.update', { sectionId: id, patch: dto });
        return saved;
    }
    async deleteSection(id, userId) {
        const section = await this.sections.findOne({ where: { id } });
        if (!section)
            throw new common_1.NotFoundException('Section not found.');
        // Cards are removed with their section: they have no meaning alone.
        await this.cards.delete({ sectionId: id });
        await this.sections.delete({ id });
        await this.log(userId, 'section.delete', { sectionId: id });
    }
    async reorderSections(dto, userId) {
        await this.reorder(this.sections, dto.ids);
        await this.log(userId, 'section.reorder', { ids: dto.ids });
    }
    // ---------- Cards ----------
    async createCard(dto, userId) {
        const section = await this.sections.findOne({ where: { id: dto.sectionId } });
        if (!section)
            throw new common_1.NotFoundException('Section not found.');
        const nextOrder = dto.order ??
            (await this.maxOrder(this.cards, { sectionId: dto.sectionId })) + 1;
        const card = await this.cards.save(this.cards.create({
            sectionId: dto.sectionId,
            cardType: dto.cardType,
            content: dto.content ?? {},
            order: nextOrder,
            isVisible: dto.isVisible ?? true,
            status: dto.status ?? 'published',
            publishAt: toDate(dto.publishAt),
            expiresAt: toDate(dto.expiresAt),
        }));
        await this.log(userId, 'card.create', {
            cardId: card.id,
            sectionId: dto.sectionId,
        });
        return card;
    }
    async updateCard(id, dto, userId) {
        const card = await this.cards.findOne({ where: { id } });
        if (!card)
            throw new common_1.NotFoundException('Card not found.');
        if (dto.cardType !== undefined)
            card.cardType = dto.cardType;
        if (dto.content !== undefined) {
            // Partial patch: admin sends only the edited fields, the rest survive.
            card.content = { ...(card.content ?? {}), ...dto.content };
        }
        if (dto.order !== undefined)
            card.order = dto.order;
        if (dto.isVisible !== undefined)
            card.isVisible = dto.isVisible;
        if (dto.status !== undefined)
            card.status = dto.status;
        if (dto.publishAt !== undefined)
            card.publishAt = toDate(dto.publishAt);
        if (dto.expiresAt !== undefined)
            card.expiresAt = toDate(dto.expiresAt);
        const saved = await this.cards.save(card);
        await this.log(userId, 'card.update', { cardId: id, patch: dto });
        return saved;
    }
    async deleteCard(id, userId) {
        const card = await this.cards.findOne({ where: { id } });
        if (!card)
            throw new common_1.NotFoundException('Card not found.');
        await this.cards.delete({ id });
        await this.log(userId, 'card.delete', { cardId: id });
    }
    async reorderCards(dto, userId) {
        await this.reorder(this.cards, dto.ids);
        await this.log(userId, 'card.reorder', { ids: dto.ids });
    }
    // ---------- Audit ----------
    async listAuditLogs(limit = 50) {
        const capped = Math.min(Math.max(limit, 1), 200);
        return this.audit.find({ order: { createdAt: 'DESC' }, take: capped });
    }
    // ---------- Helpers ----------
    async maxOrder(repo, where) {
        const rows = await repo.find({ where });
        return rows.reduce((max, row) => Math.max(max, row.order ?? 0), 0);
    }
    async reorder(repo, ids) {
        for (let index = 0; index < ids.length; index++) {
            await repo.update({ id: ids[index] }, { order: index + 1 });
        }
    }
    async log(userId, action, metadata) {
        try {
            await this.audit.save(this.audit.create({ userId, action, metadata }));
        }
        catch (_) {
            // Audit failures must never fail the admin operation itself.
        }
    }
    // ---------- Provider management (ADM-B1) ----------
    async listProviders() {
        return this.providers.find({
            order: { vertical: 'ASC', priority: 'ASC' },
        });
    }
    async setProviderStatus(key, isActive, userId) {
        const row = await this.providers.findOne({ where: { providerKey: key } });
        if (!row)
            throw new common_1.NotFoundException('Provider not found.');
        row.isActive = isActive;
        const saved = await this.providers.save(row);
        await this.sync.refresh();
        await this.log(userId, isActive ? 'provider.enable' : 'provider.disable', {
            providerKey: key,
        });
        return saved;
    }
    async setProviderPriority(key, priority, userId) {
        const row = await this.providers.findOne({ where: { providerKey: key } });
        if (!row)
            throw new common_1.NotFoundException('Provider not found.');
        row.priority = priority;
        const saved = await this.providers.save(row);
        await this.sync.refresh();
        await this.log(userId, 'provider.priority', {
            providerKey: key,
            priority,
        });
        return saved;
    }
    async setProviderConfig(key, config, userId) {
        const row = await this.providers.findOne({ where: { providerKey: key } });
        if (!row)
            throw new common_1.NotFoundException('Provider not found.');
        row.config = { ...(row.config ?? {}), ...config };
        const saved = await this.providers.save(row);
        await this.log(userId, 'provider.config', {
            providerKey: key,
            keys: Object.keys(config),
        });
        return saved;
    }
    /** Probes one provider and persists the outcome (status + latency). */
    async runHealthCheck(key, userId) {
        const row = await this.providers.findOne({ where: { providerKey: key } });
        if (!row)
            throw new common_1.NotFoundException('Provider not found.');
        const instance = this.instances.get(key);
        if (!instance)
            throw new common_1.NotFoundException('Provider instance not registered.');
        const started = Date.now();
        let healthy = false;
        try {
            await Promise.race([this.probe(instance), this.timeout(10_000)]);
            healthy = true;
        }
        catch (_) {
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
    async refreshRegistry(userId) {
        await this.sync.refresh();
        const counts = {
            flight: this.registry.getFlightProviders().length,
            hotel: this.registry.getHotelProviders().length,
            car: this.registry.getCarProviders().length,
        };
        await this.log(userId, 'provider.registry-refresh', counts);
        return counts;
    }
    async probe(instance) {
        const method = ['searchFlights', 'searchHotels', 'searchCars']
            .map((name) => instance[name])
            .find((fn) => typeof fn === 'function');
        if (!method)
            throw new Error('Provider exposes no search method.');
        await method.call(instance, {});
    }
    timeout(ms) {
        return new Promise((_, reject) => setTimeout(() => reject(new Error('Health check timed out.')), ms));
    }
};
exports.AdminService = AdminService;
exports.AdminService = AdminService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(home_section_entity_1.HomeSection)),
    __param(1, (0, typeorm_1.InjectRepository)(home_card_entity_1.HomeCard)),
    __param(2, (0, typeorm_1.InjectRepository)(audit_log_entity_1.AuditLog)),
    __param(3, (0, typeorm_1.InjectRepository)(provider_entity_1.Provider)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        provider_instances_1.ProviderInstances,
        registry_sync_service_1.RegistrySyncService,
        provider_registry_impl_1.ProviderRegistryImpl])
], AdminService);
function toDate(value) {
    return value === undefined ? undefined : new Date(value);
}
//# sourceMappingURL=admin.service.js.map