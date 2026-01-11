// ============================================================================
// MaaS Platform - OTP Response Interfaces
// TypeScript interfaces for OpenTripPlanner GraphQL responses
// ============================================================================

/**
 * OTP GraphQL Plan Response
 */
export interface OtpPlanResponse {
  data: {
    plan: OtpPlan;
  };
  errors?: OtpError[];
}

export interface OtpError {
  message: string;
  locations?: Array<{ line: number; column: number }>;
  path?: string[];
}

export interface OtpPlan {
  date: number;
  from: OtpPlace;
  to: OtpPlace;
  itineraries: OtpItinerary[];
  routingErrors?: OtpRoutingError[];
}

export interface OtpRoutingError {
  code: string;
  description: string;
  inputField?: string;
}

export interface OtpItinerary {
  startTime: number;
  endTime: number;
  duration: number;
  walkTime: number;
  waitingTime: number;
  walkDistance: number;
  generalizedCost: number;
  elevationGained: number;
  elevationLost: number;
  transfers: number;
  legs: OtpLeg[];
  accessibilityScore?: number;
}

export interface OtpLeg {
  mode: OtpMode;
  startTime: number;
  endTime: number;
  duration: number;
  distance: number;
  from: OtpPlace;
  to: OtpPlace;
  route?: OtpRoute;
  agency?: OtpAgency;
  legGeometry: OtpLegGeometry;
  rentedBike: boolean;
  steps: OtpStep[];
  intermediateStops?: OtpPlace[];
  headsign?: string;
  pickupType?: string;
  dropoffType?: string;
  interlineWithPreviousLeg?: boolean;
  realTime?: boolean;
  realtimeState?: string;
  serviceDate?: string;
  tripId?: string;
  routeShortName?: string;
  routeLongName?: string;
  fareProducts?: OtpFareProduct[];
}

export type OtpMode = 
  | 'WALK'
  | 'BICYCLE'
  | 'BICYCLE_RENT'
  | 'SCOOTER_RENT'
  | 'CAR'
  | 'CAR_PARK'
  | 'BUS'
  | 'RAIL'
  | 'SUBWAY'
  | 'TRAM'
  | 'FERRY'
  | 'CABLE_CAR'
  | 'GONDOLA'
  | 'FUNICULAR'
  | 'TRANSIT'
  | 'FLEX';

export interface OtpPlace {
  name: string;
  lat: number;
  lon: number;
  stop?: OtpStop;
  vehicleRentalStation?: OtpVehicleRentalStation;
  rentalVehicle?: OtpRentalVehicle;
  arrival?: number;
  departure?: number;
  vertexType?: string;
}

export interface OtpStop {
  gtfsId: string;
  name: string;
  code?: string;
  platformCode?: string;
  zoneId?: string;
  vehicleMode?: string;
  parentStation?: {
    gtfsId: string;
    name: string;
  };
}

export interface OtpVehicleRentalStation {
  stationId: string;
  name: string;
  lat: number;
  lon: number;
  bikesAvailable: number;
  spacesAvailable: number;
  network?: string;
  allowDropoff?: boolean;
  allowPickup?: boolean;
}

export interface OtpRentalVehicle {
  vehicleId: string;
  name?: string;
  lat: number;
  lon: number;
  network?: string;
  operative?: boolean;
}

export interface OtpRoute {
  gtfsId: string;
  shortName: string;
  longName: string;
  mode: string;
  color?: string;
  textColor?: string;
  agency?: OtpAgency;
  bikesAllowed?: string;
}

export interface OtpAgency {
  gtfsId: string;
  name: string;
  url?: string;
  timezone?: string;
  phone?: string;
}

export interface OtpLegGeometry {
  points: string;
  length: number;
}

export interface OtpStep {
  distance: number;
  relativeDirection: OtpRelativeDirection;
  streetName: string;
  absoluteDirection?: OtpAbsoluteDirection;
  stayOn?: boolean;
  area?: boolean;
  exit?: string;
  lon: number;
  lat: number;
  elevation?: Array<{ first: number; second: number }>;
}

export type OtpRelativeDirection =
  | 'DEPART'
  | 'HARD_LEFT'
  | 'LEFT'
  | 'SLIGHTLY_LEFT'
  | 'CONTINUE'
  | 'SLIGHTLY_RIGHT'
  | 'RIGHT'
  | 'HARD_RIGHT'
  | 'CIRCLE_CLOCKWISE'
  | 'CIRCLE_COUNTERCLOCKWISE'
  | 'ELEVATOR'
  | 'UTURN_LEFT'
  | 'UTURN_RIGHT'
  | 'ENTER_STATION'
  | 'EXIT_STATION'
  | 'FOLLOW_SIGNS';

export type OtpAbsoluteDirection =
  | 'NORTH'
  | 'NORTHEAST'
  | 'EAST'
  | 'SOUTHEAST'
  | 'SOUTH'
  | 'SOUTHWEST'
  | 'WEST'
  | 'NORTHWEST';

export interface OtpFareProduct {
  id: string;
  name: string;
  price: {
    amount: number;
    currency: string;
  };
}

/**
 * OTP GraphQL Query Variables
 */
export interface OtpPlanQueryVariables extends Record<string, unknown> {
  from: OtpInputCoordinates;
  to: OtpInputCoordinates;
  date?: string;
  time?: string;
  arriveBy?: boolean;
  numItineraries?: number;
  transportModes?: OtpTransportMode[];
  walkReluctance?: number;
  bikeReluctance?: number;
  wheelchair?: boolean;
  maxWalkDistance?: number;
  allowBikeRental?: boolean;
  allowScooterRental?: boolean;
}

export interface OtpInputCoordinates {
  lat: number;
  lon: number;
}

export interface OtpTransportMode {
  mode: string;
  qualifier?: string;
}
