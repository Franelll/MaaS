// ============================================================================
// MaaS Platform - Routing Module
// Multimodal trip planning with OpenTripPlanner v2
// ============================================================================

import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { RoutingController } from './routing.controller';
import { TripPlannerService } from './services/trip-planner.service';
import { RouteScoringService } from './services/route-scoring.service';
import { OtpGraphqlClient } from './services/otp-graphql.client';

@Module({
  imports: [
    ConfigModule,
    HttpModule.register({
      timeout: 30000,
      maxRedirects: 3,
    }),
  ],
  controllers: [RoutingController],
  providers: [
    TripPlannerService,
    RouteScoringService,
    OtpGraphqlClient,
  ],
  exports: [TripPlannerService],
})
export class RoutingModule {}
