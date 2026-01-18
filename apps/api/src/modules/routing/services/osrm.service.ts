// ============================================================================
// MaaS Platform - OSRM Routing Service
// Fetches real street geometry using OSRM (Open Source Routing Machine)
// ============================================================================

import { Injectable, Logger } from '@nestjs/common';

export interface OsrmRoute {
  geometry: string; // Encoded polyline
  distance: number; // meters
  duration: number; // seconds
  legs: OsrmLeg[];
}

export interface OsrmLeg {
  distance: number;
  duration: number;
  steps: OsrmStep[];
}

export interface OsrmStep {
  geometry: string;
  distance: number;
  duration: number;
  name: string;
  maneuver: {
    type: string;
    modifier?: string;
    location: [number, number];
  };
}

export interface OsrmResponse {
  code: string;
  routes: OsrmRoute[];
}

@Injectable()
export class OsrmService {
  private readonly logger = new Logger(OsrmService.name);
  
  // Public OSRM demo server (for development only)
  // For production, deploy your own OSRM instance
  private readonly osrmBaseUrl = 'https://router.project-osrm.org';

  /**
   * Get walking route geometry between two points
   */
  async getWalkingRoute(
    origin: { lat: number; lng: number },
    destination: { lat: number; lng: number },
  ): Promise<OsrmRoute | null> {
    return this.getRoute(origin, destination, 'foot');
  }

  /**
   * Get driving route geometry between two points
   * (Used as approximation for bus/tram routes)
   */
  async getDrivingRoute(
    origin: { lat: number; lng: number },
    destination: { lat: number; lng: number },
  ): Promise<OsrmRoute | null> {
    return this.getRoute(origin, destination, 'driving');
  }

  /**
   * Get cycling route geometry between two points
   * (Used for bikes and scooters)
   */
  async getCyclingRoute(
    origin: { lat: number; lng: number },
    destination: { lat: number; lng: number },
  ): Promise<OsrmRoute | null> {
    return this.getRoute(origin, destination, 'bike');
  }

  /**
   * Get route between two points using specified profile
   */
  private async getRoute(
    origin: { lat: number; lng: number },
    destination: { lat: number; lng: number },
    profile: 'foot' | 'driving' | 'bike',
  ): Promise<OsrmRoute | null> {
    try {
      // OSRM uses lng,lat order (opposite to most other APIs)
      const coordinates = `${origin.lng},${origin.lat};${destination.lng},${destination.lat}`;
      const url = `${this.osrmBaseUrl}/route/v1/${profile}/${coordinates}?overview=full&geometries=polyline&steps=true`;

      const start = Date.now();
      this.logger.debug(`OSRM request start: ${url}`);

      const controller = new AbortController();
      const timeoutMs = 5000;
      const timeout = setTimeout(() => controller.abort(), timeoutMs);

      let response;
      try {
        response = await fetch(url, {
          headers: {
            'User-Agent': 'MaaS-Platform/1.0',
          },
          signal: controller.signal as any,
        });
      } catch (err: unknown) {
        const elapsedErr = Date.now() - start;
        const message = err instanceof Error ? err.message : String(err);
        this.logger.warn(`OSRM fetch error: ${message} timeMs=${elapsedErr}`);
        clearTimeout(timeout);
        return null;
      }

      clearTimeout(timeout);
      const elapsed = Date.now() - start;
      this.logger.debug(`OSRM request finished: ${url} status=${response.status} timeMs=${elapsed}`);

      if (!response.ok) {
        this.logger.warn(`OSRM request failed: ${response.status}`);
        return null;
      }

      const data = (await response.json()) as OsrmResponse;

      if (data.code !== 'Ok' || !data.routes?.length) {
        this.logger.warn(`OSRM returned no routes: ${data.code}`);
        return null;
      }

      return data.routes[0];
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`OSRM error: ${message}`);
      return null;
    }
  }

  /**
   * Get route with waypoints (for multi-stop routes)
   */
  async getRouteWithWaypoints(
    waypoints: Array<{ lat: number; lng: number }>,
    profile: 'foot' | 'driving' | 'bike' = 'driving',
  ): Promise<OsrmRoute | null> {
    if (waypoints.length < 2) {
      return null;
    }

    try {
      const coordinates = waypoints
        .map(wp => `${wp.lng},${wp.lat}`)
        .join(';');
      
      const url = `${this.osrmBaseUrl}/route/v1/${profile}/${coordinates}?overview=full&geometries=polyline&steps=true`;

      const start = Date.now();
      this.logger.debug(`OSRM waypoints request start: ${url}`);

      const controller = new AbortController();
      const timeoutMs = 5000;
      const timeout = setTimeout(() => controller.abort(), timeoutMs);

      let response;
      try {
        response = await fetch(url, {
          headers: {
            'User-Agent': 'MaaS-Platform/1.0',
          },
          signal: controller.signal as any,
        });
      } catch (err: unknown) {
        const elapsedErr = Date.now() - start;
        const message = err instanceof Error ? err.message : String(err);
        this.logger.warn(`OSRM waypoints fetch error: ${message} timeMs=${elapsedErr}`);
        clearTimeout(timeout);
        return null;
      }

      clearTimeout(timeout);
      const elapsed = Date.now() - start;
      this.logger.debug(`OSRM waypoints request finished: ${url} status=${response.status} timeMs=${elapsed}`);

      if (!response.ok) {
        return null;
      }

      const data = (await response.json()) as OsrmResponse;

      if (data.code !== 'Ok' || !data.routes?.length) {
        return null;
      }

      return data.routes[0];
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`OSRM waypoints error: ${message}`);
      return null;
    }
  }

  /**
   * Check if OSRM service is available
   */
  async healthCheck(): Promise<boolean> {
    try {
      // Test with a simple route in Warsaw
      const route = await this.getRoute(
        { lat: 52.2297, lng: 21.0122 },
        { lat: 52.2317, lng: 21.0142 },
        'driving',
      );
      return route !== null;
    } catch {
      return false;
    }
  }
}
