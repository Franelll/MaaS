// ============================================================================
// MaaS Platform - Geocoding Controller
// REST API endpoints for address search
// ============================================================================

import {
  Controller,
  Get,
  Query,
  Logger,
  BadRequestException,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiQuery,
} from '@nestjs/swagger';
import { GeocodingService, GeocodingResult } from './geocoding.service';

// ============================================================================
// DTOs (for documentation purposes)
// ============================================================================

class GeocodingResponseDto {
  success!: boolean;
  data!: {
    results: GeocodingResult[];
    count: number;
  };
}

class ReverseGeocodingResponseDto {
  success!: boolean;
  data!: GeocodingResult | null;
}

// ============================================================================
// Controller
// ============================================================================

@ApiTags('Geocoding')
@Controller('geocode')
export class GeocodingController {
  private readonly logger = new Logger(GeocodingController.name);

  constructor(private readonly geocodingService: GeocodingService) {}

  /**
   * Search for addresses and places
   */
  @Get()
  @ApiOperation({
    summary: 'Search for addresses',
    description: 'Search for addresses, places, and transit stops by text query. Results are biased towards the provided location.',
  })
  @ApiQuery({ name: 'q', required: true, description: 'Search query (min 2 characters)' })
  @ApiQuery({ name: 'lat', required: false, description: 'Latitude for location bias' })
  @ApiQuery({ name: 'lon', required: false, description: 'Longitude for location bias' })
  @ApiQuery({ name: 'limit', required: false, description: 'Max results (default: 10, max: 20)' })
  @ApiResponse({
    status: 200,
    description: 'Search results',
    type: GeocodingResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Invalid query parameters',
  })
  async search(
    @Query('q') query: string,
    @Query('lat') lat?: string,
    @Query('lon') lon?: string,
    @Query('limit') limit?: string,
  ): Promise<GeocodingResponseDto> {
    if (!query || query.trim().length < 2) {
      throw new BadRequestException('Query must be at least 2 characters');
    }

    const parsedLat = lat ? parseFloat(lat) : undefined;
    const parsedLon = lon ? parseFloat(lon) : undefined;
    const parsedLimit = Math.min(parseInt(limit || '10', 10), 20);

    // Validate coordinates if provided
    if (parsedLat !== undefined && (isNaN(parsedLat) || parsedLat < -90 || parsedLat > 90)) {
      throw new BadRequestException('Invalid latitude');
    }
    if (parsedLon !== undefined && (isNaN(parsedLon) || parsedLon < -180 || parsedLon > 180)) {
      throw new BadRequestException('Invalid longitude');
    }

    this.logger.log(`Geocoding search: "${query}"`);

    const results = await this.geocodingService.search({
      query: query.trim(),
      lat: parsedLat,
      lon: parsedLon,
      limit: parsedLimit,
    });

    return {
      success: true,
      data: {
        results,
        count: results.length,
      },
    };
  }

  /**
   * Autocomplete for search-as-you-type
   */
  @Get('autocomplete')
  @ApiOperation({
    summary: 'Autocomplete addresses',
    description: 'Fast autocomplete for search-as-you-type functionality. Returns fewer results optimized for dropdown display.',
  })
  @ApiQuery({ name: 'q', required: true, description: 'Partial search query' })
  @ApiQuery({ name: 'lat', required: false, description: 'Latitude for location bias' })
  @ApiQuery({ name: 'lon', required: false, description: 'Longitude for location bias' })
  @ApiResponse({
    status: 200,
    description: 'Autocomplete suggestions',
    type: GeocodingResponseDto,
  })
  async autocomplete(
    @Query('q') query: string,
    @Query('lat') lat?: string,
    @Query('lon') lon?: string,
  ): Promise<GeocodingResponseDto> {
    const parsedLat = lat ? parseFloat(lat) : undefined;
    const parsedLon = lon ? parseFloat(lon) : undefined;

    const results = await this.geocodingService.autocomplete(
      query?.trim() || '',
      parsedLat,
      parsedLon,
    );

    return {
      success: true,
      data: {
        results,
        count: results.length,
      },
    };
  }

  /**
   * Reverse geocoding (coordinates to address)
   */
  @Get('reverse')
  @ApiOperation({
    summary: 'Reverse geocode',
    description: 'Get address for given coordinates',
  })
  @ApiQuery({ name: 'lat', required: true, description: 'Latitude' })
  @ApiQuery({ name: 'lon', required: true, description: 'Longitude' })
  @ApiResponse({
    status: 200,
    description: 'Address for coordinates',
    type: ReverseGeocodingResponseDto,
  })
  async reverse(
    @Query('lat') lat: string,
    @Query('lon') lon: string,
  ): Promise<ReverseGeocodingResponseDto> {
    const parsedLat = parseFloat(lat);
    const parsedLon = parseFloat(lon);

    if (isNaN(parsedLat) || parsedLat < -90 || parsedLat > 90) {
      throw new BadRequestException('Invalid latitude');
    }
    if (isNaN(parsedLon) || parsedLon < -180 || parsedLon > 180) {
      throw new BadRequestException('Invalid longitude');
    }

    const result = await this.geocodingService.reverse({
      lat: parsedLat,
      lon: parsedLon,
    });

    return {
      success: true,
      data: result,
    };
  }

  /**
   * Search for transit stops
   */
  @Get('stops')
  @ApiOperation({
    summary: 'Search transit stops',
    description: 'Search specifically for public transport stops and stations',
  })
  @ApiQuery({ name: 'q', required: true, description: 'Stop name query' })
  @ApiQuery({ name: 'lat', required: false, description: 'Latitude for bias' })
  @ApiQuery({ name: 'lon', required: false, description: 'Longitude for bias' })
  @ApiResponse({
    status: 200,
    description: 'Transit stop results',
    type: GeocodingResponseDto,
  })
  async searchStops(
    @Query('q') query: string,
    @Query('lat') lat?: string,
    @Query('lon') lon?: string,
  ): Promise<GeocodingResponseDto> {
    if (!query || query.trim().length < 2) {
      throw new BadRequestException('Query must be at least 2 characters');
    }

    const parsedLat = lat ? parseFloat(lat) : undefined;
    const parsedLon = lon ? parseFloat(lon) : undefined;

    const results = await this.geocodingService.searchStops(
      query.trim(),
      parsedLat,
      parsedLon,
    );

    return {
      success: true,
      data: {
        results,
        count: results.length,
      },
    };
  }
}
