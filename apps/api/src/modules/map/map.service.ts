// ============================================================================
// MaaS Platform - Map Service
// Business logic for map queries
// ============================================================================

import { Injectable, Logger } from '@nestjs/common';
import { 
  NearbySearchDto, 
  BoundingBoxSearchDto, 
  MapResponseDto,
  DeepLinkResponseDto,
} from './dto/map.dto';
import { ZtmPollerService } from './ztm-poller.service';

@Injectable()
export class MapService {
  private readonly logger = new Logger(MapService.name);
  
  constructor(
    private readonly ztmPollerService: ZtmPollerService,
  ) {}

  /**
   * Get entities within a bounding box
   */
  async getEntitiesInBoundingBox(query: BoundingBoxSearchDto): Promise<MapResponseDto> {
    try {
      // Fetch ZTM vehicles (buses + trams)
      const ztmVehicles = await this.ztmPollerService.fetchAll();
      
      // TODO: Filter by bounding box
      // TODO: Add GBFS vehicles from cache/DB
      
      this.logger.debug(`📍 Returning ${ztmVehicles.length} vehicles in bounding box`);
      console.log(`[MapService] Fetched ${ztmVehicles.length} ZTM vehicles`);
      
      return MapResponseDto.create(ztmVehicles, {
        boundingBox: query.boundingBox,
      });
    } catch (error) {
      this.logger.error('Error fetching entities:', error);
      return MapResponseDto.create([], {
        boundingBox: query.boundingBox,
      });
    }
  }

  /**
   * Get nearby entities
   */
  async getNearbyEntities(query: NearbySearchDto): Promise<MapResponseDto> {
    // TODO: Implement actual data fetching from Redis/DB
    // This is a placeholder implementation
    
    return MapResponseDto.create([], {
      center: query.location,
      radius: query.radius,
    });
  }

  /**
   * Generate deep link for a vehicle
   */
  async getDeepLink(
    vehicleId: string, 
    platform: 'ios' | 'android'
  ): Promise<DeepLinkResponseDto> {
    // Parse provider from vehicleId (format: "provider-slug:vehicle-id")
    const [providerSlug] = vehicleId.split(':');
    const platformSegment = platform === 'ios' ? 'ios' : 'android';
    
    // TODO: Look up provider and generate actual deep links
    // This is a placeholder implementation
    
    return {
      deepLink: `${providerSlug}://${platformSegment}/vehicle/${vehicleId}`,
      appStoreUrl: `https://apps.apple.com/app/${providerSlug}`,
      playStoreUrl: `https://play.google.com/store/apps/details?id=com.${providerSlug}`,
      webFallbackUrl: `https://${providerSlug}.eu`,
      provider: {
        name: providerSlug,
        slug: providerSlug,
      },
    };
  }
}
