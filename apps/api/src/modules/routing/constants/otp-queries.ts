// ============================================================================
// MaaS Platform - OTP GraphQL Queries
// GraphQL query definitions for OpenTripPlanner v2
// ============================================================================

/**
 * Main trip planning query for OTP GraphQL API
 * Compatible with OTP v2.5
 */
export const PLAN_TRIP_QUERY = `
query PlanTrip(
  $from: InputCoordinates!
  $to: InputCoordinates!
  $date: String
  $time: String
  $arriveBy: Boolean
  $numItineraries: Int
  $transportModes: [TransportMode]
  $walkReluctance: Float
  $wheelchair: Boolean
) {
  plan(
    from: $from
    to: $to
    date: $date
    time: $time
    arriveBy: $arriveBy
    numItineraries: $numItineraries
    transportModes: $transportModes
    preferences: {
      street: {
        walk: {
          reluctance: $walkReluctance
          speed: 1.33
          boardCost: 600
        }
      }
    }
    wheelchair: $wheelchair
  ) {
    date
    from {
      name
      lat
      lon
    }
    to {
      name
      lat
      lon
    }
    routingErrors {
      code
      description
      inputField
    }
    itineraries {
      startTime
      endTime
      duration
      walkTime
      waitingTime
      walkDistance
      generalizedCost
      transfers
      accessibilityScore
      legs {
        mode
        startTime
        endTime
        duration
        distance
        from {
          name
          lat
          lon
          stop {
            gtfsId
            name
            code
            platformCode
            vehicleMode
            parentStation {
              gtfsId
              name
            }
          }
          vehicleRentalStation {
            stationId
            name
            lat
            lon
            bikesAvailable
            spacesAvailable
            network
          }
          rentalVehicle {
            vehicleId
            name
            lat
            lon
            network
            operative
          }
        }
        to {
          name
          lat
          lon
          stop {
            gtfsId
            name
            code
            platformCode
            vehicleMode
            parentStation {
              gtfsId
              name
            }
          }
          vehicleRentalStation {
            stationId
            name
            lat
            lon
            bikesAvailable
            spacesAvailable
            network
          }
        }
        route {
          gtfsId
          shortName
          longName
          mode
          color
          textColor
          agency {
            gtfsId
            name
          }
        }
        agency {
          gtfsId
          name
        }
        legGeometry {
          points
          length
        }
        rentedBike
        headsign
        realTime
        realtimeState
        intermediateStops {
          name
          lat
          lon
          stop {
            gtfsId
            name
          }
        }
        steps {
          distance
          relativeDirection
          streetName
          absoluteDirection
          stayOn
          area
          exit
          lon
          lat
        }
      }
    }
  }
}
`;

/**
 * Health check query
 */
export const HEALTH_CHECK_QUERY = `
query HealthCheck {
  serviceTimeRange {
    start
    end
  }
}
`;

/**
 * Get available rental vehicles in area
 */
export const RENTAL_VEHICLES_QUERY = `
query RentalVehicles(
  $minLat: Float!
  $minLon: Float!
  $maxLat: Float!
  $maxLon: Float!
) {
  rentalVehicles(
    bbox: {
      minLat: $minLat
      minLon: $minLon
      maxLat: $maxLat
      maxLon: $maxLon
    }
  ) {
    vehicleId
    name
    lat
    lon
    network
    operative
  }
}
`;

/**
 * Get vehicle rental stations in area
 */
export const RENTAL_STATIONS_QUERY = `
query RentalStations(
  $minLat: Float!
  $minLon: Float!
  $maxLat: Float!
  $maxLon: Float!
) {
  vehicleRentalStations(
    bbox: {
      minLat: $minLat
      minLon: $minLon
      maxLat: $maxLat
      maxLon: $maxLon
    }
  ) {
    stationId
    name
    lat
    lon
    bikesAvailable
    spacesAvailable
    network
    allowDropoff
    allowPickup
  }
}
`;

/**
 * Get transit stops in area
 */
export const STOPS_QUERY = `
query Stops(
  $minLat: Float!
  $minLon: Float!
  $maxLat: Float!
  $maxLon: Float!
) {
  stops(
    minLat: $minLat
    minLon: $minLon
    maxLat: $maxLat
    maxLon: $maxLon
  ) {
    gtfsId
    name
    lat
    lon
    code
    vehicleMode
    parentStation {
      gtfsId
      name
    }
    stoptimesWithoutPatterns(
      numberOfDepartures: 5
      timeRange: 7200
    ) {
      scheduledDeparture
      realtimeDeparture
      headsign
      trip {
        route {
          shortName
          longName
          color
        }
      }
    }
  }
}
`;
