// ============================================================================
// MaaS Platform - Unified Entity Interfaces
// Common types for all mobility providers
// ============================================================================

/**
 * Types of mobility providers
 */
export type ProviderType = 'transit' | 'micromobility' | 'taxi' | 'carsharing';

/**
 * Types of vehicles across all providers
 */
export type VehicleType = 
  | 'bus' 
  | 'tram' 
  | 'metro' 
  | 'train' 
  | 'ferry'
  | 'scooter' 
  | 'bike' 
  | 'ebike' 
  | 'moped'
  | 'car'
  | 'taxi';

/**
 * Vehicle availability status
 */
export type VehicleStatus = 
  | 'available' 
  | 'reserved' 
  | 'in_use' 
  | 'maintenance' 
  | 'offline' 
  | 'low_battery';

/**
 * Geographic coordinate
 */
export interface GeoLocation {
  lat: number;
  lng: number;
}

/**
 * Bounding box for map queries
 */
export interface BoundingBox {
  north: number;
  south: number;
  east: number;
  west: number;
}

/**
 * Base interface for all map entities
 */
export interface BaseMapEntity {
  id: string;
  type: MapEntityType;
  provider: ProviderInfo;
  location: GeoLocation;
  lastUpdated: Date;
}

/**
 * Types of entities displayed on map
 */
export type MapEntityType = 
  | 'transit_stop' 
  | 'scooter' 
  | 'bike' 
  | 'ebike'
  | 'taxi_available'
  | 'bus_realtime'
  | 'tram_realtime'
  | 'station';

/**
 * Provider information
 */
export interface ProviderInfo {
  id: string;
  name: string;
  slug: string;
  type: ProviderType;
  color: string;
  logoUrl?: string;
}

// ============================================================================
// Transit (GTFS) Types
// ============================================================================

/**
 * Transit stop with departure information
 */
export interface TransitStopEntity extends BaseMapEntity {
  type: 'transit_stop';
  metadata: TransitStopMetadata;
}

export interface TransitStopMetadata {
  stopId: string;
  stopCode: string;
  stopName: string;
  routes: TransitRoute[];
  facilities: string[];
  wheelchairAccessible: boolean;
}

export interface TransitRoute {
  routeId: string;
  routeShortName: string;
  routeLongName: string;
  routeColor: string;
  routeTextColor: string;
  vehicleType: VehicleType;
  nextDepartures: TransitDeparture[];
}

export interface TransitDeparture {
  tripId: string;
  headsign: string;
  scheduledTime: Date;
  realtimeTime?: Date;
  delay?: number; // seconds
  status: 'scheduled' | 'on_time' | 'delayed' | 'cancelled';
}

/**
 * Real-time vehicle position (bus, tram, etc.)
 */
export interface TransitVehicleEntity extends BaseMapEntity {
  type: 'bus_realtime' | 'tram_realtime';
  metadata: TransitVehicleMetadata;
}

export interface TransitVehicleMetadata {
  vehicleId: string;
  tripId: string;
  routeId: string;
  routeShortName: string;
  routeColor: string;
  headsign: string;
  heading: number;
  speed: number;
  currentStopSequence: number;
  status: 'INCOMING_AT' | 'STOPPED_AT' | 'IN_TRANSIT_TO';
  delay?: number;
}

// ============================================================================
// Micromobility (GBFS) Types
// ============================================================================

/**
 * Micromobility vehicle (scooter, bike)
 */
export interface MicromobilityEntity extends BaseMapEntity {
  type: 'scooter' | 'bike' | 'ebike';
  metadata: MicromobilityMetadata;
}

export interface MicromobilityMetadata {
  vehicleId: string;
  vehicleCode: string;
  batteryLevel: number;
  estimatedRange: number; // meters
  pricing: VehiclePricing;
  deepLink: DeepLinkInfo;
  isReserved: boolean;
  isDisabled: boolean;
}

export interface VehiclePricing {
  unlockFee: number;
  perMinute: number;
  perKm?: number;
  currency: string;
}

export interface DeepLinkInfo {
  unlockUrl: string;
  appStoreUrl: string;
  playStoreUrl: string;
  webFallbackUrl: string;
}

/**
 * Docking station for bikes/scooters
 */
export interface StationEntity extends BaseMapEntity {
  type: 'station';
  metadata: StationMetadata;
}

export interface StationMetadata {
  stationId: string;
  name: string;
  address?: string;
  capacity: number;
  availableVehicles: number;
  availableDocks: number;
  vehicleTypes: VehicleType[];
  isRenting: boolean;
  isReturning: boolean;
}

// ============================================================================
// Taxi/Ride-hailing Types
// ============================================================================

/**
 * Available taxi vehicle
 */
export interface TaxiEntity extends BaseMapEntity {
  type: 'taxi_available';
  metadata: TaxiMetadata;
}

export interface TaxiMetadata {
  vehicleId: string;
  vehicleType: 'standard' | 'comfort' | 'xl' | 'premium';
  estimatedPickupTime: number; // minutes
  pricing: TaxiPricing;
  deepLink: DeepLinkInfo;
}

export interface TaxiPricing {
  baseFare: number;
  perKm: number;
  perMinute: number;
  minimumFare: number;
  currency: string;
  surgeMultiplier?: number;
}

// ============================================================================
// API Request/Response Types
// ============================================================================

/**
 * Map query request
 */
export interface MapQueryRequest {
  boundingBox: BoundingBox;
  entityTypes?: MapEntityType[];
  providers?: string[];
  limit?: number;
}

/**
 * Nearby search request
 */
export interface NearbySearchRequest {
  location: GeoLocation;
  radiusMeters: number;
  entityTypes?: MapEntityType[];
  providers?: string[];
  limit?: number;
}

/**
 * Unified map response
 */
export interface MapResponse {
  entities: UnifiedMapEntity[];
  meta: {
    totalCount: number;
    providers: string[];
    timestamp: Date;
    boundingBox?: BoundingBox;
  };
}

/**
 * Union type for all map entities
 */
export type UnifiedMapEntity = 
  | TransitStopEntity 
  | TransitVehicleEntity 
  | MicromobilityEntity 
  | StationEntity 
  | TaxiEntity;

// ============================================================================
// Trip Planning Types
// ============================================================================

export interface TripPlanRequest {
  origin: GeoLocation;
  destination: GeoLocation;
  departureTime?: Date;
  arrivalTime?: Date;
  modes?: VehicleType[];
  preferences?: TripPreferences;
}

export interface TripPreferences {
  maxWalkDistance?: number;
  preferredProviders?: string[];
  avoidProviders?: string[];
  wheelchairAccessible?: boolean;
  bikeFriendly?: boolean;
}

export interface TripPlanResponse {
  itineraries: Itinerary[];
  meta: {
    requestTime: Date;
    computeTimeMs: number;
  };
}

export interface Itinerary {
  id: string;
  legs: TripLeg[];
  totalDuration: number; // seconds
  totalDistance: number; // meters
  totalCost: CostEstimate;
  startTime: Date;
  endTime: Date;
}

export interface TripLeg {
  mode: VehicleType | 'walk';
  provider?: ProviderInfo;
  from: LegLocation;
  to: LegLocation;
  startTime: Date;
  endTime: Date;
  duration: number;
  distance: number;
  polyline: string; // encoded polyline
  instructions?: string[];
  cost?: CostEstimate;
  deepLink?: DeepLinkInfo;
}

export interface LegLocation {
  name: string;
  location: GeoLocation;
  stopId?: string;
}

export interface CostEstimate {
  min: number;
  max: number;
  currency: string;
}
