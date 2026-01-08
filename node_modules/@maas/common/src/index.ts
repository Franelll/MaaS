// ============================================================================
// MaaS Platform - Common Library Index
// ============================================================================

// Interfaces
export * from './interfaces/unified-entity.interface';
export * from './interfaces/provider.interface';

// DTOs will be added here
// export * from './dto';

// Utils will be added here  
// export * from './utils';

// Constants
export const DEFAULT_SEARCH_RADIUS_METERS = 500;
export const MAX_SEARCH_RADIUS_METERS = 5000;
export const DEFAULT_MAP_ENTITY_LIMIT = 100;

export const CACHE_TTL = {
  VEHICLES: 15,           // seconds
  STATIONS: 60,           // seconds
  GTFS_STATIC: 86400,     // 24 hours
  SESSION: 3600,          // 1 hour
  DEPARTURES: 30,         // seconds
} as const;

export const POLLING_INTERVALS = {
  GBFS: 10000,            // 10 seconds
  GTFS_REALTIME: 5000,    // 5 seconds
  TAXI: 30000,            // 30 seconds
} as const;

// Redis key prefixes
export const REDIS_KEYS = {
  VEHICLES: 'maas:vehicles:',
  VEHICLE_GEO: 'maas:vehicles:geo',
  STATIONS: 'maas:stations:',
  STATION_GEO: 'maas:stations:geo',
  GTFS_REALTIME: 'maas:gtfs:realtime:',
  SESSIONS: 'maas:sessions:',
  PROVIDER_HEALTH: 'maas:health:',
} as const;
