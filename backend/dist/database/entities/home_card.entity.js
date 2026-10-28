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
Object.defineProperty(exports, "__esModule", { value: true });
exports.HomeCard = void 0;
const typeorm_1 = require("typeorm");
let HomeCard = class HomeCard {
    id;
    sectionId;
    cardType;
    content;
    order;
    isVisible;
    expiresAt;
    /** Publication time: the public feed hides the card until then. */
    publishAt;
    /** Content lifecycle: drafts never reach the public home feed. */
    status;
    createdAt;
    updatedAt;
};
exports.HomeCard = HomeCard;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], HomeCard.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], HomeCard.prototype, "sectionId", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], HomeCard.prototype, "cardType", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb' }),
    __metadata("design:type", Object)
], HomeCard.prototype, "content", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int' }),
    __metadata("design:type", Number)
], HomeCard.prototype, "order", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: true }),
    __metadata("design:type", Boolean)
], HomeCard.prototype, "isVisible", void 0);
__decorate([
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", Date)
], HomeCard.prototype, "expiresAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz', nullable: true }),
    __metadata("design:type", Date)
], HomeCard.prototype, "publishAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: 'published' }),
    __metadata("design:type", String)
], HomeCard.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], HomeCard.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)(),
    __metadata("design:type", Date)
], HomeCard.prototype, "updatedAt", void 0);
exports.HomeCard = HomeCard = __decorate([
    (0, typeorm_1.Entity)('home_cards')
], HomeCard);
//# sourceMappingURL=home_card.entity.js.map