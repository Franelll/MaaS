// ============================================================================
// MaaS Platform - Trip Planner Service
// Main service for multimodal trip planning
// ============================================================================

import { Injectable, Logger } from '@nestjs/common';
import { OtpGraphqlClient } from './otp-graphql.client';
import {
  TripPlanRequestDto,
  PlannedRouteDto,
  RouteSegmentDto,
  SegmentType,
  OptimizationMode,
} from '../dto/trip-plan.dto';
import {
  OtpPlanResponse,
  OtpItinerary,
  OtpLeg,
  OtpMode,
  OtpPlanQueryVariables,
  OtpTransportMode,
} from '../interfaces/otp-response.interface';

@Injectable()
export class TripPlannerService {
  private readonly logger = new Logger(TripPlannerService.name);
  private otpAvailable = false;

  // Mode icon mapping for summary generation

  constructor(private readonly otpClient: OtpGraphqlClient) {
    // Check OTP availability on startup
    this.checkOtpAvailability();
  }

  private async checkOtpAvailability(): Promise<void> {
    this.otpAvailable = await this.otpClient.healthCheck();
    if (!this.otpAvailable) {
      this.logger.warn('⚠️ OTP not available - using mock routing fallback');
    }
  }

  /**
   * Plan a multimodal trip
   */
  async planTrip(request: TripPlanRequestDto): Promise<PlannedRouteDto[]> {
    this.logger.log(`Planning trip with preferences: ${JSON.stringify(request.preferences)}`);

    // Fallback to mock if OTP not available
    if (!this.otpAvailable) {
      this.logger.log('Using mock routing (OTP unavailable)');
      return this.generateMockRoutes(request);
    }

    // Build OTP query variables based on request
    const variables = this.buildQueryVariables(request);

    // Execute OTP query
    let response: OtpPlanResponse;
    try {
      response = await this.otpClient.planTrip(variables);
    } catch (error) {
      this.logger.error('Failed to get trip plan from OTP', error);
      // Fall back to mock routing instead of throwing
      this.logger.warn('Falling back to mock routing');
      return this.generateMockRoutes(request);
    }

    // Check for routing errors
    if (response.data?.plan?.routingErrors?.length) {
      const errors = response.data.plan.routingErrors;
      this.logger.warn(`OTP returned routing errors: ${JSON.stringify(errors)}`);
      
      // Check for specific error types
      const noPathError = errors.find(e => e.code === 'NO_TRANSIT_CONNECTION' || e.code === 'NO_STOPS_IN_RANGE');
      if (noPathError) {
        return []; // Return empty routes if no path found
      }
    }

    // Parse and map itineraries to our format
    const itineraries = response.data?.plan?.itineraries ?? [];
    
    if (itineraries.length === 0) {
      this.logger.warn('No itineraries found for the requested trip');
      return [];
    }

    return itineraries.map((itinerary, index) => this.mapItineraryToRoute(itinerary, index));
  }

  /**
   * Build OTP query variables from request
   */
  private buildQueryVariables(request: TripPlanRequestDto): OtpPlanQueryVariables {
    const preferences = request.preferences ?? {};
    const mode = preferences.mode ?? OptimizationMode.FASTEST;

    // Determine transport modes to include
    const transportModes = this.buildTransportModes(preferences);

    // Determine walk reluctance based on optimization mode
    const walkReluctance = this.getWalkReluctance(mode, preferences);

    // Parse date and time
    const { date, time, arriveBy } = this.parseDateTimeOptions(request);

    return {
      from: {
        lat: request.origin.lat,
        lon: request.origin.lng,
      },
      to: {
        lat: request.destination.lat,
        lon: request.destination.lng,
      },
      date,
      time,
      arriveBy,
      numItineraries: preferences.numAlternatives ?? 5,
      transportModes,
      walkReluctance,
      wheelchair: preferences.wheelchairAccessible ?? false,
      maxWalkDistance: preferences.maxWalkDistance ?? 1000,
    };
  }

  /**
   * Build transport modes array based on preferences
   */
  private buildTransportModes(preferences: TripPlanRequestDto['preferences']): OtpTransportMode[] {
    const modes: OtpTransportMode[] = [
      { mode: 'WALK' },
      { mode: 'TRANSIT' }, // Includes all public transport
    ];

    // Add bike rental if allowed
    if (preferences?.allowBikes !== false) {
      modes.push({ mode: 'BICYCLE', qualifier: 'RENT' });
    }

    // Add scooter rental if allowed
    if (preferences?.allowScooters !== false) {
      modes.push({ mode: 'SCOOTER', qualifier: 'RENT' });
    }

    return modes;
  }

  /**
   * Get walk reluctance based on optimization mode
   * Higher values = less walking preferred
   */
  private getWalkReluctance(
    mode: OptimizationMode,
    preferences: TripPlanRequestDto['preferences'],
  ): number {
    // If micromobility is allowed, increase walk reluctance to prefer vehicles
    const hasMicromobility = 
      (preferences?.allowScooters !== false) || 
      (preferences?.allowBikes !== false);

    switch (mode) {
      case OptimizationMode.FASTEST:
        // High reluctance = prefer vehicles over walking
        return hasMicromobility ? 3.5 : 2.0;

      case OptimizationMode.CHEAPEST:
        // Low reluctance = walking is fine (it's free)
        return 1.5;

      case OptimizationMode.COMFORTABLE:
        // Medium reluctance = balanced
        return 2.5;

      default:
        return 2.0;
    }
  }

  /**
   * Parse departure/arrival time options
   */
  private parseDateTimeOptions(request: TripPlanRequestDto): {
    date?: string;
    time?: string;
    arriveBy: boolean;
  } {
    let dateTime: Date;
    let arriveBy = false;

    if (request.arrivalTime) {
      dateTime = new Date(request.arrivalTime);
      arriveBy = true;
    } else if (request.departureTime) {
      dateTime = new Date(request.departureTime);
    } else {
      dateTime = new Date();
    }

    // Format for OTP: date = "2026-01-09", time = "08:30"
    const date = dateTime.toISOString().split('T')[0];
    const time = dateTime.toTimeString().slice(0, 5);

    return { date, time, arriveBy };
  }

  /**
   * Map OTP itinerary to our PlannedRouteDto format
   */
  private mapItineraryToRoute(itinerary: OtpItinerary, index: number): PlannedRouteDto {
    const segments = itinerary.legs.map(leg => this.mapLegToSegment(leg));
    const summary = this.generateRouteSummary(segments);
    const totalCost = this.calculateTotalCost(segments);

    return {
      id: `route-${index + 1}`,
      summary,
      duration: itinerary.duration,
      walkTime: itinerary.walkTime,
      waitTime: itinerary.waitingTime,
      walkDistance: itinerary.walkDistance,
      transfers: itinerary.transfers,
      estimatedCost: totalCost,
      departureTime: new Date(itinerary.startTime).toISOString(),
      arrivalTime: new Date(itinerary.endTime).toISOString(),
      score: {
        overall: 0, // Will be calculated by RouteScoringService
        time: 0,
        cost: 0,
        comfort: 0,
      },
      segments,
    };
  }

  /**
   * Map OTP leg to RouteSegmentDto
   */
  private mapLegToSegment(leg: OtpLeg): RouteSegmentDto {
    const segmentType = this.mapOtpModeToSegmentType(leg.mode);
    const cost = this.estimateSegmentCost(leg, segmentType);

    const segment: RouteSegmentDto = {
      type: segmentType,
      from: {
        name: leg.from.name || 'Start',
        location: {
          lat: leg.from.lat,
          lng: leg.from.lon,
        },
        stopId: leg.from.stop?.gtfsId,
        stationId: leg.from.vehicleRentalStation?.stationId,
      },
      to: {
        name: leg.to.name || 'End',
        location: {
          lat: leg.to.lat,
          lng: leg.to.lon,
        },
        stopId: leg.to.stop?.gtfsId,
        stationId: leg.to.vehicleRentalStation?.stationId,
      },
      duration: leg.duration,
      distance: leg.distance,
      polyline: leg.legGeometry.points,
      cost,
      isRented: leg.rentedBike,
    };

    // Add transit-specific info
    if (leg.route) {
      segment.line = {
        name: leg.route.shortName || leg.routeShortName || '',
        longName: leg.route.longName || leg.routeLongName,
        color: leg.route.color ? `#${leg.route.color}` : '#666666',
        agency: leg.route.agency?.name || leg.agency?.name,
      };
      segment.departureTime = new Date(leg.startTime).toISOString();
      segment.arrivalTime = new Date(leg.endTime).toISOString();
      
      if (leg.intermediateStops) {
        segment.numStops = leg.intermediateStops.length;
      }
    }

    // Add provider for micromobility
    if (segmentType === SegmentType.SCOOTER || segmentType === SegmentType.BIKE) {
      segment.provider = this.detectProvider(leg);
    }

    // Add walking instructions
    if (segmentType === SegmentType.WALK && leg.steps?.length) {
      segment.instructions = leg.steps.map(step => ({
        text: this.formatStepInstruction(step.relativeDirection, step.streetName),
        distance: step.distance,
        direction: step.relativeDirection,
        streetName: step.streetName,
      }));
    }

    return segment;
  }

  /**
   * Map OTP mode to our SegmentType
   */
  private mapOtpModeToSegmentType(mode: OtpMode): SegmentType {
    switch (mode) {
      case 'WALK':
        return SegmentType.WALK;
      case 'BUS':
        return SegmentType.BUS;
      case 'TRAM':
        return SegmentType.TRAM;
      case 'SUBWAY':
        return SegmentType.METRO;
      case 'RAIL':
        return SegmentType.RAIL;
      case 'BICYCLE':
      case 'BICYCLE_RENT':
        return SegmentType.BIKE;
      case 'SCOOTER_RENT':
        return SegmentType.SCOOTER;
      case 'CAR':
      case 'CAR_PARK':
        return SegmentType.CAR;
      default:
        return SegmentType.WALK;
    }
  }

  /**
   * Detect provider from OTP leg data
   */
  private detectProvider(leg: OtpLeg): string {
    // Check rental vehicle network
    if (leg.from.rentalVehicle?.network) {
      return leg.from.rentalVehicle.network;
    }
    
    // Check rental station network
    if (leg.from.vehicleRentalStation?.network) {
      return leg.from.vehicleRentalStation.network;
    }

    // Default providers
    if (leg.mode === 'SCOOTER_RENT') {
      return 'bolt-scooters';
    }
    if (leg.mode === 'BICYCLE_RENT' || leg.mode === 'BICYCLE') {
      return 'veturilo-bikes';
    }

    return 'unknown';
  }

  /**
   * Estimate cost for a single segment
   */
  private estimateSegmentCost(leg: OtpLeg, segmentType: SegmentType): number {
    const durationMinutes = leg.duration / 60;

    switch (segmentType) {
      case SegmentType.WALK:
        return 0;

      case SegmentType.BUS:
      case SegmentType.TRAM:
      case SegmentType.METRO:
        // ZTM Warsaw single ticket (simplified - should track zones)
        return 4.40;

      case SegmentType.RAIL:
        // KM/SKM ticket
        return 4.40;

      case SegmentType.SCOOTER:
        // Bolt pricing: 3.49 unlock + 0.69/min
        return 3.49 + durationMinutes * 0.69;

      case SegmentType.BIKE:
        // Veturilo: first 20 min free, then 4 PLN/hour
        if (durationMinutes <= 20) {
          return 0;
        }
        const additionalHours = Math.ceil((durationMinutes - 20) / 60);
        return additionalHours * 4.0;

      default:
        return 0;
    }
  }

  /**
   * Calculate total cost for all segments
   * Applies transit fare capping (single ticket covers transfers)
   */
  private calculateTotalCost(segments: RouteSegmentDto[]): number {
    let total = 0;
    let hasTransit = false;

    for (const segment of segments) {
      if ([SegmentType.BUS, SegmentType.TRAM, SegmentType.METRO, SegmentType.RAIL].includes(segment.type)) {
        // Only count transit fare once (transfer included in ticket)
        if (!hasTransit) {
          total += segment.cost;
          hasTransit = true;
        }
      } else {
        total += segment.cost;
      }
    }

    return Math.round(total * 100) / 100;
  }

  /**
   * Generate human-readable route summary
   */
  private generateRouteSummary(segments: RouteSegmentDto[]): string {
    const significantModes = segments
      .filter(s => s.type !== SegmentType.WALK || s.duration > 120) // Skip short walks
      .map(s => this.getModeLabel(s.type));

    // Deduplicate consecutive same modes
    const dedupedModes: string[] = [];
    for (const mode of significantModes) {
      if (dedupedModes.length === 0 || dedupedModes[dedupedModes.length - 1] !== mode) {
        dedupedModes.push(mode);
      }
    }

    return dedupedModes.join(' → ') || 'Walk';
  }

  /**
   * Get human-readable label for mode
   */
  private getModeLabel(type: SegmentType): string {
    const labels: Record<SegmentType, string> = {
      [SegmentType.WALK]: 'Spacer',
      [SegmentType.BUS]: 'Autobus',
      [SegmentType.TRAM]: 'Tramwaj',
      [SegmentType.METRO]: 'Metro',
      [SegmentType.RAIL]: 'Kolej',
      [SegmentType.SCOOTER]: 'Hulajnoga',
      [SegmentType.BIKE]: 'Rower',
      [SegmentType.TAXI]: 'Taxi',
      [SegmentType.CAR]: 'Samochód',
    };
    return labels[type] || type;
  }

  /**
   * Format step instruction
   */
  private formatStepInstruction(direction: string, streetName: string): string {
    const directionMap: Record<string, string> = {
      'DEPART': 'Wyjdź',
      'HARD_LEFT': 'Skręć ostro w lewo',
      'LEFT': 'Skręć w lewo',
      'SLIGHTLY_LEFT': 'Skręć lekko w lewo',
      'CONTINUE': 'Idź prosto',
      'SLIGHTLY_RIGHT': 'Skręć lekko w prawo',
      'RIGHT': 'Skręć w prawo',
      'HARD_RIGHT': 'Skręć ostro w prawo',
      'UTURN_LEFT': 'Zawróć w lewo',
      'UTURN_RIGHT': 'Zawróć w prawo',
      'ELEVATOR': 'Użyj windy',
      'ENTER_STATION': 'Wejdź na stację',
      'EXIT_STATION': 'Wyjdź ze stacji',
    };

    const directionText = directionMap[direction] || 'Kontynuuj';
    
    if (streetName && streetName !== 'unnamed path') {
      return `${directionText} na ${streetName}`;
    }
    
    return directionText;
  }

  /**
   * Check if OTP is healthy
   */
  async checkOtpHealth(): Promise<boolean> {
    return this.otpClient.healthCheck();
  }

  /**
   * Generate mock routes when OTP is unavailable
   * Creates realistic looking routes for testing
   */
  private generateMockRoutes(request: TripPlanRequestDto): PlannedRouteDto[] {
    const { origin, destination } = request;
    const now = new Date();
    
    // Calculate rough distance between points (Haversine approximation)
    const R = 6371000; // Earth radius in meters
    const dLat = (destination.lat - origin.lat) * Math.PI / 180;
    const dLng = (destination.lng - origin.lng) * Math.PI / 180;
    const lat1 = origin.lat * Math.PI / 180;
    const lat2 = destination.lat * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng/2) * Math.sin(dLng/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const distance = R * c;

    // Generate simple polyline (just straight line for mock)
    const polyline = this.generateSimplePolyline(origin, destination);

    // Generate 3 mock routes with different modes
    const routes: PlannedRouteDto[] = [];

    // Route 1: Transit (Bus/Tram)
    const transitDuration = Math.round(distance / 10) + 300; // ~36 km/h avg + 5 min walk
    
    // Generate polylines for each segment
    const walkToStop = this.generateSimplePolyline(
      { lat: origin.lat, lng: origin.lng },
      { lat: origin.lat + 0.001, lng: origin.lng + 0.001 }
    );
    const busRide = this.generateSimplePolyline(
      { lat: origin.lat + 0.001, lng: origin.lng + 0.001 },
      { lat: destination.lat - 0.001, lng: destination.lng - 0.001 }
    );
    const walkFromStop = this.generateSimplePolyline(
      { lat: destination.lat - 0.001, lng: destination.lng - 0.001 },
      { lat: destination.lat, lng: destination.lng }
    );
    
    routes.push({
      id: 'route-1',
      summary: 'Spacer → Autobus → Spacer',
      duration: transitDuration,
      walkTime: 300,
      waitTime: 180,
      walkDistance: 400,
      transfers: 0,
      estimatedCost: 4.40,
      departureTime: now.toISOString(),
      arrivalTime: new Date(now.getTime() + transitDuration * 1000).toISOString(),
      score: { overall: 85, time: 80, cost: 90, comfort: 85 },
      segments: [
        {
          type: SegmentType.WALK,
          from: { name: 'Start', location: { lat: origin.lat, lng: origin.lng } },
          to: { name: 'Przystanek', location: { lat: origin.lat + 0.001, lng: origin.lng + 0.001 } },
          duration: 150,
          distance: 200,
          polyline: walkToStop,
          cost: 0,
        },
        {
          type: SegmentType.BUS,
          from: { name: 'Przystanek A', location: { lat: origin.lat + 0.001, lng: origin.lng + 0.001 } },
          to: { name: 'Przystanek B', location: { lat: destination.lat - 0.001, lng: destination.lng - 0.001 } },
          duration: transitDuration - 300,
          distance: distance - 400,
          polyline: busRide,
          cost: 4.40,
          line: { name: '180', longName: 'Centrum - Żoliborz', color: '#CC0000', agency: 'ZTM Warszawa' },
          departureTime: new Date(now.getTime() + 180000).toISOString(),
          arrivalTime: new Date(now.getTime() + (transitDuration - 150) * 1000).toISOString(),
          numStops: Math.max(3, Math.round(distance / 500)),
        },
        {
          type: SegmentType.WALK,
          from: { name: 'Przystanek', location: { lat: destination.lat - 0.001, lng: destination.lng - 0.001 } },
          to: { name: 'Cel', location: { lat: destination.lat, lng: destination.lng } },
          duration: 150,
          distance: 200,
          polyline: walkFromStop,
          cost: 0,
        },
      ],
    });

    // Route 2: E-Scooter
    const scooterDuration = Math.round(distance / 5); // ~18 km/h
    const scooterCost = 3.49 + (scooterDuration / 60) * 0.69;
    
    // Generate polylines for scooter route
    const walkToScooter = this.generateSimplePolyline(
      { lat: origin.lat, lng: origin.lng },
      { lat: origin.lat + 0.0005, lng: origin.lng + 0.0005 }
    );
    const scooterRide = this.generateSimplePolyline(
      { lat: origin.lat + 0.0005, lng: origin.lng + 0.0005 },
      { lat: destination.lat - 0.0005, lng: destination.lng - 0.0005 }
    );
    const walkFromScooter = this.generateSimplePolyline(
      { lat: destination.lat - 0.0005, lng: destination.lng - 0.0005 },
      { lat: destination.lat, lng: destination.lng }
    );
    
    routes.push({
      id: 'route-2',
      summary: 'Spacer → Hulajnoga → Spacer',
      duration: scooterDuration + 180,
      walkTime: 180,
      waitTime: 0,
      walkDistance: 200,
      transfers: 0,
      estimatedCost: Math.round(scooterCost * 100) / 100,
      departureTime: now.toISOString(),
      arrivalTime: new Date(now.getTime() + (scooterDuration + 180) * 1000).toISOString(),
      score: { overall: 75, time: 90, cost: 60, comfort: 75 },
      segments: [
        {
          type: SegmentType.WALK,
          from: { name: 'Start', location: { lat: origin.lat, lng: origin.lng } },
          to: { name: 'Hulajnoga', location: { lat: origin.lat + 0.0005, lng: origin.lng + 0.0005 } },
          duration: 90,
          distance: 100,
          polyline: walkToScooter,
          cost: 0,
        },
        {
          type: SegmentType.SCOOTER,
          from: { name: 'Hulajnoga', location: { lat: origin.lat + 0.0005, lng: origin.lng + 0.0005 } },
          to: { name: 'Parking', location: { lat: destination.lat - 0.0005, lng: destination.lng - 0.0005 } },
          duration: scooterDuration,
          distance: distance - 200,
          polyline: scooterRide,
          cost: scooterCost,
          provider: 'bolt-scooters',
          isRented: true,
        },
        {
          type: SegmentType.WALK,
          from: { name: 'Parking', location: { lat: destination.lat - 0.0005, lng: destination.lng - 0.0005 } },
          to: { name: 'Cel', location: { lat: destination.lat, lng: destination.lng } },
          duration: 90,
          distance: 100,
          polyline: walkFromScooter,
          cost: 0,
        },
      ],
    });

    // Route 3: Walking only
    const walkDuration = Math.round(distance / 1.4); // ~5 km/h
    routes.push({
      id: 'route-3',
      summary: 'Spacer',
      duration: walkDuration,
      walkTime: walkDuration,
      waitTime: 0,
      walkDistance: distance,
      transfers: 0,
      estimatedCost: 0,
      departureTime: now.toISOString(),
      arrivalTime: new Date(now.getTime() + walkDuration * 1000).toISOString(),
      score: { overall: 65, time: 40, cost: 100, comfort: 55 },
      segments: [
        {
          type: SegmentType.WALK,
          from: { name: 'Start', location: { lat: origin.lat, lng: origin.lng } },
          to: { name: 'Cel', location: { lat: destination.lat, lng: destination.lng } },
          duration: walkDuration,
          distance: distance,
          polyline: polyline,
          cost: 0,
        },
      ],
    });

    this.logger.log(`Generated ${routes.length} mock routes`);
    return routes;
  }

  /**
   * Generate a simple encoded polyline between two points
   */
  private generateSimplePolyline(origin: { lat: number; lng: number }, destination: { lat: number; lng: number }): string {
    // Create intermediate points for a more realistic line
    const points: [number, number][] = [];
    const steps = 10;
    
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const lat = origin.lat + (destination.lat - origin.lat) * t;
      const lng = origin.lng + (destination.lng - origin.lng) * t;
      points.push([lat, lng]);
    }

    // Encode to polyline format
    return this.encodePolyline(points);
  }

  /**
   * Encode coordinates to Google polyline format
   */
  private encodePolyline(coordinates: [number, number][]): string {
    let encoded = '';
    let prevLat = 0;
    let prevLng = 0;

    for (const [lat, lng] of coordinates) {
      const latInt = Math.round(lat * 1e5);
      const lngInt = Math.round(lng * 1e5);

      encoded += this.encodeNumber(latInt - prevLat);
      encoded += this.encodeNumber(lngInt - prevLng);

      prevLat = latInt;
      prevLng = lngInt;
    }

    return encoded;
  }

  private encodeNumber(num: number): string {
    let value = num < 0 ? ~(num << 1) : (num << 1);
    let encoded = '';

    while (value >= 0x20) {
      encoded += String.fromCharCode((0x20 | (value & 0x1f)) + 63);
      value >>= 5;
    }
    encoded += String.fromCharCode(value + 63);

    return encoded;
  }
}
