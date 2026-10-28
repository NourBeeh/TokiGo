import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import databaseConfig from './config/database.config';
import { UsersModule } from './modules/users/users.module';
import { AuthModule } from './modules/auth/auth.module';
import { ProvidersModule } from './modules/providers/providers.module';
import { OffersModule } from './modules/offers/offers.module';
import { HomeModule } from './modules/home/home.module';
import { CacheModule } from './modules/cache/cache.module';
import { AdminModule } from './modules/admin/admin.module';
import { AiModule } from './modules/ai/ai.module';
import { AiConversationModule } from './modules/ai/ai.conversation.module';
import { AuditModule } from './modules/audit/audit.module';
import { DuffelModule } from './modules/duffel/duffel.module';
import { GeoModule } from './modules/geo/geo.module';
import { ProfileModule } from './modules/profile/profile.module';
import { EventsModule } from './modules/events/events.module';
import { RecommendModule } from './modules/recommend/recommend.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { MemoryModule } from './modules/memory/memory.module';
import { BookingsModule } from './modules/bookings/bookings.module';

@Module({
  imports: [
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 30 }]),
    ConfigModule.forRoot({
      isGlobal: true,
      load: [databaseConfig],
      envFilePath: ['.env', '../.env'],
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get('database.host'),
        port: config.get('database.port'),
        username: config.get('database.username'),
        password: config.get('database.password'),
        database: config.get('database.database'),
        autoLoadEntities: true,
        synchronize: process.env.NODE_ENV !== 'production',
      }),
      inject: [ConfigService],
    }),
    UsersModule,
    AuthModule,
    ProvidersModule,
    OffersModule,
    HomeModule,
    CacheModule,
    AdminModule,
    AiModule,
    AiConversationModule,
    AuditModule,
    DuffelModule,
    GeoModule,
    ProfileModule,
    EventsModule,
    RecommendModule,
    PaymentsModule,
    MemoryModule,
    BookingsModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}