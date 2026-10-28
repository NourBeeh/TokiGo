"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const throttler_1 = require("@nestjs/throttler");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const database_config_1 = __importDefault(require("./config/database.config"));
const users_module_1 = require("./modules/users/users.module");
const auth_module_1 = require("./modules/auth/auth.module");
const providers_module_1 = require("./modules/providers/providers.module");
const offers_module_1 = require("./modules/offers/offers.module");
const home_module_1 = require("./modules/home/home.module");
const cache_module_1 = require("./modules/cache/cache.module");
const admin_module_1 = require("./modules/admin/admin.module");
const ai_module_1 = require("./modules/ai/ai.module");
const ai_conversation_module_1 = require("./modules/ai/ai.conversation.module");
const audit_module_1 = require("./modules/audit/audit.module");
const duffel_module_1 = require("./modules/duffel/duffel.module");
const geo_module_1 = require("./modules/geo/geo.module");
const profile_module_1 = require("./modules/profile/profile.module");
const events_module_1 = require("./modules/events/events.module");
const recommend_module_1 = require("./modules/recommend/recommend.module");
const payments_module_1 = require("./modules/payments/payments.module");
const memory_module_1 = require("./modules/memory/memory.module");
const bookings_module_1 = require("./modules/bookings/bookings.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            throttler_1.ThrottlerModule.forRoot([{ ttl: 60000, limit: 30 }]),
            config_1.ConfigModule.forRoot({
                isGlobal: true,
                load: [database_config_1.default],
                envFilePath: ['.env', '../.env'],
            }),
            typeorm_1.TypeOrmModule.forRootAsync({
                imports: [config_1.ConfigModule],
                useFactory: (config) => ({
                    type: 'postgres',
                    host: config.get('database.host'),
                    port: config.get('database.port'),
                    username: config.get('database.username'),
                    password: config.get('database.password'),
                    database: config.get('database.database'),
                    autoLoadEntities: true,
                    synchronize: process.env.NODE_ENV !== 'production',
                }),
                inject: [config_1.ConfigService],
            }),
            users_module_1.UsersModule,
            auth_module_1.AuthModule,
            providers_module_1.ProvidersModule,
            offers_module_1.OffersModule,
            home_module_1.HomeModule,
            cache_module_1.CacheModule,
            admin_module_1.AdminModule,
            ai_module_1.AiModule,
            ai_conversation_module_1.AiConversationModule,
            audit_module_1.AuditModule,
            duffel_module_1.DuffelModule,
            geo_module_1.GeoModule,
            profile_module_1.ProfileModule,
            events_module_1.EventsModule,
            recommend_module_1.RecommendModule,
            payments_module_1.PaymentsModule,
            memory_module_1.MemoryModule,
            bookings_module_1.BookingsModule,
        ],
        providers: [{ provide: core_1.APP_GUARD, useClass: throttler_1.ThrottlerGuard }],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map