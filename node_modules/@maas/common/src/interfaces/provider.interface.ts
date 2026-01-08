// ============================================================================
// MaaS Platform - Provider Interface
// Contract for all mobility data providers
// ============================================================================

import { 
  ProviderType, 
  VehicleType, 
  GeoLocation, 
  BoundingBox,
  UnifiedMapEntity 
} from './unified-entity.interface';

/**
 * Configuration for a mobility provider
 */
export interface ProviderConfig {
  id: string;
  name: string;
  slug: string;
  type: ProviderType;
  
  // API Configuration
  apiBaseUrl?: string;
  apiKey?: string;
  apiVersion?: string;
  
  // GBFS/GTFS feeds
  gbfsFeedUrl?: string;
  gtfsFeedUrl?: string;
  gtfsRealtimeUrl?: string;
  
  // Deep linking
  deepLinkScheme?: string;
  deepLinkPatterns?: DeepLinkPatterns;
  appStoreUrl?: string;
  playStoreUrl?: string;
  webFallbackUrl?: string;
  
  // Branding
  primaryColor: string;
  secondaryColor?: string;
  logoUrl?: string;
  
  // Operational config
  pollingIntervalMs: number;
  isEnabled: boolean;
  supportedVehicleTypes: VehicleType[];
  coverageAreas?: CoverageArea[];
}

export interface DeepLinkPatterns {
  unlock?: string;  // Pattern with {vehicle_id}, {lat}, {lng} placeholders
  ride?: string;    // Pattern for taxi ride
  station?: string; // Pattern for station details
}

export interface CoverageArea {
  cityName: string;
  cityCode: string;
  boundingBox: BoundingBox;
}

/**
 * Interface that all provider adapters must implement
 */
export interface IProviderAdapter {
  /**
   * Provider configuration
   */
  readonly config: ProviderConfig;
  
  /**
   * Initialize the provider adapter
   */
  initialize(): Promise<void>;
  
  /**
   * Fetch current vehicle positions
   */
  fetchVehicles(boundingBox?: BoundingBox): Promise<UnifiedMapEntity[]>;
  
  /**
   * Fetch nearby vehicles from a point
   */
  fetchNearbyVehicles(
    location: GeoLocation, 
    radiusMeters: number
  ): Promise<UnifiedMapEntity[]>;
  
  /**
   * Check if provider is healthy and responding
   */
  healthCheck(): Promise<ProviderHealthStatus>;
  
  /**
   * Generate deep link for a specific action
   */
  generateDeepLink(action: DeepLinkAction): string;
  
  /**
   * Get last sync timestamp
   */
  getLastSyncTime(): Date | null;
  
  /**
   * Cleanup resources
   */
  dispose(): Promise<void>;
}

/**
 * Health status of a provider
 */
export interface ProviderHealthStatus {
  isHealthy: boolean;
  lastCheck: Date;
  lastSuccessfulSync?: Date;
  errorMessage?: string;
  latencyMs?: number;
  vehicleCount?: number;
}

/**
 * Deep link action types
 */
export type DeepLinkAction = 
  | { type: 'unlock_vehicle'; vehicleId: string; location?: GeoLocation }
  | { type: 'request_ride'; pickup: GeoLocation; destination?: GeoLocation }
  | { type: 'view_station'; stationId: string }
  | { type: 'open_app' };

/**
 * Provider registry interface
 */
export interface IProviderRegistry {
  /**
   * Register a provider adapter
   */
  register(adapter: IProviderAdapter): void;
  
  /**
   * Get provider by slug
   */
  get(slug: string): IProviderAdapter | undefined;
  
  /**
   * Get all providers of a specific type
   */
  getByType(type: ProviderType): IProviderAdapter[];
  
  /**
   * Get all enabled providers
   */
  getAllEnabled(): IProviderAdapter[];
  
  /**
   * Unregister a provider
   */
  unregister(slug: string): void;
}

/**
 * Event emitted when provider data changes
 */
export interface ProviderDataEvent {
  providerId: string;
  providerSlug: string;
  eventType: 'vehicles_updated' | 'stations_updated' | 'realtime_updated';
  entityCount: number;
  timestamp: Date;
  boundingBox?: BoundingBox;
}

/**
 * Base class for provider adapters
 */
export abstract class BaseProviderAdapter implements IProviderAdapter {
  protected lastSyncTime: Date | null = null;
  
  constructor(public readonly config: ProviderConfig) {}
  
  abstract initialize(): Promise<void>;
  abstract fetchVehicles(boundingBox?: BoundingBox): Promise<UnifiedMapEntity[]>;
  abstract fetchNearbyVehicles(location: GeoLocation, radiusMeters: number): Promise<UnifiedMapEntity[]>;
  abstract healthCheck(): Promise<ProviderHealthStatus>;
  abstract dispose(): Promise<void>;
  
  getLastSyncTime(): Date | null {
    return this.lastSyncTime;
  }
  
  generateDeepLink(action: DeepLinkAction): string {
    const { deepLinkScheme, deepLinkPatterns, webFallbackUrl } = this.config;
    
    if (!deepLinkScheme || !deepLinkPatterns) {
      return webFallbackUrl || '';
    }
    
    switch (action.type) {
      case 'unlock_vehicle':
        if (deepLinkPatterns.unlock) {
          let url = deepLinkPatterns.unlock
            .replace('{vehicle_id}', action.vehicleId);
          if (action.location) {
            url = url
              .replace('{lat}', action.location.lat.toString())
              .replace('{lng}', action.location.lng.toString());
          }
          return url;
        }
        break;
        
      case 'request_ride':
        if (deepLinkPatterns.ride) {
          let url = deepLinkPatterns.ride
            .replace('{pickup_lat}', action.pickup.lat.toString())
            .replace('{pickup_lng}', action.pickup.lng.toString());
          if (action.destination) {
            url = url
              .replace('{dest_lat}', action.destination.lat.toString())
              .replace('{dest_lng}', action.destination.lng.toString());
          }
          return url;
        }
        break;
        
      case 'view_station':
        if (deepLinkPatterns.station) {
          return deepLinkPatterns.station.replace('{station_id}', action.stationId);
        }
        break;
        
      case 'open_app':
        return `${deepLinkScheme}`;
    }
    
    return webFallbackUrl || '';
  }
  
  protected updateLastSyncTime(): void {
    this.lastSyncTime = new Date();
  }
}
