// ============================================================================
// MaaS Platform - ZTM Module
// ============================================================================

import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { ZtmPollerService } from './services/ztm-poller.service.js';

@Module({
  imports: [HttpModule, ConfigModule],
  providers: [ZtmPollerService],
  exports: [ZtmPollerService],
})
export class ZtmModule {}
