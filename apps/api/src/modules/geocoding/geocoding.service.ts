// ============================================================================
// MaaS Platform - Geocoding Service
// Uses Photon API (Komoot) for address search with location bias
// ============================================================================

import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom, timeout, catchError } from 'rxjs';
import { AxiosError } from 'axios';

// ============================================================================
// Interfaces
// ============================================================================

export interface GeocodingResult {
  id: string;
  name: string;
  label: string;
  location: {
    lat: number;
    lng: number;
  };
  type: GeocodingResultType;
  distance?: number; // Distance from bias point in meters
  details?: {
    street?: string;
    houseNumber?: string;
    city?: string;
    district?: string;
    postcode?: string;
    country?: string;
  };
}

export type GeocodingResultType = 
  | 'address'
  | 'street'
  | 'city'
  | 'district'
  | 'poi'
  | 'stop'
  | 'station'
  | 'unknown';

export interface GeocodingOptions {
  query: string;
  lat?: number;        // Location bias latitude
  lon?: number;        // Location bias longitude
  limit?: number;      // Max results (default: 10)
}

export interface ReverseGeocodingOptions {
  lat: number;
  lon: number;
  radius?: number;     // Search radius in meters
}

// Photon API response types
interface PhotonFeature {
  type: 'Feature';
  geometry: {
    type: 'Point';
    coordinates: [number, number]; // [lon, lat]
  };
  properties: {
    osm_id: number;
    osm_type: string;
    osm_key: string;
    osm_value: string;
    name?: string;
    street?: string;
    housenumber?: string;
    city?: string;
    district?: string;
    locality?: string;
    postcode?: string;
    country?: string;
    countrycode?: string;
    state?: string;
    type?: string;
    extent?: [number, number, number, number];
  };
}

interface PhotonResponse {
  type: 'FeatureCollection';
  features: PhotonFeature[];
}

// ============================================================================
// Service Implementation
// ============================================================================

@Injectable()
export class GeocodingService {
  private readonly logger = new Logger(GeocodingService.name);
  
  // Photon API (free, no rate limits, OSM-based)
  private readonly photonUrl: string;

  // Default location bias (Warsaw center)
  private readonly defaultBias = {
    lat: 52.2297,
    lon: 21.0122,
  };

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
  ) {
    this.photonUrl = this.configService.get<string>(
      'PHOTON_URL',
      'https://photon.komoot.io',
    );
  }

  // ============================================================================
  // Forward Geocoding (Text → Coordinates)
  // ============================================================================

  /**
   * Search for addresses/places by text query
   */
  async search(options: GeocodingOptions): Promise<GeocodingResult[]> {
    const { 
      query, 
      lat = this.defaultBias.lat, 
      lon = this.defaultBias.lon,
      limit = 10,
    } = options;

    if (!query || query.trim().length < 2) {
      return [];
    }

    this.logger.debug(`Geocoding search: "${query}" with bias (${lat}, ${lon})`);

    try {
      // Build URL for Photon API
      // Note: Only use supported parameters (q, lat, lon, limit)
      const url = `${this.photonUrl}/api?q=${encodeURIComponent(query.trim())}&lat=${lat}&lon=${lon}&limit=${limit}`;
      
      this.logger.debug(`Photon API URL: ${url}`);
      
      const response = await firstValueFrom(
        this.httpService.get<PhotonResponse>(url, {
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'MaaS-Platform/1.0 (https://maas.local)',
          },
        }).pipe(
          timeout(8000),
          catchError((error: AxiosError) => {
            this.logger.error(`Photon API error: ${error.message}`);
            this.logger.error(`Photon API response: ${JSON.stringify(error.response?.data)}`);
            throw error;
          }),
        ),
      );

      const results = response.data.features.map((feature, index) => 
        this.mapPhotonFeature(feature, index, lat, lon),
      );

      this.logger.debug(`Found ${results.length} results for "${query}"`);
      return results;

    } catch (error) {
      this.logger.error(`Geocoding search failed for "${query}"`, error);
      return [];
    }
  }

  /**
   * Search specifically for transit stops (uses OTP or local DB)
   * Falls back to Photon for general POI
   */
  async searchStops(query: string, lat?: number, lon?: number): Promise<GeocodingResult[]> {
    // For transit stops, we could query OTP's stop index
    // For now, use Photon with railway/bus_stop filter
    const results = await this.search({
      query,
      lat,
      lon,
      limit: 15,
    });

    // Filter to likely transit stops
    return results.filter(r => 
      r.type === 'stop' || 
      r.type === 'station' ||
      r.name.toLowerCase().includes('przystanek') ||
      r.name.toLowerCase().includes('stacja') ||
      r.name.toLowerCase().includes('metro') ||
      r.name.toLowerCase().includes('dworzec'),
    );
  }

  // ============================================================================
  // Reverse Geocoding (Coordinates → Address)
  // ============================================================================

  /**
   * Get address for given coordinates
   */
  async reverse(options: ReverseGeocodingOptions): Promise<GeocodingResult | null> {
    const { lat, lon } = options;

    this.logger.debug(`Reverse geocoding: (${lat}, ${lon})`);

    try {
      const url = `${this.photonUrl}/reverse?lat=${lat}&lon=${lon}`;
      
      this.logger.debug(`Reverse geocode URL: ${url}`);
      
      const response = await firstValueFrom(
        this.httpService.get<PhotonResponse>(url, {
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'MaaS-Platform/1.0',
          },
        }).pipe(
          timeout(5000),
          catchError((error: AxiosError) => {
            this.logger.error(`Reverse geocoding error: ${error.message}`);
            throw error;
          }),
        ),
      );

      if (response.data.features.length === 0) {
        return null;
      }

      return this.mapPhotonFeature(response.data.features[0], 0, lat, lon);

    } catch (error) {
      this.logger.error(`Reverse geocoding failed for (${lat}, ${lon})`, error);
      return null;
    }
  }

  // ============================================================================
  // Autocomplete (Optimized for typing)
  // ============================================================================

  /**
   * Fast autocomplete for search-as-you-type
   * Uses smaller limit and caches common queries
   */
  async autocomplete(
    query: string,
    lat?: number,
    lon?: number,
  ): Promise<GeocodingResult[]> {
    if (query.length < 2) {
      return [];
    }

    // Use search with smaller limit for autocomplete
    return this.search({
      query,
      lat,
      lon,
      limit: 5,
    });
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  /**
   * Map Photon feature to our GeocodingResult format
   */
  private mapPhotonFeature(
    feature: PhotonFeature,
    _index: number,
    biasLat: number,
    biasLon: number,
  ): GeocodingResult {
    const [lon, lat] = feature.geometry.coordinates;
    const props = feature.properties;

    // Build human-readable label
    const label = this.buildLabel(props);
    
    // Determine result type
    const type = this.determineType(props);

    // Calculate distance from bias point
    const distance = this.calculateDistance(biasLat, biasLon, lat, lon);

    return {
      id: `photon-${props.osm_type}-${props.osm_id}`,
      name: props.name || props.street || label.split(',')[0],
      label,
      location: { lat, lng: lon },
      type,
      distance,
      details: {
        street: props.street,
        houseNumber: props.housenumber,
        city: props.city || props.locality,
        district: props.district,
        postcode: props.postcode,
        country: props.country,
      },
    };
  }

  /**
   * Build human-readable address label
   */
  private buildLabel(props: PhotonFeature['properties']): string {
    const parts: string[] = [];

    // Primary name
    if (props.name) {
      parts.push(props.name);
    }

    // Street address
    if (props.street) {
      const streetPart = props.housenumber 
        ? `${props.street} ${props.housenumber}`
        : props.street;
      if (!parts.includes(streetPart)) {
        parts.push(streetPart);
      }
    }

    // City/locality
    const city = props.city || props.locality;
    if (city && !parts.some(p => p.includes(city))) {
      if (props.district && props.district !== city) {
        parts.push(`${props.district}, ${city}`);
      } else {
        parts.push(city);
      }
    }

    return parts.join(', ') || 'Nieznana lokalizacja';
  }

  /**
   * Determine the type of geocoding result
   */
  private determineType(props: PhotonFeature['properties']): GeocodingResultType {
    const osmKey = props.osm_key?.toLowerCase() || '';
    const osmValue = props.osm_value?.toLowerCase() || '';
    const name = props.name?.toLowerCase() || '';

    // Transit stops
    if (osmKey === 'railway' || osmKey === 'public_transport') {
      if (osmValue.includes('station') || osmValue.includes('halt')) {
        return 'station';
      }
      if (osmValue.includes('stop') || osmValue.includes('platform')) {
        return 'stop';
      }
    }
    if (osmKey === 'highway' && osmValue === 'bus_stop') {
      return 'stop';
    }
    if (name.includes('metro') || name.includes('stacja')) {
      return 'station';
    }

    // Places
    if (osmKey === 'place') {
      if (osmValue === 'city' || osmValue === 'town') {
        return 'city';
      }
      if (osmValue === 'suburb' || osmValue === 'neighbourhood') {
        return 'district';
      }
    }

    // Addresses
    if (props.housenumber || (osmKey === 'building')) {
      return 'address';
    }
    if (props.street && !props.name) {
      return 'street';
    }

    // POIs
    if (osmKey === 'amenity' || osmKey === 'shop' || osmKey === 'tourism') {
      return 'poi';
    }

    return 'unknown';
  }

  /**
   * Calculate distance between two points (Haversine)
   */
  private calculateDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const R = 6371000; // Earth's radius in meters
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = 
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.round(R * c);
  }
}
