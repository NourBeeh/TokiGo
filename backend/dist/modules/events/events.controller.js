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
exports.EventsController = void 0;
const common_1 = require("@nestjs/common");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const event_dto_1 = require("../../common/dto/event.dto");
const events_service_1 = require("./events.service");
/**
 * Behavioural signal tracking (R-3). Auth is optional per call: registered
 * users are identified by their JWT; guests send a stable deviceId in the body.
 */
let EventsController = class EventsController {
    events;
    constructor(events) {
        this.events = events;
    }
    async track(req, dto) {
        const user = req.user;
        await this.events.track({
            userId: user?.id,
            deviceId: user?.id ? undefined : dto.deviceId,
            type: dto.type,
            payload: dto.payload,
        });
    }
};
exports.EventsController = EventsController;
__decorate([
    (0, common_1.Post)(),
    (0, common_1.HttpCode)(204),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, event_dto_1.TrackEventDto]),
    __metadata("design:returntype", Promise)
], EventsController.prototype, "track", null);
exports.EventsController = EventsController = __decorate([
    (0, common_1.Controller)('events'),
    __metadata("design:paramtypes", [events_service_1.EventsService])
], EventsController);
//# sourceMappingURL=events.controller.js.map