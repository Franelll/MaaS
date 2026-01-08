// ============================================================================
// MaaS Platform - Redis Cache Service
// High-performance caching for real-time vehicle positions
// ============================================================================

import Redis from 'ioredis';
import {
  GeoLocation,
  BoundingBox,
  UnifiedMapEntity,
  MicromobilityEntity,
  StationEntity,
  CACHE_TTL,
} from '@maas/common';

/**
 * Cache service configuration
 */
export interface CacheServiceConfig {
  redisUrl: string;
  keyPrefix?: string;
  defaultTtl?: number;
}

/**
 * Geo search result
 */
export interface GeoSearchResult {
  id: string;
  distance: number;
  location: GeoLocation;
}

/**
 * Vehicle Cache Service
 * Manages real-time vehicle positions in Redis with geo-spatial queries
 */
export class VehicleCacheService {
  private redis: Redis;
  private keyPrefix: string;

  constructor(config: CacheServiceConfig) {
    this.redis = new Redis(config.redisUrl, {
      maxRetriesPerRequest: 3,
      retryStrategy: (times: number) => Math.min(times * 50, 2000),
      enableReadyCheck: true,
    });
    this.keyPrefix = config.keyPrefix || 'maas:';
    
    this.redis.on('error', (err: Error) => {
      console.error('[Redis] Connection error:', err);
    });
    
    this.redis.on('connect', () => {
      console.log('[Redis] Connected successfully');
    });
  }

  // ==========================================================================
  // Vehicle Operations
  // ==========================================================================

  /**
   * Store multiple vehicles with their positions
   */
  async setVehicles(
    providerId: string,
    vehicles: MicromobilityEntity[]
  ): Promise<void> {
    if (vehicles.length === 0) return;

    const pipeline = this.redis.pipeline();
    const geoKey = this.getGeoKey('vehicles');
    const dataKey = this.getDataKey('vehicles', providerId);
    
    // Clear old vehicles for this provider
    const existingIds = await this.redis.hkeys(dataKey);
    if (existingIds.length > 0) {
      // Remove from geo index
      pipeline.zrem(geoKey, ...existingIds);
    }
    pipeline.del(dataKey);

    // Add new vehicles
    for (const vehicle of vehicles) {
      const vehicleKey = vehicle.id;
      
      // Add to geo index for spatial queries
      pipeline.geoadd(
        geoKey,
        vehicle.location.lng,
        vehicle.location.lat,
        vehicleKey
      );
      
      // Store vehicle data
      pipeline.hset(dataKey, vehicleKey, JSON.stringify(vehicle));
    }
    
    // Set TTL on data key
    pipeline.expire(dataKey, CACHE_TTL.VEHICLES);
    
    await pipeline.exec();
  }

  /**
   * Get vehicles within radius of a point
   */
  async getNearbyVehicles(
    location: GeoLocation,
    radiusMeters: number,
    limit: number = 50
  ): Promise<MicromobilityEntity[]> {
    const geoKey = this.getGeoKey('vehicles');
    
    // Get vehicle IDs within radius
    const results = await this.redis.georadius(
      geoKey,
      location.lng,
      location.lat,
      radiusMeters,
      'm',
      'WITHCOORD',
      'WITHDIST',
      'ASC',
      'COUNT',
      limit
    ) as Array<[string, string, [string, string]]>;

    if (results.length === 0) return [];

    // Get vehicle data
    const vehicles = await this.getVehiclesByIds(
      results.map(r => r[0])
    );

    // Attach distance to each vehicle
    const distanceMap = new Map(
      results.map(r => [r[0], parseFloat(r[1])])
    );

    return vehicles.map(v => ({
      ...v,
      _distance: distanceMap.get(v.id),
    })) as MicromobilityEntity[];
  }

  /**
   * Get vehicles within a bounding box
   */
  async getVehiclesInBoundingBox(
    bbox: BoundingBox,
    limit: number = 100
  ): Promise<MicromobilityEntity[]> {
    const geoKey = this.getGeoKey('vehicles');
    
    // GEOSEARCH with BYBOX
    await this.redis.call(
      'GEOSEARCH',
      geoKey,
      'FROMMEMBER', 'dummy', // We'll use corner approach instead
      'BYBOX',
      this.calculateBoxWidth(bbox),
      this.calculateBoxHeight(bbox),
      'km',
      'ASC',
      'COUNT',
      limit
    ).catch(() => []);

    // Fallback: use center point with radius
    const center = this.getBoundingBoxCenter(bbox);
    const radius = this.getBoundingBoxRadius(bbox);
    
    return this.getNearbyVehicles(center, radius, limit);
  }

  /**
   * Get vehicles by IDs
   */
  async getVehiclesByIds(ids: string[]): Promise<MicromobilityEntity[]> {
    if (ids.length === 0) return [];

    // Get all provider data keys
    const keys = await this.redis.keys(`${this.keyPrefix}vehicles:data:*`);
    
    const vehicles: MicromobilityEntity[] = [];
    
    for (const key of keys) {
      const results = await this.redis.hmget(key, ...ids);
      for (const data of results) {
        if (data) {
          try {
            vehicles.push(JSON.parse(data));
          } catch (e) {
            // Skip invalid data
          }
        }
      }
    }
    
    return vehicles;
  }

  // ==========================================================================
  // Station Operations
  // ==========================================================================

  /**
   * Store stations with their positions
   */
  async setStations(
    providerId: string,
    stations: StationEntity[]
  ): Promise<void> {
    if (stations.length === 0) return;

    const pipeline = this.redis.pipeline();
    const geoKey = this.getGeoKey('stations');
    const dataKey = this.getDataKey('stations', providerId);
    
    // Clear old stations for this provider
    pipeline.del(dataKey);

    for (const station of stations) {
      const stationKey = station.id;
      
      // Add to geo index
      pipeline.geoadd(
        geoKey,
        station.location.lng,
        station.location.lat,
        stationKey
      );
      
      // Store station data
      pipeline.hset(dataKey, stationKey, JSON.stringify(station));
    }
    
    pipeline.expire(dataKey, CACHE_TTL.STATIONS);
    
    await pipeline.exec();
  }

  /**
   * Get stations within radius
   */
  async getNearbyStations(
    location: GeoLocation,
    radiusMeters: number,
    limit: number = 20
  ): Promise<StationEntity[]> {
    const geoKey = this.getGeoKey('stations');
    
    const results = await this.redis.georadius(
      geoKey,
      location.lng,
      location.lat,
      radiusMeters,
      'm',
      'WITHCOORD',
      'WITHDIST',
      'ASC',
      'COUNT',
      limit
    ) as Array<[string, string, [string, string]]>;

    if (results.length === 0) return [];

    return this.getStationsByIds(results.map(r => r[0]));
  }

  /**
   * Get stations by IDs
   */
  async getStationsByIds(ids: string[]): Promise<StationEntity[]> {
    if (ids.length === 0) return [];

    const keys = await this.redis.keys(`${this.keyPrefix}stations:data:*`);
    const stations: StationEntity[] = [];
    
    for (const key of keys) {
      const results = await this.redis.hmget(key, ...ids);
      for (const data of results) {
        if (data) {
          try {
            stations.push(JSON.parse(data));
          } catch (e) {
            // Skip invalid data
          }
        }
      }
    }
    
    return stations;
  }

  // ==========================================================================
  // Session Operations
  // ==========================================================================

  /**
   * Store user session
   */
  async setSession(sessionId: string, data: object, ttl?: number): Promise<void> {
    const key = `${this.keyPrefix}sessions:${sessionId}`;
    await this.redis.setex(
      key,
      ttl || CACHE_TTL.SESSION,
      JSON.stringify(data)
    );
  }

  /**
   * Get user session
   */
  async getSession<T>(sessionId: string): Promise<T | null> {
    const key = `${this.keyPrefix}sessions:${sessionId}`;
    const data = await this.redis.get(key);
    if (!data) return null;
    
    try {
      return JSON.parse(data) as T;
    } catch {
      return null;
    }
  }

  /**
   * Delete user session
   */
  async deleteSession(sessionId: string): Promise<void> {
    const key = `${this.keyPrefix}sessions:${sessionId}`;
    await this.redis.del(key);
  }

  // ==========================================================================
  // Provider Health Operations
  // ==========================================================================

  /**
   * Update provider health status
   */
  async setProviderHealth(
    providerSlug: string,
    health: {
      isHealthy: boolean;
      lastCheck: Date;
      latencyMs: number;
      vehicleCount?: number;
      errorMessage?: string;
    }
  ): Promise<void> {
    const key = `${this.keyPrefix}health:${providerSlug}`;
    await this.redis.setex(key, 60, JSON.stringify(health));
  }

  /**
   * Get provider health status
   */
  async getProviderHealth(providerSlug: string): Promise<object | null> {
    const key = `${this.keyPrefix}health:${providerSlug}`;
    const data = await this.redis.get(key);
    return data ? JSON.parse(data) : null;
  }

  /**
   * Get all providers health status
   */
  async getAllProvidersHealth(): Promise<Map<string, object>> {
    const keys = await this.redis.keys(`${this.keyPrefix}health:*`);
    const result = new Map<string, object>();
    
    if (keys.length === 0) return result;
    
    const values = await this.redis.mget(...keys);
    
    for (let i = 0; i < keys.length; i++) {
      const slug = keys[i].replace(`${this.keyPrefix}health:`, '');
      if (values[i]) {
        result.set(slug, JSON.parse(values[i]!));
      }
    }
    
    return result;
  }

  // ==========================================================================
  // Pub/Sub for Real-time Updates
  // ==========================================================================

  /**
   * Publish vehicle update event
   */
  async publishVehicleUpdate(
    channel: string,
    data: { providerId: string; vehicles: UnifiedMapEntity[] }
  ): Promise<void> {
    await this.redis.publish(
      `${this.keyPrefix}${channel}`,
      JSON.stringify(data)
    );
  }

  /**
   * Subscribe to vehicle updates
   */
  async subscribeToUpdates(
    channel: string,
    callback: (data: any) => void
  ): Promise<void> {
    const subscriber = this.redis.duplicate();
    await subscriber.subscribe(`${this.keyPrefix}${channel}`);
    
    subscriber.on('message', (_channel: string, message: string) => {
      try {
        const data = JSON.parse(message);
        callback(data);
      } catch (e) {
        console.error('[Redis] Failed to parse message:', e);
      }
    });
  }

  // ==========================================================================
  // Utility Methods
  // ==========================================================================

  private getGeoKey(type: 'vehicles' | 'stations'): string {
    return `${this.keyPrefix}${type}:geo`;
  }

  private getDataKey(type: 'vehicles' | 'stations', providerId: string): string {
    return `${this.keyPrefix}${type}:data:${providerId}`;
  }

  private getBoundingBoxCenter(bbox: BoundingBox): GeoLocation {
    return {
      lat: (bbox.north + bbox.south) / 2,
      lng: (bbox.east + bbox.west) / 2,
    };
  }

  private getBoundingBoxRadius(bbox: BoundingBox): number {
    // Approximate radius to cover the bounding box (in meters)
    const latDiff = Math.abs(bbox.north - bbox.south);
    const lngDiff = Math.abs(bbox.east - bbox.west);
    const maxDiff = Math.max(latDiff, lngDiff);
    return maxDiff * 111320 * 0.7; // degrees to meters, with margin
  }

  private calculateBoxWidth(bbox: BoundingBox): number {
    return Math.abs(bbox.east - bbox.west) * 111;
  }

  private calculateBoxHeight(bbox: BoundingBox): number {
    return Math.abs(bbox.north - bbox.south) * 111;
  }

  /**
   * Get cache statistics
   */
  async getStats(): Promise<{
    vehicleCount: number;
    stationCount: number;
    memoryUsage: string;
  }> {
    const vehicleGeoKey = this.getGeoKey('vehicles');
    const stationGeoKey = this.getGeoKey('stations');
    
    const [vehicleCount, stationCount, info] = await Promise.all([
      this.redis.zcard(vehicleGeoKey),
      this.redis.zcard(stationGeoKey),
      this.redis.info('memory'),
    ]);
    
    const memoryMatch = info.match(/used_memory_human:(\S+)/);
    
    return {
      vehicleCount,
      stationCount,
      memoryUsage: memoryMatch?.[1] || 'unknown',
    };
  }

  /**
   * Flush all cache data
   */
  async flush(): Promise<void> {
    const keys = await this.redis.keys(`${this.keyPrefix}*`);
    if (keys.length > 0) {
      await this.redis.del(...keys);
    }
  }

  /**
   * Close Redis connection
   */
  async close(): Promise<void> {
    await this.redis.quit();
  }
}
