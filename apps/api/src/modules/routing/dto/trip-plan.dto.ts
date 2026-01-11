// ============================================================================
// MaaS Platform - Trip Plan DTOs
// Request and Response Data Transfer Objects for routing endpoints
// ============================================================================

import {
  IsNumber,
  IsOptional,
  IsBoolean,
  IsEnum,
  IsDateString,
  ValidateNested,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

// ============================================================================
// Enums
// ============================================================================

export enum OptimizationMode {
  FASTEST = 'fastest',
  CHEAPEST = 'cheapest',
  COMFORTABLE = 'comfortable',
}

export enum SegmentType {
  WALK = 'WALK',
  BUS = 'BUS',
  TRAM = 'TRAM',
  METRO = 'METRO',
  RAIL = 'RAIL',
  SCOOTER = 'SCOOTER',
  BIKE = 'BIKE',
  TAXI = 'TAXI',
  CAR = 'CAR',
}

// ============================================================================
// Request DTOs
// ============================================================================

export class GeoLocationDto {
  @ApiProperty({ description: 'Latitude', example: 52.2297 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat!: number;

  @ApiProperty({ description: 'Longitude', example: 21.0122 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng!: number;
}

export class TripPreferencesDto {
  @ApiPropertyOptional({
    enum: OptimizationMode,
    default: OptimizationMode.FASTEST,
    description: 'Optimization mode: fastest, cheapest, or comfortable',
  })
  @IsOptional()
  @IsEnum(OptimizationMode)
  mode?: OptimizationMode = OptimizationMode.FASTEST;

  @ApiPropertyOptional({
    description: 'Allow e-scooters in route',
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  allowScooters?: boolean = true;

  @ApiPropertyOptional({
    description: 'Allow bikes in route',
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  allowBikes?: boolean = true;

  @ApiPropertyOptional({
    description: 'Maximum walking distance in meters',
    default: 1000,
  })
  @IsOptional()
  @IsNumber()
  @Min(100)
  @Max(5000)
  maxWalkDistance?: number = 1000;

  @ApiPropertyOptional({
    description: 'Require wheelchair accessible route',
    default: false,
  })
  @IsOptional()
  @IsBoolean()
  wheelchairAccessible?: boolean = false;

  @ApiPropertyOptional({
    description: 'Number of route alternatives to return',
    default: 3,
  })
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(5)
  numAlternatives?: number = 3;
}

export class TripPlanRequestDto {
  @ApiProperty({ description: 'Starting point', type: GeoLocationDto })
  @ValidateNested()
  @Type(() => GeoLocationDto)
  origin!: GeoLocationDto;

  @ApiProperty({ description: 'Destination point', type: GeoLocationDto })
  @ValidateNested()
  @Type(() => GeoLocationDto)
  destination!: GeoLocationDto;

  @ApiPropertyOptional({
    description: 'Departure time (ISO 8601)',
    example: '2026-01-09T08:30:00Z',
  })
  @IsOptional()
  @IsDateString()
  departureTime?: string;

  @ApiPropertyOptional({
    description: 'Arrival time (ISO 8601) - use instead of departureTime for arrive-by routing',
  })
  @IsOptional()
  @IsDateString()
  arrivalTime?: string;

  @ApiPropertyOptional({
    description: 'Trip preferences',
    type: TripPreferencesDto,
  })
  @IsOptional()
  @ValidateNested()
  @Type(() => TripPreferencesDto)
  preferences?: TripPreferencesDto;
}

// ============================================================================
// Response DTOs
// ============================================================================

export class LocationDetailDto {
  @ApiProperty({ description: 'Location name' })
  name!: string;

  @ApiProperty({ description: 'Geographic coordinates' })
  location!: GeoLocationDto;

  @ApiPropertyOptional({ description: 'Stop ID for transit stops' })
  stopId?: string;

  @ApiPropertyOptional({ description: 'Station ID for rental stations' })
  stationId?: string;
}

export class TransitLineDto {
  @ApiProperty({ description: 'Line short name', example: 'M1' })
  name!: string;

  @ApiPropertyOptional({ description: 'Line long name' })
  longName?: string;

  @ApiProperty({ description: 'Line color (hex)', example: '#E3000F' })
  color!: string;

  @ApiPropertyOptional({ description: 'Agency name' })
  agency?: string;
}

export class InstructionDto {
  @ApiProperty({ description: 'Instruction text' })
  text!: string;

  @ApiProperty({ description: 'Distance in meters' })
  distance!: number;

  @ApiPropertyOptional({ description: 'Direction' })
  direction?: string;

  @ApiPropertyOptional({ description: 'Street name' })
  streetName?: string;
}

export class RouteSegmentDto {
  @ApiProperty({ enum: SegmentType, description: 'Segment transport mode' })
  type!: SegmentType;

  @ApiPropertyOptional({ description: 'Provider ID for micromobility' })
  provider?: string;

  @ApiProperty({ description: 'Starting point', type: LocationDetailDto })
  from!: LocationDetailDto;

  @ApiProperty({ description: 'End point', type: LocationDetailDto })
  to!: LocationDetailDto;

  @ApiProperty({ description: 'Duration in seconds' })
  duration!: number;

  @ApiProperty({ description: 'Distance in meters' })
  distance!: number;

  @ApiProperty({ description: 'Encoded polyline for map rendering' })
  polyline!: string;

  @ApiProperty({ description: 'Estimated cost in PLN' })
  cost!: number;

  @ApiPropertyOptional({ description: 'Transit line information' })
  line?: TransitLineDto;

  @ApiPropertyOptional({ description: 'Scheduled departure time' })
  departureTime?: string;

  @ApiPropertyOptional({ description: 'Scheduled arrival time' })
  arrivalTime?: string;

  @ApiPropertyOptional({
    description: 'Navigation instructions',
    type: [InstructionDto],
  })
  instructions?: InstructionDto[];

  @ApiPropertyOptional({ description: 'Number of stops (for transit)' })
  numStops?: number;

  @ApiPropertyOptional({ description: 'Is this a rental vehicle segment' })
  isRented?: boolean;
}

export class RouteScoreDto {
  @ApiProperty({ description: 'Overall score (0-1)' })
  overall!: number;

  @ApiProperty({ description: 'Time efficiency score (0-1)' })
  time!: number;

  @ApiProperty({ description: 'Cost efficiency score (0-1)' })
  cost!: number;

  @ApiProperty({ description: 'Comfort score (0-1)' })
  comfort!: number;
}

export class PlannedRouteDto {
  @ApiProperty({ description: 'Route ID' })
  id!: string;

  @ApiProperty({ description: 'Human-readable summary', example: 'Hulajnoga → Metro → Spacer' })
  summary!: string;

  @ApiProperty({ description: 'Total duration in seconds' })
  duration!: number;

  @ApiProperty({ description: 'Total walking time in seconds' })
  walkTime!: number;

  @ApiProperty({ description: 'Total waiting time in seconds' })
  waitTime!: number;

  @ApiProperty({ description: 'Total walking distance in meters' })
  walkDistance!: number;

  @ApiProperty({ description: 'Number of transfers' })
  transfers!: number;

  @ApiProperty({ description: 'Estimated total cost in PLN' })
  estimatedCost!: number;

  @ApiProperty({ description: 'Departure time' })
  departureTime!: string;

  @ApiProperty({ description: 'Arrival time' })
  arrivalTime!: string;

  @ApiProperty({ description: 'Route scores', type: RouteScoreDto })
  score!: RouteScoreDto;

  @ApiProperty({
    description: 'Route segments',
    type: [RouteSegmentDto],
  })
  segments!: RouteSegmentDto[];
}

export class DataFreshnessDto {
  @ApiProperty({ description: 'GTFS data date' })
  gtfs!: string;

  @ApiProperty({ description: 'GBFS last update timestamp' })
  gbfs!: string;
}

export class ResponseMetadataDto {
  @ApiProperty({ description: 'Computation timestamp' })
  computedAt!: string;

  @ApiProperty({ description: 'OTP version' })
  otpVersion!: string;

  @ApiProperty({ description: 'Data freshness info' })
  dataFreshness!: DataFreshnessDto;
}

export class TripPlanDataDto {
  @ApiProperty({ description: 'Planned routes', type: [PlannedRouteDto] })
  routes!: PlannedRouteDto[];

  @ApiProperty({ description: 'Response metadata' })
  metadata!: ResponseMetadataDto;
}

export class TripPlanResponseDto {
  @ApiProperty({ description: 'Request success status' })
  success!: boolean;

  @ApiProperty({ description: 'Response data', type: TripPlanDataDto })
  data!: TripPlanDataDto;
}

// ============================================================================
// Modes and Providers DTOs
// ============================================================================

export class TransportModeDto {
  @ApiProperty({ description: 'Mode ID' })
  id!: string;

  @ApiProperty({ description: 'Mode name' })
  name!: string;

  @ApiProperty({ description: 'Mode icon emoji' })
  icon!: string;

  @ApiProperty({ description: 'Is mode currently available' })
  available!: boolean;

  @ApiPropertyOptional({ description: 'Provider ID for single provider' })
  provider?: string;

  @ApiPropertyOptional({ description: 'Provider IDs for multiple providers' })
  providers?: string[];
}

export class AvailableModesDto {
  @ApiProperty({ type: [TransportModeDto] })
  modes!: TransportModeDto[];
}

export class ProviderPricingDto {
  @ApiPropertyOptional({ description: 'Single ticket price' })
  singleTicket?: number;

  @ApiPropertyOptional({ description: '20-minute ticket price' })
  twentyMinuteTicket?: number;

  @ApiPropertyOptional({ description: 'Daily pass price' })
  dailyPass?: number;

  @ApiPropertyOptional({ description: 'Unlock fee' })
  unlockFee?: number;

  @ApiPropertyOptional({ description: 'Per minute rate' })
  perMinute?: number;

  @ApiPropertyOptional({ description: 'First 20 minutes price' })
  first20min?: number;

  @ApiPropertyOptional({ description: 'Per hour rate' })
  perHour?: number;

  @ApiProperty({ description: 'Currency code' })
  currency!: string;
}

export class RoutingProviderDto {
  @ApiProperty({ description: 'Provider ID' })
  id!: string;

  @ApiProperty({ description: 'Provider name' })
  name!: string;

  @ApiProperty({ description: 'Provider type' })
  type!: string;

  @ApiProperty({ description: 'Supported modes' })
  modes!: string[];

  @ApiProperty({ description: 'Pricing information' })
  pricing!: ProviderPricingDto;
}

export class RoutingProvidersDto {
  @ApiProperty({ type: [RoutingProviderDto] })
  providers!: RoutingProviderDto[];
}
