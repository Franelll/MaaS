// ============================================================================
// MaaS Platform - Map Module
// ============================================================================

import { Module } from '@nestjs/common';
import { CacheModule } from '@nestjs/cache-manager';
import { MapController } from './map.controller';
import { MapService } from './map.service';

@Module({
  imports: [
    CacheModule.register({
      ttl: 10000, // 10 seconds
      max: 1000,
    }),
  ],
  controllers: [MapController],
  providers: [MapService],
  exports: [MapService],
})
export class MapModule {}
