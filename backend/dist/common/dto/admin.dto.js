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
exports.UpdateProviderConfigDto = exports.UpdateProviderPriorityDto = exports.UpdateProviderStatusDto = exports.ReorderDto = exports.UpdateCardDto = exports.CreateCardDto = exports.UpdateSectionDto = exports.CreateSectionDto = exports.CONTENT_STATUSES = exports.CARD_TYPES = exports.SECTION_LAYOUTS = void 0;
const class_validator_1 = require("class-validator");
const travel_mood_1 = require("../travel_mood");
function hasValidDestinationMoods(value, required) {
    if (value === null || typeof value !== 'object' || Array.isArray(value)) {
        return false;
    }
    const content = value;
    if (content.metadata === undefined)
        return !required;
    if (content.metadata === null ||
        typeof content.metadata !== 'object' ||
        Array.isArray(content.metadata)) {
        return false;
    }
    const moods = content.metadata.moods;
    if (moods === undefined)
        return !required;
    return (Array.isArray(moods) &&
        moods.length > 0 &&
        moods.length <= travel_mood_1.TRAVEL_MOODS.length &&
        new Set(moods).size === moods.length &&
        moods.every((mood) => typeof mood === 'string' &&
            travel_mood_1.TRAVEL_MOODS.includes(mood)));
}
let CreateDestinationMoodsConstraint = class CreateDestinationMoodsConstraint {
    validate(value, args) {
        const cardType = args.object.cardType;
        return hasValidDestinationMoods(value, cardType === 'destination');
    }
    defaultMessage() {
        return `Destination moods must be a non-empty unique array of: ${travel_mood_1.TRAVEL_MOODS.join(', ')}.`;
    }
};
CreateDestinationMoodsConstraint = __decorate([
    (0, class_validator_1.ValidatorConstraint)({ name: 'createDestinationMoods', async: false })
], CreateDestinationMoodsConstraint);
let ValidDestinationMoodsConstraint = class ValidDestinationMoodsConstraint {
    validate(value) {
        return hasValidDestinationMoods(value, false);
    }
    defaultMessage() {
        return `Moods must be a non-empty unique array of: ${travel_mood_1.TRAVEL_MOODS.join(', ')}.`;
    }
};
ValidDestinationMoodsConstraint = __decorate([
    (0, class_validator_1.ValidatorConstraint)({ name: 'validDestinationMoods', async: false })
], ValidDestinationMoodsConstraint);
/** Section layouts exactly as the Flutter Home repository parses them. */
exports.SECTION_LAYOUTS = [
    'horizontal',
    'horizontalpeek',
    'grid',
    'vertical',
];
/** Card types exactly as HomeCardType on the Flutter side. */
exports.CARD_TYPES = [
    'flight',
    'hotel',
    'car',
    'package',
    'destination',
    'deal',
];
/** Content lifecycle: drafts stay invisible to the public home feed. */
exports.CONTENT_STATUSES = ['draft', 'published'];
class CreateSectionDto {
    title;
    subtitle;
    layout;
    order;
    isVisible;
    status;
    /** Publication time: the public feed hides the section until then. */
    publishAt;
    expiresAt;
}
exports.CreateSectionDto = CreateSectionDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    (0, class_validator_1.MaxLength)(120),
    __metadata("design:type", String)
], CreateSectionDto.prototype, "title", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(200),
    __metadata("design:type", String)
], CreateSectionDto.prototype, "subtitle", void 0);
__decorate([
    (0, class_validator_1.IsIn)(exports.SECTION_LAYOUTS),
    __metadata("design:type", String)
], CreateSectionDto.prototype, "layout", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], CreateSectionDto.prototype, "order", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], CreateSectionDto.prototype, "isVisible", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(exports.CONTENT_STATUSES),
    __metadata("design:type", String)
], CreateSectionDto.prototype, "status", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], CreateSectionDto.prototype, "publishAt", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], CreateSectionDto.prototype, "expiresAt", void 0);
class UpdateSectionDto {
    title;
    subtitle;
    layout;
    order;
    isVisible;
    status;
    publishAt;
    expiresAt;
}
exports.UpdateSectionDto = UpdateSectionDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    (0, class_validator_1.MaxLength)(120),
    __metadata("design:type", String)
], UpdateSectionDto.prototype, "title", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(200),
    __metadata("design:type", String)
], UpdateSectionDto.prototype, "subtitle", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(exports.SECTION_LAYOUTS),
    __metadata("design:type", String)
], UpdateSectionDto.prototype, "layout", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], UpdateSectionDto.prototype, "order", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], UpdateSectionDto.prototype, "isVisible", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(exports.CONTENT_STATUSES),
    __metadata("design:type", String)
], UpdateSectionDto.prototype, "status", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], UpdateSectionDto.prototype, "publishAt", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], UpdateSectionDto.prototype, "expiresAt", void 0);
class CreateCardDto {
    sectionId;
    cardType;
    /** Presentation payload: title/price/rating/... (flattened by HomeService). */
    content;
    order;
    isVisible;
    status;
    publishAt;
    expiresAt;
}
exports.CreateCardDto = CreateCardDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], CreateCardDto.prototype, "sectionId", void 0);
__decorate([
    (0, class_validator_1.IsIn)(exports.CARD_TYPES),
    __metadata("design:type", String)
], CreateCardDto.prototype, "cardType", void 0);
__decorate([
    (0, class_validator_1.IsObject)(),
    (0, class_validator_1.Validate)(CreateDestinationMoodsConstraint),
    __metadata("design:type", Object)
], CreateCardDto.prototype, "content", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], CreateCardDto.prototype, "order", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], CreateCardDto.prototype, "isVisible", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(exports.CONTENT_STATUSES),
    __metadata("design:type", String)
], CreateCardDto.prototype, "status", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], CreateCardDto.prototype, "publishAt", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], CreateCardDto.prototype, "expiresAt", void 0);
class UpdateCardDto {
    cardType;
    /** Partial patch: provided keys are merged into the persisted content. */
    content;
    order;
    isVisible;
    status;
    publishAt;
    expiresAt;
}
exports.UpdateCardDto = UpdateCardDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(exports.CARD_TYPES),
    __metadata("design:type", String)
], UpdateCardDto.prototype, "cardType", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsObject)(),
    (0, class_validator_1.Validate)(ValidDestinationMoodsConstraint),
    __metadata("design:type", Object)
], UpdateCardDto.prototype, "content", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], UpdateCardDto.prototype, "order", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], UpdateCardDto.prototype, "isVisible", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(exports.CONTENT_STATUSES),
    __metadata("design:type", String)
], UpdateCardDto.prototype, "status", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], UpdateCardDto.prototype, "publishAt", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], UpdateCardDto.prototype, "expiresAt", void 0);
class ReorderDto {
    /** Entity ids in their new display order. */
    ids;
}
exports.ReorderDto = ReorderDto;
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], ReorderDto.prototype, "ids", void 0);
class UpdateProviderStatusDto {
    isActive;
}
exports.UpdateProviderStatusDto = UpdateProviderStatusDto;
__decorate([
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], UpdateProviderStatusDto.prototype, "isActive", void 0);
class UpdateProviderPriorityDto {
    priority;
}
exports.UpdateProviderPriorityDto = UpdateProviderPriorityDto;
__decorate([
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], UpdateProviderPriorityDto.prototype, "priority", void 0);
class UpdateProviderConfigDto {
    config;
}
exports.UpdateProviderConfigDto = UpdateProviderConfigDto;
__decorate([
    (0, class_validator_1.IsObject)(),
    __metadata("design:type", Object)
], UpdateProviderConfigDto.prototype, "config", void 0);
//# sourceMappingURL=admin.dto.js.map