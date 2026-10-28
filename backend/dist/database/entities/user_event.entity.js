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
exports.UserEvent = void 0;
const typeorm_1 = require("typeorm");
/**
 * One behavioural signal collected for the recommendation engine (R-3).
 *
 * Each row is a lightweight fact: what the user did, with which payload, when.
 * Keys either a registered userId or an anonymous deviceId (guest flows) —
 * exactly one is set. No free-text, no personal data beyond ids.
 */
let UserEvent = class UserEvent {
    id;
    userId;
    deviceId;
    type; // hotel_search | hotel_view | favorite | trip_planned | ...
    payload;
    createdAt;
};
exports.UserEvent = UserEvent;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], UserEvent.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], UserEvent.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], UserEvent.prototype, "deviceId", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], UserEvent.prototype, "type", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb', default: () => "'{}'::jsonb" }),
    __metadata("design:type", Object)
], UserEvent.prototype, "payload", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], UserEvent.prototype, "createdAt", void 0);
exports.UserEvent = UserEvent = __decorate([
    (0, typeorm_1.Entity)('user_events')
], UserEvent);
//# sourceMappingURL=user_event.entity.js.map