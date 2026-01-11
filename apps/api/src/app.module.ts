// ============================================================================
// MaaS Platform - API Application Module
// ============================================================================

import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
// import { TypeOrmModule, ConfigService } from '@nestjs/typeorm';
import { ThrottlerModule } from '@nestjs/throttler';
import { HealthModule } from './modules/health/health.module';
import { MapModule } from './modules/map/map.module';
import { ProvidersModule } from './modules/providers/providers.module';
import { RoutingModule } from './modules/routing/routing.module';

@Module({
  imports: [
    // Configuration
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env.local', '.env'],
    }),

    // Database (DISABLED FOR ZTM API TESTING)
    // TypeOrmModule.forRootAsync({
    //   imports: [ConfigModule],
    //   inject: [ConfigService],
    //   useFactory: (configService: ConfigService) => ({
    //     type: 'postgres',
    //     url: configService.get<string>('DATABASE_URL'),
    //     autoLoadEntities: true,
    //     synchronize: configService.get<string>('NODE_ENV') !== 'production',
    //     logging: configService.get<string>('NODE_ENV') === 'development',
    //     ssl: configService.get<string>('NODE_ENV') === 'production' 
    //       ? { rejectUnauthorized: false } 
    //       : false,
    //   }),
    // }),

    // Rate limiting
    ThrottlerModule.forRoot([
      {
        name: 'short',
        ttl: 1000,
        limit: 10,
      },
      {
        name: 'medium',
        ttl: 10000,
        limit: 50,
      },
      {
        name: 'long',
        ttl: 60000,
        limit: 100,
      },
    ]),

    // Feature modules
    HealthModule,
    MapModule,
    ProvidersModule,
    RoutingModule,  // Phase 2: Multimodal Routing
  ],
})
export class AppModule {}
