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
exports.SearchController = void 0;
const common_1 = require("@nestjs/common");
const flight_search_dto_1 = require("../../common/dto/flight.search.dto");
const hotel_search_dto_1 = require("../../common/dto/hotel.search.dto");
const car_search_dto_1 = require("../../common/dto/car.search.dto");
const search_service_1 = require("./search.service");
/**
 * Unified search endpoints. `market` is an optional ISO country code that
 * selects the MarketContext (display currency/locale/payment region).
 * It never selects a provider — routing is a separate policy (spec point 3).
 */
let SearchController = class SearchController {
    searchService;
    constructor(searchService) {
        this.searchService = searchService;
    }
    async searchFlights(dto) {
        return this.searchService.searchFlights(dto, dto.market);
    }
    async searchHotels(dto) {
        return this.searchService.searchHotels(dto, dto.market);
    }
    async searchCars(dto) {
        return this.searchService.searchCars(dto, dto.market);
    }
};
exports.SearchController = SearchController;
__decorate([
    (0, common_1.Post)('flights'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [flight_search_dto_1.FlightSearchDto]),
    __metadata("design:returntype", Promise)
], SearchController.prototype, "searchFlights", null);
__decorate([
    (0, common_1.Post)('hotels'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [hotel_search_dto_1.HotelSearchDto]),
    __metadata("design:returntype", Promise)
], SearchController.prototype, "searchHotels", null);
__decorate([
    (0, common_1.Post)('cars'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [car_search_dto_1.CarSearchDto]),
    __metadata("design:returntype", Promise)
], SearchController.prototype, "searchCars", null);
exports.SearchController = SearchController = __decorate([
    (0, common_1.Controller)('search'),
    __metadata("design:paramtypes", [search_service_1.SearchService])
], SearchController);
//# sourceMappingURL=search.controller.js.map