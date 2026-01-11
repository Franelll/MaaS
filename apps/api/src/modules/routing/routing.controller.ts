// ============================================================================
// MaaS Platform - Routing Controller
// REST API endpoints for trip planning
// ============================================================================

import {
  Controller,
  Post,
  Get,
  Body,
  HttpCode,
  HttpStatus,
  Logger,
  BadRequestException,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBody,
} from '@nestjs/swagger';
import { TripPlannerService } from './services/trip-planner.service';
import { RouteScoringService } from './services/route-scoring.service';
import {
  TripPlanRequestDto,
  TripPlanResponseDto,
  AvailableModesDto,
  RoutingProvidersDto,
  OptimizationMode,
} from './dto/trip-plan.dto';

@ApiTags('Routing')
@Controller('routing')
export class RoutingController {
  private readonly logger = new Logger(RoutingController.name);

  constructor(
    private readonly tripPlannerService: TripPlannerService,
    private readonly routeScoringService: RouteScoringService,
  ) {}

  /**
   * Plan a multimodal trip
   */
  @Post('plan')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Plan a multimodal trip',
    description: 'Calculate routes combining walking, public transit, and micromobility (scooters, bikes)',
  })
  @ApiBody({ type: TripPlanRequestDto })
  @ApiResponse({
    status: 200,
    description: 'Trip plan calculated successfully',
    type: TripPlanResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Invalid request parameters',
  })
  @ApiResponse({
    status: 503,
    description: 'Routing service unavailable',
  })
  async planTrip(@Body() request: TripPlanRequestDto): Promise<TripPlanResponseDto> {
    this.logger.log(`Planning trip from (${request.origin.lat}, ${request.origin.lng}) to (${request.destination.lat}, ${request.destination.lng})`);

    // Validate coordinates are in Poland/Warsaw area
    this.validateCoordinates(request.origin.lat, request.origin.lng, 'origin');
    this.validateCoordinates(request.destination.lat, request.destination.lng, 'destination');

    // Get routes from OTP
    const routes = await this.tripPlannerService.planTrip(request);

    // Score and rank routes based on user preferences
    const scoredRoutes = this.routeScoringService.scoreAndRankRoutes(
      routes,
      request.preferences?.mode ?? OptimizationMode.FASTEST,
    );

    return {
      success: true,
      data: {
        routes: scoredRoutes,
        metadata: {
          computedAt: new Date().toISOString(),
          otpVersion: '2.5.0',
          dataFreshness: {
            gtfs: new Date().toISOString().split('T')[0],
            gbfs: new Date().toISOString(),
          },
        },
      },
    };
  }

  /**
   * Get available transport modes
   */
  @Get('modes')
  @ApiOperation({
    summary: 'Get available transport modes',
    description: 'Returns list of transport modes available for routing',
  })
  @ApiResponse({
    status: 200,
    description: 'List of available modes',
    type: AvailableModesDto,
  })
  async getAvailableModes(): Promise<AvailableModesDto> {
    return {
      modes: [
        {
          id: 'WALK',
          name: 'Walking',
          icon: '🚶',
          available: true,
        },
        {
          id: 'BUS',
          name: 'Bus',
          icon: '🚌',
          available: true,
          provider: 'ztm-warsaw',
        },
        {
          id: 'TRAM',
          name: 'Tram',
          icon: '🚋',
          available: true,
          provider: 'ztm-warsaw',
        },
        {
          id: 'METRO',
          name: 'Metro',
          icon: '🚇',
          available: true,
          provider: 'ztm-warsaw',
        },
        {
          id: 'RAIL',
          name: 'Train',
          icon: '🚆',
          available: true,
          provider: 'koleje-mazowieckie',
        },
        {
          id: 'SCOOTER',
          name: 'E-Scooter',
          icon: '🛴',
          available: true,
          providers: ['bolt-scooters', 'tier-scooters', 'lime-scooters'],
        },
        {
          id: 'BIKE',
          name: 'Bike',
          icon: '🚲',
          available: true,
          providers: ['veturilo-bikes'],
        },
      ],
    };
  }

  /**
   * Get routing providers with pricing
   */
  @Get('providers')
  @ApiOperation({
    summary: 'Get routing providers',
    description: 'Returns list of transport providers with current pricing',
  })
  @ApiResponse({
    status: 200,
    description: 'List of providers with pricing',
    type: RoutingProvidersDto,
  })
  async getProviders(): Promise<RoutingProvidersDto> {
    return {
      providers: [
        {
          id: 'ztm-warsaw',
          name: 'ZTM Warszawa',
          type: 'transit',
          modes: ['BUS', 'TRAM', 'METRO'],
          pricing: {
            singleTicket: 4.40,
            twentyMinuteTicket: 3.40,
            dailyPass: 15.00,
            currency: 'PLN',
          },
        },
        {
          id: 'bolt-scooters',
          name: 'Bolt',
          type: 'micromobility',
          modes: ['SCOOTER'],
          pricing: {
            unlockFee: 3.49,
            perMinute: 0.69,
            currency: 'PLN',
          },
        },
        {
          id: 'tier-scooters',
          name: 'TIER',
          type: 'micromobility',
          modes: ['SCOOTER'],
          pricing: {
            unlockFee: 3.50,
            perMinute: 0.65,
            currency: 'PLN',
          },
        },
        {
          id: 'lime-scooters',
          name: 'Lime',
          type: 'micromobility',
          modes: ['SCOOTER'],
          pricing: {
            unlockFee: 3.50,
            perMinute: 0.79,
            currency: 'PLN',
          },
        },
        {
          id: 'veturilo-bikes',
          name: 'Veturilo',
          type: 'micromobility',
          modes: ['BIKE'],
          pricing: {
            first20min: 0,
            perHour: 4.00,
            currency: 'PLN',
          },
        },
      ],
    };
  }

  /**
   * Health check for routing service
   */
  @Get('health')
  @ApiOperation({ summary: 'Check routing service health' })
  async healthCheck(): Promise<{ status: string; otp: boolean }> {
    const otpHealthy = await this.tripPlannerService.checkOtpHealth();
    return {
      status: otpHealthy ? 'healthy' : 'degraded',
      otp: otpHealthy,
    };
  }

  /**
   * Validate coordinates are within reasonable bounds (Poland)
   */
  private validateCoordinates(lat: number, lng: number, field: string): void {
    // Poland approximate bounds
    const POLAND_BOUNDS = {
      minLat: 49.0,
      maxLat: 55.0,
      minLng: 14.0,
      maxLng: 24.5,
    };

    if (
      lat < POLAND_BOUNDS.minLat ||
      lat > POLAND_BOUNDS.maxLat ||
      lng < POLAND_BOUNDS.minLng ||
      lng > POLAND_BOUNDS.maxLng
    ) {
      throw new BadRequestException(
        `${field} coordinates (${lat}, ${lng}) are outside the supported region (Poland)`,
      );
    }
  }
}
