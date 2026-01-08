// ============================================================================
// MaaS Platform - Map DTOs
// Data Transfer Objects for map endpoints
// ============================================================================

import { 
  IsNumber, 
  IsOptional, 
  IsString, 
  Min, 
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { 
  GeoLocation, 
  BoundingBox, 
  MapEntityType,
  UnifiedMapEntity,
} from '@maas/common';

/**
 * Nearby search request DTO
 */
export class NearbySearchDto {
  @ApiProperty({ description: 'Latitude of center point', example: 52.2297 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  lat!: number;

  @ApiProperty({ description: 'Longitude of center point', example: 21.0122 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  lng!: number;

  @ApiPropertyOptional({ description: 'Search radius in meters', default: 500, example: 500 })
  @IsOptional()
  @IsNumber()
  @Min(50)
  @Max(5000)
  @Type(() => Number)
  radius?: number = 500;

  @ApiPropertyOptional({ 
    description: 'Comma-separated entity types to include',
    example: 'scooter,bike,transit_stop',
  })
  @IsOptional()
  @IsString()
  types?: string;

  @ApiPropertyOptional({ 
    description: 'Comma-separated provider slugs to include',
    example: 'bolt-scooters,tier',
  })
  @IsOptional()
  @IsString()
  providers?: string;

  @ApiPropertyOptional({ description: 'Maximum number of results', default: 50 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(200)
  @Type(() => Number)
  limit?: number = 50;

  /**
   * Get location as GeoLocation
   */
  get location(): GeoLocation {
    return { lat: this.lat, lng: this.lng };
  }

  /**
   * Get types as array
   */
  get entityTypes(): MapEntityType[] | undefined {
    return this.types?.split(',').map(t => t.trim() as MapEntityType);
  }

  /**
   * Get providers as array
   */
  get providerSlugs(): string[] | undefined {
    return this.providers?.split(',').map(p => p.trim());
  }
}

/**
 * Bounding box search request DTO
 */
export class BoundingBoxSearchDto {
  @ApiProperty({ description: 'North latitude of bounding box', example: 52.25 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  north!: number;

  @ApiProperty({ description: 'South latitude of bounding box', example: 52.20 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  south!: number;

  @ApiProperty({ description: 'East longitude of bounding box', example: 21.05 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  east!: number;

  @ApiProperty({ description: 'West longitude of bounding box', example: 20.95 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  west!: number;

  @ApiPropertyOptional({ 
    description: 'Comma-separated entity types to include',
    example: 'scooter,bike,station',
  })
  @IsOptional()
  @IsString()
  types?: string;

  @ApiPropertyOptional({ 
    description: 'Comma-separated provider slugs to include',
    example: 'bolt-scooters,tier,dott',
  })
  @IsOptional()
  @IsString()
  providers?: string;

  @ApiPropertyOptional({ description: 'Maximum number of results', default: 100 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(500)
  @Type(() => Number)
  limit?: number = 100;

  /**
   * Get bounding box object
   */
  get boundingBox(): BoundingBox {
    return {
      north: this.north,
      south: this.south,
      east: this.east,
      west: this.west,
    };
  }

  /**
   * Get types as array
   */
  get entityTypes(): MapEntityType[] | undefined {
    return this.types?.split(',').map(t => t.trim() as MapEntityType);
  }

  /**
   * Get providers as array
   */
  get providerSlugs(): string[] | undefined {
    return this.providers?.split(',').map(p => p.trim());
  }
}

/**
 * Map response DTO
 */
export class MapResponseDto {
  @ApiProperty({ description: 'Array of map entities' })
  entities!: UnifiedMapEntity[];

  @ApiProperty({ description: 'Response metadata' })
  meta!: {
    totalCount: number;
    providers: string[];
    timestamp: Date;
    boundingBox?: BoundingBox;
    center?: GeoLocation;
    radius?: number;
  };

  static create(
    entities: UnifiedMapEntity[],
    options: {
      boundingBox?: BoundingBox;
      center?: GeoLocation;
      radius?: number;
    } = {},
  ): MapResponseDto {
    const providers = [...new Set(entities.map(e => e.provider.slug))];
    
    return {
      entities,
      meta: {
        totalCount: entities.length,
        providers,
        timestamp: new Date(),
        ...options,
      },
    };
  }
}

/**
 * Deep link response DTO
 */
export class DeepLinkResponseDto {
  @ApiProperty({ description: 'Primary deep link URL' })
  deepLink!: string;

  @ApiProperty({ description: 'iOS App Store URL' })
  appStoreUrl!: string;

  @ApiProperty({ description: 'Android Play Store URL' })
  playStoreUrl!: string;

  @ApiProperty({ description: 'Web fallback URL' })
  webFallbackUrl!: string;

  @ApiProperty({ description: 'Provider information' })
  provider!: {
    name: string;
    slug: string;
  };
}
