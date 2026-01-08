// ============================================================================
// MaaS Platform - Providers Controller
// ============================================================================

import { Controller, Get, Param, Version } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { ProvidersService } from './providers.service';

@ApiTags('providers')
@Controller('providers')
export class ProvidersController {
  constructor(private readonly providersService: ProvidersService) {}

  @Get()
  @Version('1')
  @ApiOperation({ summary: 'Get all mobility providers' })
  @ApiResponse({ status: 200, description: 'List of providers' })
  async getAllProviders() {
    return this.providersService.findAll();
  }

  @Get(':slug')
  @Version('1')
  @ApiOperation({ summary: 'Get provider by slug' })
  @ApiResponse({ status: 200, description: 'Provider details' })
  @ApiResponse({ status: 404, description: 'Provider not found' })
  async getProvider(@Param('slug') slug: string) {
    return this.providersService.findBySlug(slug);
  }

  @Get(':slug/health')
  @Version('1')
  @ApiOperation({ summary: 'Get provider health status' })
  @ApiResponse({ status: 200, description: 'Provider health status' })
  async getProviderHealth(@Param('slug') slug: string) {
    return this.providersService.getHealth(slug);
  }
}
