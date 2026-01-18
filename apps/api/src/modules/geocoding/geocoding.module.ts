// ============================================================================
// MaaS Platform - Geocoding Module
// Address search and reverse geocoding using Photon (OSM)
// ============================================================================

import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { GeocodingController } from './geocoding.controller';
import { GeocodingService } from './geocoding.service';

@Module({
  imports: [
    ConfigModule,
    HttpModule.register({
      timeout: 10000,
      maxRedirects: 3,
    }),
  ],
  controllers: [GeocodingController],
  providers: [GeocodingService],
  exports: [GeocodingService],
})
export class GeocodingModule {}
