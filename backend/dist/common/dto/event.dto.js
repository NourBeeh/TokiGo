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
exports.TrackEventDto = exports.EVENT_TYPES = void 0;
const class_validator_1 = require("class-validator");
/** All event types the recommendation engine understands (R-3/R-4). */
exports.EVENT_TYPES = [
    'hotel_search',
    'hotel_view',
    'hotel_favorite',
    'trip_planned',
    'booking_confirmed',
];
class TrackEventDto {
    type;
    /** Optional stable client id used for anonymous (guest) profiles. */
    deviceId;
    payload;
}
exports.TrackEventDto = TrackEventDto;
__decorate([
    (0, class_validator_1.IsIn)(exports.EVENT_TYPES),
    __metadata("design:type", String)
], TrackEventDto.prototype, "type", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(80),
    __metadata("design:type", String)
], TrackEventDto.prototype, "deviceId", void 0);
__decorate([
    (0, class_validator_1.IsObject)(),
    __metadata("design:type", Object)
], TrackEventDto.prototype, "payload", void 0);
//# sourceMappingURL=event.dto.js.map