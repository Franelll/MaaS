// ============================================================================
// MaaS Platform - Map Controller
// Unified API for map entities across all providers
// ============================================================================

import {
  Controller,
  Get,
  Query,
  Version,
  UseInterceptors,
} from '@nestjs/common';
import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiQuery,
} from '@nestjs/swagger';
import { MapService } from './map.service';
import {
  NearbySearchDto,
  BoundingBoxSearchDto,
  MapResponseDto,
} from './dto/map.dto';

@ApiTags('map')
@Controller('map')
export class MapController {
  constructor(private readonly mapService: MapService) {}

  /**
   * Get all mobility entities within a bounding box
   */
  @Get('entities')
  @Version('1')
  @UseInterceptors(CacheInterceptor)
  @CacheTTL(10)
  @ApiOperation({
    summary: 'Get map entities within bounding box',
    description: 'Returns all mobility entities (vehicles, stations, transit stops) within the specified bounding box',
  })
  @ApiQuery({ name: 'north', type: Number, description: 'North latitude of bounding box' })
  @ApiQuery({ name: 'south', type: Number, description: 'South latitude of bounding box' })
  @ApiQuery({ name: 'east', type: Number, description: 'East longitude of bounding box' })
  @ApiQuery({ name: 'west', type: Number, description: 'West longitude of bounding box' })
  @ApiQuery({ name: 'types', type: String, required: false, description: 'Comma-separated entity types' })
  @ApiQuery({ name: 'providers', type: String, required: false, description: 'Comma-separated provider slugs' })
  @ApiQuery({ name: 'limit', type: Number, required: false, description: 'Max entities to return (default: 100)' })
  @ApiResponse({ status: 200, description: 'Map entities retrieved successfully' })
  async getEntitiesInBoundingBox(
    @Query() query: BoundingBoxSearchDto
  ): Promise<MapResponseDto> {
    return this.mapService.getEntitiesInBoundingBox(query);
  }

  /**
   * Get nearby mobility entities
   */
  @Get('nearby')
  @Version('1')
  @UseInterceptors(CacheInterceptor)
  @CacheTTL(10)
  @ApiOperation({
    summary: 'Get nearby mobility entities',
    description: 'Returns mobility entities within specified radius of a point',
  })
  @ApiQuery({ name: 'lat', type: Number, description: 'Latitude of center point' })
  @ApiQuery({ name: 'lng', type: Number, description: 'Longitude of center point' })
  @ApiQuery({ name: 'radius', type: Number, required: false, description: 'Search radius in meters (default: 500)' })
  @ApiQuery({ name: 'types', type: String, required: false, description: 'Comma-separated entity types' })
  @ApiQuery({ name: 'providers', type: String, required: false, description: 'Comma-separated provider slugs' })
  @ApiQuery({ name: 'limit', type: Number, required: false, description: 'Max entities to return (default: 50)' })
  @ApiResponse({ status: 200, description: 'Nearby entities retrieved successfully' })
  async getNearbyEntities(
    @Query() query: NearbySearchDto
  ): Promise<MapResponseDto> {
    return this.mapService.getNearbyEntities(query);
  }

  /**
   * Get nearby scooters/bikes only
   */
  @Get('nearby/micromobility')
  @Version('1')
  @UseInterceptors(CacheInterceptor)
  @CacheTTL(10)
  @ApiOperation({
    summary: 'Get nearby micromobility vehicles',
    description: 'Returns scooters, bikes, and e-bikes within radius',
  })
  @ApiResponse({ status: 200, description: 'Micromobility vehicles retrieved successfully' })
  async getNearbyMicromobility(
    @Query() query: NearbySearchDto
  ): Promise<MapResponseDto> {
    query.types = 'scooter,bike,ebike';
    return this.mapService.getNearbyEntities(query);
  }

  /**
   * Get nearby transit stops with departures
   */
  @Get('nearby/transit')
  @Version('1')
  @UseInterceptors(CacheInterceptor)
  @CacheTTL(15)
  @ApiOperation({
    summary: 'Get nearby transit stops',
    description: 'Returns transit stops with upcoming departures within radius',
  })
  @ApiResponse({ status: 200, description: 'Transit stops retrieved successfully' })
  async getNearbyTransit(
    @Query() query: NearbySearchDto
  ): Promise<MapResponseDto> {
    query.types = 'transit_stop';
    return this.mapService.getNearbyEntities(query);
  }

  /**
   * Get deep link for a specific vehicle
   */
  @Get('deeplink/:vehicleId')
  @Version('1')
  @ApiOperation({
    summary: 'Get deep link for vehicle',
    description: 'Returns deep link URL to open vehicle in provider app',
  })
  @ApiResponse({ status: 200, description: 'Deep link generated successfully' })
  async getDeepLink(
    @Query('vehicleId') vehicleId: string,
    @Query('platform') platform: 'ios' | 'android' = 'android'
  ) {
    return this.mapService.getDeepLink(vehicleId, platform);
  }
}
