// ============================================================================
// MaaS Platform - Map Module
// ============================================================================

import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { CacheModule } from '@nestjs/cache-manager';
import { MapController } from './map.controller';
import { MapService } from './map.service';
import { ZtmPollerService } from './ztm-poller.service';

@Module({
  imports: [
    HttpModule,
    ConfigModule,
    CacheModule.register({
      ttl: 10000, // 10 seconds
      max: 1000,
    }),
  ],
  controllers: [MapController],
  providers: [MapService, ZtmPollerService],
  exports: [MapService],
})
export class MapModule {}
