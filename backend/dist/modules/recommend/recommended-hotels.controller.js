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
exports.RecommendedHotelsController = void 0;
const common_1 = require("@nestjs/common");
const recommend_dto_1 = require("../../common/dto/recommend.dto");
const recommended_hotel_service_1 = require("./recommended-hotel.service");
/**
 * Personalised/recommendation endpoint (R-4). Reads the caller identity from
 * the (optional) JWT to enrich the profile and country; falls back to default
 * recommendations for guests. All hotels come from the current provider only.
 */
let RecommendedHotelsController = class RecommendedHotelsController {
    engine;
    constructor(engine) {
        this.engine = engine;
    }
    async recommend(req, query) {
        const userId = req.user?.id;
        const result = await this.engine.recommend({
            userId,
            limit: query.limit,
            // Explicit caller country wins over the profile fallback. Dropping this
            // silently was why every Home stayed on the launch market.
            countryCode: query.code,
        });
        return {
            ...result,
            hotels: result.hotels.map((h) => ({
                ...h,
                // Wire name compatibility: the Flutter HomeItem expects `title` and
                // presentation fields; the Nuitee id stays the canonical key.
                type: 'hotel',
            })),
        };
    }
};
exports.RecommendedHotelsController = RecommendedHotelsController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, recommend_dto_1.RecommendedHotelsQueryDto]),
    __metadata("design:returntype", Promise)
], RecommendedHotelsController.prototype, "recommend", null);
exports.RecommendedHotelsController = RecommendedHotelsController = __decorate([
    (0, common_1.Controller)('home/recommended'),
    __metadata("design:paramtypes", [recommended_hotel_service_1.RecommendedHotelService])
], RecommendedHotelsController);
//# sourceMappingURL=recommended-hotels.controller.js.map