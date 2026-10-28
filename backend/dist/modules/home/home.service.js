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
exports.HomeService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const home_card_entity_1 = require("../../database/entities/home_card.entity");
const home_section_entity_1 = require("../../database/entities/home_section.entity");
/**
 * Reads the home feed from the persisted entities.
 *
 * Persistence and wire shapes deliberately differ, and this service is the
 * single translation point between them:
 *
 * - `HomeSection` / `HomeCard` name their flags `isVisible` / `expiresAt`,
 *   while the client reads `visibility` / `expiration`.
 * - `HomeCard` keeps every presentation field inside its `content` jsonb column
 *   and its kind in `cardType`; the client expects them flattened, with the
 *   kind under `type`.
 * - `home_cards.sectionId` is a plain column, not a TypeORM relation, so the
 *   cards cannot be eager-loaded with `relations: ['cards']`.
 *
 * The emitted keys are exactly the ones `HomeRepositoryImpl.getHomeSections`
 * parses on the Flutter side, so the HTTP contract is unchanged.
 */
let HomeService = class HomeService {
    sectionRepo;
    cardRepo;
    constructor(sectionRepo, cardRepo) {
        this.sectionRepo = sectionRepo;
        this.cardRepo = cardRepo;
    }
    async getSections() {
        const sections = await this.sectionRepo.find({
            where: { isVisible: true },
            order: { order: 'ASC' },
        });
        // Admin workstream (ADM-B1): drafts, not-yet-published and expired
        // content never reach the public feed. Undefined fields (legacy rows,
        // tests) are treated as published.
        const now = new Date();
        const liveSections = sections.filter((section) => isLive(section, now));
        if (liveSections.length === 0) {
            return [];
        }
        // One extra query plus in-memory grouping, because `sectionId` is a column
        // rather than a relation. Ordering is explicit: without it Postgres gives
        // no row order guarantee, and both entities carry an `order` column.
        const cards = await this.cardRepo.find({
            where: {
                sectionId: (0, typeorm_2.In)(liveSections.map((section) => section.id)),
                isVisible: true,
            },
            order: { order: 'ASC' },
        });
        const cardsBySection = new Map();
        for (const card of cards) {
            if (!isLive(card, now))
                continue;
            const bucket = cardsBySection.get(card.sectionId);
            if (bucket === undefined) {
                cardsBySection.set(card.sectionId, [card]);
            }
            else {
                bucket.push(card);
            }
        }
        return liveSections.map((section) => ({
            id: section.id,
            title: section.title,
            subtitle: section.subtitle,
            layout: section.layout,
            cards: (cardsBySection.get(section.id) ?? []).map((card) => flattenCard(card)),
            visibility: section.isVisible,
            expiration: section.expiresAt,
        }));
    }
    async refresh() {
        // Invalidate cache
        return { refreshed: true };
    }
};
exports.HomeService = HomeService;
exports.HomeService = HomeService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(home_section_entity_1.HomeSection)),
    __param(1, (0, typeorm_1.InjectRepository)(home_card_entity_1.HomeCard)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository])
], HomeService);
/**
 * Flattens one persisted card into the client shape.
 *
 * `content` is jsonb, so its keys are untyped at compile time and absent keys
 * simply become `undefined` and drop out of the JSON response — which is what
 * the client already treats as "field not provided".
 */
/**
 * Publication window check shared by sections and cards: `status` must not be
 * a draft, `publishAt` (when set) must have passed, and `expiresAt` (when set)
 * must still be in the future.
 */
function isLive(row, now) {
    if (row.status === 'draft')
        return false;
    if (row.publishAt && row.publishAt.getTime() > now.getTime())
        return false;
    if (row.expiresAt && row.expiresAt.getTime() <= now.getTime())
        return false;
    return true;
}
function flattenCard(card) {
    const content = card.content ?? {};
    const action = content.actionLabel ?? content.action;
    return {
        id: card.id,
        type: card.cardType,
        title: asString(content.title),
        subtitle: asString(content.subtitle),
        description: asString(content.description),
        imageUrl: asString(content.imageUrl),
        price: asNumber(content.price),
        currency: asString(content.currency),
        rating: asNumber(content.rating),
        reviewCount: asNumber(content.reviewCount),
        badge: asString(content.badge),
        highlights: asStringArray(content.highlights),
        tags: asStringArray(content.tags),
        // Accept the persisted legacy `actionLabel` key, but expose both supported
        // wire aliases so existing Flutter clients receive the same label.
        action: typeof action === 'string' ? action : undefined,
        actionLabel: typeof action === 'string' ? action : undefined,
        rawPrice: asNumber(content.rawPrice),
        metadata: asRecord(content.metadata),
        expiration: card.expiresAt,
        visibility: card.isVisible,
    };
}
function asString(value) {
    return typeof value === 'string' ? value : undefined;
}
function asNumber(value) {
    return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}
function asStringArray(value) {
    return Array.isArray(value) && value.every((item) => typeof item === 'string')
        ? value
        : undefined;
}
function asRecord(value) {
    return value !== null && typeof value === 'object' && !Array.isArray(value)
        ? value
        : undefined;
}
//# sourceMappingURL=home.service.js.map