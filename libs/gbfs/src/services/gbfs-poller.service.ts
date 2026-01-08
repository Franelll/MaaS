// ============================================================================
// MaaS Platform - GBFS Service
// Handles polling and parsing of GBFS feeds for micromobility providers
// ============================================================================

/// <reference types="node" />
import { EventEmitter } from 'events';

// Type for NodeJS Timer
type TimerHandle = ReturnType<typeof setInterval> | null;
import {
  MicromobilityEntity,
  StationEntity,
  VehicleType,
  ProviderInfo,
  DeepLinkInfo,
} from '@maas/common';

/**
 * GBFS Feed URLs structure (as per GBFS 2.3 spec)
 */
export interface GBFSFeedUrls {
  systemInformation: string;
  stationInformation?: string;
  stationStatus?: string;
  freeBikeStatus?: string;
  vehicleTypes?: string;
  systemPricingPlans?: string;
  geofencingZones?: string;
}

/**
 * GBFS Vehicle from free_bike_status feed
 */
export interface GBFSVehicle {
  bike_id: string;
  lat: number;
  lon: number;
  is_reserved: boolean;
  is_disabled: boolean;
  vehicle_type_id?: string;
  last_reported?: number;
  current_range_meters?: number;
  current_fuel_percent?: number;
  station_id?: string;
  pricing_plan_id?: string;
  rental_uris?: {
    android?: string;
    ios?: string;
    web?: string;
  };
}

/**
 * GBFS Station from station_information feed
 */
export interface GBFSStation {
  station_id: string;
  name: string;
  lat: number;
  lon: number;
  address?: string;
  capacity?: number;
  rental_methods?: string[];
  is_charging_station?: boolean;
  is_virtual_station?: boolean;
}

/**
 * GBFS Station Status from station_status feed
 */
export interface GBFSStationStatus {
  station_id: string;
  num_bikes_available: number;
  num_docks_available?: number;
  is_renting: boolean;
  is_returning: boolean;
  last_reported: number;
  vehicle_types_available?: Array<{
    vehicle_type_id: string;
    count: number;
  }>;
}

/**
 * GBFS Vehicle Type
 */
export interface GBFSVehicleType {
  vehicle_type_id: string;
  form_factor: 'bicycle' | 'scooter' | 'car' | 'moped' | 'other';
  propulsion_type: 'human' | 'electric_assist' | 'electric' | 'combustion';
  max_range_meters?: number;
  name?: string;
}

/**
 * GBFS Pricing Plan
 */
export interface GBFSPricingPlan {
  plan_id: string;
  name: string;
  currency: string;
  price: number;
  is_taxable: boolean;
  description?: string;
  per_km_pricing?: Array<{
    start: number;
    rate: number;
    interval: number;
  }>;
  per_min_pricing?: Array<{
    start: number;
    rate: number;
    interval: number;
  }>;
}

/**
 * GBFS Poller Service Configuration
 */
export interface GBFSPollerConfig {
  providerId: string;
  providerSlug: string;
  providerName: string;
  providerColor: string;
  gbfsAutoDiscoveryUrl: string;
  pollingIntervalMs: number;
  deepLinkScheme?: string;
  deepLinkPattern?: string;
  appStoreUrl?: string;
  playStoreUrl?: string;
  webFallbackUrl?: string;
}

/**
 * GBFS Poller Service
 * Fetches and normalizes GBFS data from micromobility providers
 */
export class GBFSPollerService extends EventEmitter {
  private feedUrls: GBFSFeedUrls | null = null;
  private vehicleTypes: Map<string, GBFSVehicleType> = new Map();
  private pricingPlans: Map<string, GBFSPricingPlan> = new Map();
  private stations: Map<string, GBFSStation> = new Map();
  private pollingTimer: TimerHandle = null;
  private lastFetchTime: Date | null = null;
  private isPolling = false;

  constructor(private readonly config: GBFSPollerConfig) {
    super();
  }

  /**
   * Initialize the poller by fetching feed URLs and static data
   */
  async initialize(): Promise<void> {
    try {
      // Fetch auto-discovery URL to get all feed URLs
      this.feedUrls = await this.fetchFeedUrls();
      
      // Fetch static data (vehicle types, pricing, stations)
      await Promise.all([
        this.fetchVehicleTypes(),
        this.fetchPricingPlans(),
        this.fetchStationInformation(),
      ]);
      
      console.log(`[GBFS] ${this.config.providerSlug}: Initialized with ${this.vehicleTypes.size} vehicle types, ${this.pricingPlans.size} pricing plans`);
    } catch (error) {
      console.error(`[GBFS] ${this.config.providerSlug}: Initialization failed`, error);
      throw error;
    }
  }

  /**
   * Start polling for vehicle updates
   */
  startPolling(): void {
    if (this.isPolling) return;
    
    this.isPolling = true;
    this.poll();
    
    this.pollingTimer = setInterval(
      () => this.poll(),
      this.config.pollingIntervalMs
    );
    
    console.log(`[GBFS] ${this.config.providerSlug}: Started polling every ${this.config.pollingIntervalMs}ms`);
  }

  /**
   * Stop polling
   */
  stopPolling(): void {
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer);
      this.pollingTimer = null;
    }
    this.isPolling = false;
    console.log(`[GBFS] ${this.config.providerSlug}: Stopped polling`);
  }

  /**
   * Perform a single poll
   */
  private async poll(): Promise<void> {
    try {
      const startTime = Date.now();
      
      const [vehicles, stationStatuses] = await Promise.all([
        this.fetchFreeBikeStatus(),
        this.fetchStationStatus(),
      ]);
      
      const entities = this.normalizeVehicles(vehicles);
      const stationEntities = this.normalizeStations(stationStatuses);
      
      this.lastFetchTime = new Date();
      const latencyMs = Date.now() - startTime;
      
      this.emit('vehicles_updated', {
        providerId: this.config.providerId,
        providerSlug: this.config.providerSlug,
        vehicles: entities,
        stations: stationEntities,
        timestamp: this.lastFetchTime,
        latencyMs,
      });
      
    } catch (error) {
      console.error(`[GBFS] ${this.config.providerSlug}: Polling error`, error);
      this.emit('error', {
        providerId: this.config.providerId,
        providerSlug: this.config.providerSlug,
        error,
      });
    }
  }

  /**
   * Fetch GBFS auto-discovery to get all feed URLs
   */
  private async fetchFeedUrls(): Promise<GBFSFeedUrls> {
    const response = await fetch(this.config.gbfsAutoDiscoveryUrl);
    const data = await response.json() as {
      data?: {
        en?: { feeds?: Array<{ name: string; url: string }> };
        feeds?: Array<{ name: string; url: string }>;
      };
    };
    
    const feeds = data.data?.en?.feeds ?? data.data?.feeds ?? [];
    const urls: Partial<GBFSFeedUrls> = {};
    
    for (const feed of feeds) {
      switch (feed.name) {
        case 'system_information':
          urls.systemInformation = feed.url;
          break;
        case 'station_information':
          urls.stationInformation = feed.url;
          break;
        case 'station_status':
          urls.stationStatus = feed.url;
          break;
        case 'free_bike_status':
          urls.freeBikeStatus = feed.url;
          break;
        case 'vehicle_types':
          urls.vehicleTypes = feed.url;
          break;
        case 'system_pricing_plans':
          urls.systemPricingPlans = feed.url;
          break;
      }
    }
    
    if (!urls.systemInformation) {
      throw new Error('Missing required system_information feed');
    }
    
    return urls as GBFSFeedUrls;
  }

  /**
   * Fetch vehicle types
   */
  private async fetchVehicleTypes(): Promise<void> {
    if (!this.feedUrls?.vehicleTypes) return;
    
    try {
      const response = await fetch(this.feedUrls.vehicleTypes);
      const data = await response.json() as {
        data?: { vehicle_types?: GBFSVehicleType[] };
      };
      const types = data.data?.vehicle_types || [];
      
      this.vehicleTypes.clear();
      for (const type of types) {
        this.vehicleTypes.set(type.vehicle_type_id, type);
      }
    } catch (error) {
      console.warn(`[GBFS] ${this.config.providerSlug}: Failed to fetch vehicle types`, error);
    }
  }

  /**
   * Fetch pricing plans
   */
  private async fetchPricingPlans(): Promise<void> {
    if (!this.feedUrls?.systemPricingPlans) return;
    
    try {
      const response = await fetch(this.feedUrls.systemPricingPlans);
      const data = await response.json() as {
        data?: { plans?: GBFSPricingPlan[] };
      };
      const plans = data.data?.plans || [];
      
      this.pricingPlans.clear();
      for (const plan of plans) {
        this.pricingPlans.set(plan.plan_id, plan);
      }
    } catch (error) {
      console.warn(`[GBFS] ${this.config.providerSlug}: Failed to fetch pricing plans`, error);
    }
  }

  /**
   * Fetch station information
   */
  private async fetchStationInformation(): Promise<void> {
    if (!this.feedUrls?.stationInformation) return;
    
    try {
      const response = await fetch(this.feedUrls.stationInformation);
      const data = await response.json() as {
        data?: { stations?: GBFSStation[] };
      };
      const stations = data.data?.stations || [];
      
      this.stations.clear();
      for (const station of stations) {
        this.stations.set(station.station_id, station);
      }
    } catch (error) {
      console.warn(`[GBFS] ${this.config.providerSlug}: Failed to fetch station information`, error);
    }
  }

  /**
   * Fetch current free bike status
   */
  private async fetchFreeBikeStatus(): Promise<GBFSVehicle[]> {
    if (!this.feedUrls?.freeBikeStatus) return [];
    
    const response = await fetch(this.feedUrls.freeBikeStatus);
    const data = await response.json() as {
      data?: { bikes?: GBFSVehicle[] };
    };
    return data.data?.bikes || [];
  }

  /**
   * Fetch current station status
   */
  private async fetchStationStatus(): Promise<GBFSStationStatus[]> {
    if (!this.feedUrls?.stationStatus) return [];
    
    const response = await fetch(this.feedUrls.stationStatus);
    const data = await response.json() as {
      data?: { stations?: GBFSStationStatus[] };
    };
    return data.data?.stations || [];
  }

  /**
   * Normalize GBFS vehicles to unified format
   */
  private normalizeVehicles(vehicles: GBFSVehicle[]): MicromobilityEntity[] {
    const providerInfo: ProviderInfo = {
      id: this.config.providerId,
      name: this.config.providerName,
      slug: this.config.providerSlug,
      type: 'micromobility',
      color: this.config.providerColor,
    };

    return vehicles
      .filter(v => !v.is_disabled && !v.is_reserved)
      .map(vehicle => {
        const vehicleType = vehicle.vehicle_type_id 
          ? this.vehicleTypes.get(vehicle.vehicle_type_id)
          : null;
        
        const pricingPlan = vehicle.pricing_plan_id
          ? this.pricingPlans.get(vehicle.pricing_plan_id)
          : this.getDefaultPricingPlan();

        const entityType = this.mapVehicleTypeToEntityType(vehicleType);
        
        return {
          id: `${this.config.providerSlug}:${vehicle.bike_id}`,
          type: entityType,
          provider: providerInfo,
          location: {
            lat: vehicle.lat,
            lng: vehicle.lon,
          },
          lastUpdated: vehicle.last_reported 
            ? new Date(vehicle.last_reported * 1000)
            : new Date(),
          metadata: {
            vehicleId: vehicle.bike_id,
            vehicleCode: vehicle.bike_id.slice(-6).toUpperCase(),
            batteryLevel: vehicle.current_fuel_percent || 100,
            estimatedRange: vehicle.current_range_meters || 0,
            pricing: {
              unlockFee: this.extractUnlockFee(pricingPlan),
              perMinute: this.extractPerMinuteRate(pricingPlan),
              perKm: this.extractPerKmRate(pricingPlan),
              currency: pricingPlan?.currency || 'PLN',
            },
            deepLink: this.generateDeepLinkInfo(vehicle),
            isReserved: vehicle.is_reserved,
            isDisabled: vehicle.is_disabled,
          },
        } as MicromobilityEntity;
      });
  }

  /**
   * Normalize stations to unified format
   */
  private normalizeStations(statuses: GBFSStationStatus[]): StationEntity[] {
    const providerInfo: ProviderInfo = {
      id: this.config.providerId,
      name: this.config.providerName,
      slug: this.config.providerSlug,
      type: 'micromobility',
      color: this.config.providerColor,
    };

    return statuses.map(status => {
      const stationInfo = this.stations.get(status.station_id);
      if (!stationInfo) return null;

      return {
        id: `${this.config.providerSlug}:station:${status.station_id}`,
        type: 'station' as const,
        provider: providerInfo,
        location: {
          lat: stationInfo.lat,
          lng: stationInfo.lon,
        },
        lastUpdated: new Date(status.last_reported * 1000),
        metadata: {
          stationId: status.station_id,
          name: stationInfo.name,
          address: stationInfo.address,
          capacity: stationInfo.capacity || 0,
          availableVehicles: status.num_bikes_available,
          availableDocks: status.num_docks_available || 0,
          vehicleTypes: this.extractVehicleTypes(status.vehicle_types_available),
          isRenting: status.is_renting,
          isReturning: status.is_returning,
        },
      } as StationEntity;
    }).filter((s): s is StationEntity => s !== null);
  }

  /**
   * Map GBFS vehicle type to entity type
   */
  private mapVehicleTypeToEntityType(
    vehicleType: GBFSVehicleType | null | undefined
  ): 'scooter' | 'bike' | 'ebike' {
    if (!vehicleType) return 'scooter';
    
    switch (vehicleType.form_factor) {
      case 'bicycle':
        return vehicleType.propulsion_type === 'electric_assist' ? 'ebike' : 'bike';
      case 'scooter':
        return 'scooter';
      default:
        return 'scooter';
    }
  }

  /**
   * Generate deep link info for a vehicle
   */
  private generateDeepLinkInfo(vehicle: GBFSVehicle): DeepLinkInfo {
    let unlockUrl = this.config.webFallbackUrl || '';
    
    if (this.config.deepLinkScheme && this.config.deepLinkPattern) {
      unlockUrl = this.config.deepLinkPattern
        .replace('{vehicle_id}', vehicle.bike_id)
        .replace('{lat}', vehicle.lat.toString())
        .replace('{lng}', vehicle.lon.toString());
    } else if (vehicle.rental_uris?.android) {
      unlockUrl = vehicle.rental_uris.android;
    }
    
    return {
      unlockUrl,
      appStoreUrl: this.config.appStoreUrl || '',
      playStoreUrl: this.config.playStoreUrl || '',
      webFallbackUrl: vehicle.rental_uris?.web || this.config.webFallbackUrl || '',
    };
  }

  private getDefaultPricingPlan(): GBFSPricingPlan | undefined {
    return this.pricingPlans.values().next().value;
  }

  private extractUnlockFee(plan?: GBFSPricingPlan): number {
    return plan?.price || 0;
  }

  private extractPerMinuteRate(plan?: GBFSPricingPlan): number {
    const perMinPricing = plan?.per_min_pricing?.[0];
    return perMinPricing?.rate || 0;
  }

  private extractPerKmRate(plan?: GBFSPricingPlan): number {
    const perKmPricing = plan?.per_km_pricing?.[0];
    return perKmPricing?.rate || 0;
  }

  private extractVehicleTypes(
    available?: Array<{ vehicle_type_id: string; count: number }>
  ): VehicleType[] {
    if (!available) return ['scooter'];
    
    return available.map(a => {
      const type = this.vehicleTypes.get(a.vehicle_type_id);
      if (!type) return 'scooter';
      return this.mapVehicleTypeToEntityType(type) as VehicleType;
    });
  }

  /**
   * Get last fetch time
   */
  getLastFetchTime(): Date | null {
    return this.lastFetchTime;
  }

  /**
   * Check if service is healthy
   */
  async healthCheck(): Promise<{ isHealthy: boolean; latencyMs: number }> {
    const startTime = Date.now();
    try {
      await fetch(this.config.gbfsAutoDiscoveryUrl);
      return {
        isHealthy: true,
        latencyMs: Date.now() - startTime,
      };
    } catch {
      return {
        isHealthy: false,
        latencyMs: Date.now() - startTime,
      };
    }
  }
}
