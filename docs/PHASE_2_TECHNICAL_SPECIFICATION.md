# MaaS Platform - Faza 2: Routing Engine (Multimodal Planner)

**Wersja:** 1.0  
**Data:** 2026-01-09  
**Autor:** Senior MaaS Architect

---

## Spis Treści

1. [Przegląd Fazy 2](#1-przegląd-fazy-2)
2. [Architektura Routingu](#2-architektura-routingu)
3. [Infrastruktura OpenTripPlanner v2](#3-infrastruktura-opentripplanner-v2)
4. [Integracja GBFS z OTP](#4-integracja-gbfs-z-otp)
5. [Warstwa Integracji Backend](#5-warstwa-integracji-backend)
6. [Algorytm Scoring](#6-algorytm-scoring)
7. [API Endpoints](#7-api-endpoints)
8. [Dane Testowe](#8-dane-testowe)

---

## 1. Przegląd Fazy 2

### 1.1 Cel

Umożliwienie planowania tras multimodalnych typu:
```
[START] → 🚶 Spacer → 🛴 Hulajnoga → 🚇 Metro → 🚶 Spacer → [CEL]
```

### 1.2 Przypadki Użycia

| Use Case | Opis |
|----------|------|
| First Mile | Użytkownik jedzie hulajnogą do stacji metra |
| Last Mile | Użytkownik bierze rower miejski od stacji do domu |
| Full Multimodal | Kombinacja spaceru, mikromobilności i transportu publicznego |
| Transit Only | Tylko transport publiczny (dla porównania) |

### 1.3 Wymagania Niefunkcjonalne

| Parametr | Wymaganie |
|----------|-----------|
| Czas odpowiedzi planera | < 2 sekundy |
| Maksymalna liczba alternatyw | 5 tras |
| Świeżość danych GBFS | < 30 sekund |
| Dostępność OTP | 99.5% |

---

## 2. Architektura Routingu

### 2.1 Przepływ Danych

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FLUTTER MOBILE APP                                 │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Plan Trip Request:                                                   │   │
│  │  - Origin: { lat: 52.2297, lng: 21.0122 }                           │   │
│  │  - Destination: { lat: 52.1850, lng: 20.9890 }                      │   │
│  │  - Mode: "fastest" | "cheapest" | "comfortable"                      │   │
│  │  - Preferences: { allowScooters: true, allowBikes: false }          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │ REST API
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MAAS API (NestJS)                                   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      RoutingModule                                    │   │
│  │                                                                       │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │   │
│  │  │ RoutingController│  │TripPlannerService│  │ RouteScoringService │  │   │
│  │  │                 │  │                 │  │                     │  │   │
│  │  │ POST /routing/  │─▶│ buildOTPQuery() │─▶│ scoreRoutes()       │  │   │
│  │  │      plan       │  │ parseResponse() │  │ rankByPreference()  │  │   │
│  │  └─────────────────┘  └────────┬────────┘  └─────────────────────┘  │   │
│  │                                │                                     │   │
│  └────────────────────────────────┼─────────────────────────────────────┘   │
│                                   │ GraphQL                                  │
└───────────────────────────────────┼─────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     OPENTRIPPLANNER v2.5                                     │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        GRAPH (In-Memory)                             │   │
│  │                                                                       │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────────┐  │   │
│  │  │ OSM Street  │  │ GTFS Transit│  │ GBFS Vehicle Rental         │  │   │
│  │  │ Network     │  │ Network     │  │ (Real-time via Updater)     │  │   │
│  │  │             │  │             │  │                             │  │   │
│  │  │ 🚶 Walking  │  │ 🚌 Bus      │  │ 🛴 Scooter positions        │  │   │
│  │  │ 🚴 Cycling  │  │ 🚇 Metro    │  │ 🚲 Bike positions           │  │   │
│  │  │ 🚗 Driving  │  │ 🚋 Tram     │  │ 📍 Station availability     │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────────┘  │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Endpoints:                                                                  │
│  - GraphQL: http://otp:8080/otp/routers/default/index/graphql               │
│  - REST:    http://otp:8080/otp/routers/default/plan                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Polling (10s)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DATA SOURCES                                         │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │ OSM PBF File    │  │ GTFS Static     │  │ GBFS Feeds (Real-time)      │  │
│  │ (Warsaw)        │  │ (ZTM Warsaw)    │  │ (Bolt, Tier, Dott)          │  │
│  │                 │  │                 │  │                             │  │
│  │ mazowieckie-   │  │ gtfs-warsaw.zip │  │ gbfs.json endpoints         │  │
│  │ latest.osm.pbf │  │                 │  │ from Phase 1                │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Sekwencja Planowania Trasy

```
┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│  Mobile  │      │  API     │      │  Trip    │      │   OTP    │
│   App    │      │ Gateway  │      │ Planner  │      │          │
└────┬─────┘      └────┬─────┘      └────┬─────┘      └────┬─────┘
     │                 │                 │                 │
     │ POST /routing/plan               │                 │
     │ ────────────────▶                │                 │
     │                 │                 │                 │
     │                 │ planTrip()      │                 │
     │                 │ ───────────────▶│                 │
     │                 │                 │                 │
     │                 │                 │ GraphQL query   │
     │                 │                 │ ───────────────▶│
     │                 │                 │                 │
     │                 │                 │  OTP uses:      │
     │                 │                 │  - OSM graph    │
     │                 │                 │  - GTFS data    │
     │                 │                 │  - GBFS updater │
     │                 │                 │    (real-time)  │
     │                 │                 │                 │
     │                 │                 │ Plan response   │
     │                 │                 │ ◀───────────────│
     │                 │                 │                 │
     │                 │ mapToDTO()      │                 │
     │                 │ scoreRoutes()   │                 │
     │                 │ ◀───────────────│                 │
     │                 │                 │                 │
     │ TripPlanResponse                 │                 │
     │ ◀────────────────                │                 │
     │                 │                 │                 │
```

---

## 3. Infrastruktura OpenTripPlanner v2

### 3.1 Struktura Plików

```
infrastructure/
├── otp/
│   ├── build-config.json       # Konfiguracja budowania grafu
│   ├── router-config.json      # Konfiguracja runtime (GBFS updater)
│   ├── Dockerfile              # Multi-stage build dla OTP
│   └── data/
│       ├── .gitkeep
│       ├── mazowieckie-latest.osm.pbf  # (do pobrania)
│       └── gtfs-warsaw.zip             # (do pobrania)
```

### 3.2 build-config.json

Konfiguracja budowania grafu OTP:

```json
{
  "areaVisibility": true,
  "platformEntriesLinking": true,
  "parentStopLinking": true,
  "transitServiceStart": "-P1Y",
  "transitServiceEnd": "P3Y",
  "osmDefaults": {
    "osmTagMapping": "default",
    "timeZone": "Europe/Warsaw"
  },
  "osmWayPropertySet": "default",
  "elevationBucket": {
    "elevationUnitMultiplier": 1.0
  },
  "transit": {
    "maxInterlineDistance": 200
  },
  "transferRequests": [
    {
      "modes": "WALK"
    },
    {
      "modes": "WALK",
      "wheelchairAccessibility": { "enabled": true }
    }
  ]
}
```

### 3.3 router-config.json (z GBFS Updater)

```json
{
  "routingDefaults": {
    "numItineraries": 5,
    "transferPenalty": 300,
    "walkReluctance": 2.0,
    "waitReluctance": 1.0,
    "walkSpeed": 1.33,
    "bikeSpeed": 5.0,
    "bikeWalkingSpeed": 1.33,
    "bikeSwitchTime": 60,
    "bikeSwitchCost": 60,
    "carDropoffTime": 120
  },
  "transit": {
    "dynamicSearchWindow": {
      "minTripTimeCoefficient": 0.5,
      "minWindow": "PT30M",
      "maxWindow": "PT3H"
    }
  },
  "vehicleRental": {
    "pickupTime": 60,
    "pickupCost": 120,
    "dropoffTime": 30,
    "dropoffCost": 30,
    "useAvailabilityInformation": true,
    "allowArrivingInRentedVehicleAtDestination": false
  },
  "updaters": [
    {
      "type": "vehicle-rental",
      "network": "bolt-scooters",
      "sourceType": "gbfs",
      "url": "https://mds.bolt.eu/gbfs/2/422/gbfs",
      "frequencySec": 30,
      "headers": {
        "User-Agent": "MaaS-Platform/1.0"
      }
    },
    {
      "type": "vehicle-rental",
      "network": "tier-scooters",
      "sourceType": "gbfs",
      "url": "https://platform.tier-services.io/v2/gbfs/warsaw/gbfs.json",
      "frequencySec": 30
    },
    {
      "type": "vehicle-rental",
      "network": "lime-scooters",
      "sourceType": "gbfs",
      "url": "https://data.lime.bike/api/partners/v2/gbfs/warsaw/gbfs.json",
      "frequencySec": 30
    },
    {
      "type": "vehicle-rental",
      "network": "veturilo-bikes",
      "sourceType": "gbfs",
      "url": "https://gbfs.nextbike.net/maps/gbfs/v2/nextbike_pw/gbfs.json",
      "frequencySec": 60
    }
  ],
  "vectorTiles": {
    "layers": [
      {
        "name": "stops",
        "type": "Stop",
        "mapper": "Digitransit",
        "maxZoom": 20,
        "minZoom": 14
      },
      {
        "name": "rentalVehicles",
        "type": "VehicleRental",
        "mapper": "Digitransit",
        "maxZoom": 20,
        "minZoom": 14
      }
    ]
  }
}
```

### 3.4 Dockerfile dla OTP

```dockerfile
# Multi-stage build dla OpenTripPlanner
FROM eclipse-temurin:21-jdk-alpine AS builder

# Pobierz OTP
ENV OTP_VERSION=2.5.0
RUN wget -q https://repo1.maven.org/maven2/org/opentripplanner/otp/${OTP_VERSION}/otp-${OTP_VERSION}-shaded.jar \
    -O /opt/otp.jar

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine

WORKDIR /opt/otp

# Kopiuj OTP JAR
COPY --from=builder /opt/otp.jar /opt/otp/otp.jar

# Utwórz katalog na dane
RUN mkdir -p /opt/otp/data

# Kopiuj konfiguracje
COPY build-config.json /opt/otp/
COPY router-config.json /opt/otp/

# Expose ports
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD wget -q --spider http://localhost:8080/otp/routers/default || exit 1

# Entry point
ENTRYPOINT ["java", "-Xmx4G", "-jar", "/opt/otp/otp.jar"]
```

---

## 4. Integracja GBFS z OTP

### 4.1 Jak OTP używa GBFS

OTP v2 natywnie wspiera GBFS 2.x poprzez **Vehicle Rental Updater**:

1. **Inicjalizacja**: OTP pobiera `gbfs.json` z każdego skonfigurowanego providera
2. **Discovery**: Parsuje linki do feedów (`free_bike_status`, `station_information`, `station_status`)
3. **Polling**: Co 30 sekund aktualizuje pozycje pojazdów/stacji
4. **Routing**: Przy planowaniu trasy uwzględnia aktualne dostępne pojazdy

### 4.2 Mapowanie GBFS → OTP

```
GBFS Feed                    OTP Internal Model
─────────────────────────────────────────────────
free_bike_status    →    VehicleRentalVehicle
  - bike_id              - id
  - lat/lon              - coordinates
  - is_reserved          - isReserved
  - is_disabled          - isDisabled
  - vehicle_type_id      - vehicleType

station_information →    VehicleRentalStation
  - station_id           - id
  - name                 - name
  - lat/lon              - coordinates
  - capacity             - capacity

station_status      →    VehicleRentalStationUse
  - num_bikes_available  - bikesAvailable
  - num_docks_available  - spacesAvailable
```

### 4.3 First Mile / Last Mile Logic

Aby OTP preferowało hulajnogi zamiast długiego spaceru, konfigurujemy:

```json
{
  "routingDefaults": {
    "walkReluctance": 3.5,        // Wysokie = unikaj długich spacerów
    "bikeReluctance": 1.0,        // Niskie = preferuj mikromobilność
    "vehicleRental": {
      "pickupCost": 60,           // Niska "kara" za wypożyczenie
      "useAvailabilityInformation": true
    }
  }
}
```

W zapytaniu GraphQL używamy flag:
- `allowBikeRental: true` - pozwól na rowery
- `allowScooterRental: true` - pozwól na hulajnogi (OTP 2.5+)
- `bikeReluctance: 0.8` - dodatkowa preferencja

---

## 5. Warstwa Integracji Backend

### 5.1 Struktura Modułu

```
apps/api/src/modules/routing/
├── routing.module.ts
├── routing.controller.ts
├── services/
│   ├── trip-planner.service.ts     # Komunikacja z OTP
│   ├── route-scoring.service.ts    # Algorytm scoringu
│   └── otp-graphql.client.ts       # GraphQL client
├── dto/
│   ├── trip-plan.dto.ts            # Request/Response DTOs
│   └── route-segment.dto.ts        # Segment trasy
├── interfaces/
│   ├── otp-response.interface.ts   # Typy odpowiedzi OTP
│   └── trip-preferences.interface.ts
└── constants/
    └── otp-queries.ts              # GraphQL queries
```

### 5.2 Kluczowe Komponenty

#### TripPlannerService

Odpowiedzialności:
- Budowanie zapytań GraphQL do OTP
- Parsowanie odpowiedzi OTP
- Mapowanie na uproszczone DTO

#### RouteScoringService

Odpowiedzialności:
- Kalkulacja kosztu trasy
- Scoring wygody
- Ranking według preferencji

### 5.3 GraphQL Query do OTP

```graphql
query planTrip(
  $from: InputCoordinates!
  $to: InputCoordinates!
  $date: String
  $time: String
  $arriveBy: Boolean
  $numItineraries: Int
  $modes: [TransportMode]
  $bikeReluctance: Float
  $walkReluctance: Float
) {
  plan(
    from: $from
    to: $to
    date: $date
    time: $time
    arriveBy: $arriveBy
    numItineraries: $numItineraries
    transportModes: $modes
    preferences: {
      street: {
        bicycle: { reluctance: $bikeReluctance }
        walk: { reluctance: $walkReluctance }
      }
    }
  ) {
    itineraries {
      startTime
      endTime
      duration
      walkTime
      waitingTime
      walkDistance
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
          stop { gtfsId name }
          vehicleRentalStation { stationId name }
        }
        to {
          name
          lat
          lon
          stop { gtfsId name }
        }
        route {
          shortName
          longName
          color
          agency { name }
        }
        legGeometry {
          points
        }
        rentedBike
        steps {
          distance
          relativeDirection
          streetName
        }
      }
    }
  }
}
```

---

## 6. Algorytm Scoring

### 6.1 Tryby Optymalizacji

| Tryb | Priorytet | Opis |
|------|-----------|------|
| `fastest` | Czas | Minimalizuj całkowity czas podróży |
| `cheapest` | Koszt | Preferuj transport publiczny + spacer |
| `comfortable` | Wygoda | Mniej przesiadek, mniej spaceru |

### 6.2 Wzór Scoringu

```typescript
interface RouteScore {
  time: number;      // sekundy
  cost: number;      // PLN
  comfort: number;   // 0-100
  transfers: number;
  walkDistance: number;
}

// Scoring function
function calculateScore(route: RouteScore, mode: OptimizationMode): number {
  const weights = {
    fastest: { time: 0.7, cost: 0.1, comfort: 0.1, transfers: 0.1 },
    cheapest: { time: 0.2, cost: 0.6, comfort: 0.1, transfers: 0.1 },
    comfortable: { time: 0.2, cost: 0.1, comfort: 0.5, transfers: 0.2 },
  };
  
  const w = weights[mode];
  
  // Normalize values
  const normalizedTime = 1 - (route.time / MAX_TIME);
  const normalizedCost = 1 - (route.cost / MAX_COST);
  const normalizedComfort = route.comfort / 100;
  const normalizedTransfers = 1 - (route.transfers / MAX_TRANSFERS);
  
  return (
    w.time * normalizedTime +
    w.cost * normalizedCost +
    w.comfort * normalizedComfort +
    w.transfers * normalizedTransfers
  );
}
```

### 6.3 Estymacja Kosztów

```typescript
const COST_MATRIX = {
  WALK: 0,
  BUS: 4.40,       // bilet 20-min ZTM
  TRAM: 4.40,
  METRO: 4.40,
  RAIL: 4.40,
  SCOOTER: {       // Bolt pricing
    unlock: 3.49,
    perMinute: 0.69,
  },
  BIKE: {          // Veturilo
    first20min: 0,
    perHour: 4.00,
  },
};

function estimateCost(leg: RouteLeg): number {
  switch (leg.mode) {
    case 'SCOOTER':
      const minutes = leg.duration / 60;
      return COST_MATRIX.SCOOTER.unlock + minutes * COST_MATRIX.SCOOTER.perMinute;
    case 'BICYCLE':
      const hours = Math.ceil(leg.duration / 3600);
      return hours > 0.33 ? (hours - 0.33) * COST_MATRIX.BIKE.perHour : 0;
    case 'BUS':
    case 'TRAM':
    case 'METRO':
      return COST_MATRIX[leg.mode];
    default:
      return 0;
  }
}
```

---

## 7. API Endpoints

### 7.1 POST /api/routing/plan

**Request:**
```json
{
  "origin": {
    "lat": 52.2297,
    "lng": 21.0122
  },
  "destination": {
    "lat": 52.1850,
    "lng": 20.9890
  },
  "departureTime": "2026-01-09T08:30:00Z",
  "preferences": {
    "mode": "fastest",
    "allowScooters": true,
    "allowBikes": true,
    "maxWalkDistance": 1000,
    "wheelchairAccessible": false
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "routes": [
      {
        "id": "route-1",
        "summary": "Hulajnoga → Metro → Spacer",
        "duration": 1920,
        "estimatedCost": 12.50,
        "departureTime": "2026-01-09T08:30:00Z",
        "arrivalTime": "2026-01-09T09:02:00Z",
        "score": {
          "overall": 0.87,
          "time": 0.92,
          "cost": 0.75,
          "comfort": 0.85
        },
        "segments": [
          {
            "type": "SCOOTER",
            "provider": "bolt-scooters",
            "from": {
              "name": "Punkt startowy",
              "location": { "lat": 52.2297, "lng": 21.0122 }
            },
            "to": {
              "name": "Metro Centrum",
              "location": { "lat": 52.2310, "lng": 21.0030 }
            },
            "duration": 420,
            "distance": 1200,
            "polyline": "encoded_polyline_here",
            "cost": 6.50,
            "instructions": [
              { "text": "Idź do hulajnogi Bolt (50m)", "distance": 50 },
              { "text": "Jedź ul. Marszałkowską na północ", "distance": 800 }
            ]
          },
          {
            "type": "METRO",
            "provider": "ztm-warsaw",
            "from": {
              "name": "Metro Centrum",
              "location": { "lat": 52.2310, "lng": 21.0030 },
              "stopId": "gtfs:5001"
            },
            "to": {
              "name": "Metro Wilanowska",
              "location": { "lat": 52.1870, "lng": 21.0350 },
              "stopId": "gtfs:5012"
            },
            "duration": 900,
            "line": {
              "name": "M1",
              "color": "#E3000F"
            },
            "polyline": "encoded_polyline_here",
            "cost": 4.40,
            "departureTime": "2026-01-09T08:38:00Z"
          },
          {
            "type": "WALK",
            "from": {
              "name": "Metro Wilanowska",
              "location": { "lat": 52.1870, "lng": 21.0350 }
            },
            "to": {
              "name": "Cel podróży",
              "location": { "lat": 52.1850, "lng": 20.9890 }
            },
            "duration": 600,
            "distance": 450,
            "polyline": "encoded_polyline_here",
            "cost": 0
          }
        ]
      }
    ],
    "metadata": {
      "computedAt": "2026-01-09T08:29:55Z",
      "otpVersion": "2.5.0",
      "dataFreshness": {
        "gtfs": "2026-01-08",
        "gbfs": "2026-01-09T08:29:50Z"
      }
    }
  }
}
```

### 7.2 GET /api/routing/modes

Zwraca dostępne tryby transportu.

### 7.3 GET /api/routing/providers

Zwraca aktywnych providerów z cenami.

---

## 8. Dane Testowe

### 8.1 Źródła Danych dla Warszawy

| Typ | Źródło | URL |
|-----|--------|-----|
| OSM | Geofabrik | https://download.geofabrik.de/europe/poland/mazowieckie-latest.osm.pbf |
| GTFS | ZTM Warszawa | https://mkuran.pl/gtfs/warsaw.zip |
| GTFS (alt) | Transitfeeds | https://transitfeeds.com/p/ztm-warszawa/715 |
| GBFS Bolt | Bolt API | https://mds.bolt.eu/gbfs/2/422/gbfs |
| GBFS Tier | Tier API | https://platform.tier-services.io/v2/gbfs/warsaw/gbfs.json |

### 8.2 Instrukcja Pobierania

```bash
# Utwórz katalog na dane
mkdir -p infrastructure/otp/data

# Pobierz mapę OSM (mazowieckie ~450MB)
wget -O infrastructure/otp/data/mazowieckie-latest.osm.pbf \
  https://download.geofabrik.de/europe/poland/mazowieckie-latest.osm.pbf

# Pobierz GTFS ZTM Warszawa
wget -O infrastructure/otp/data/gtfs-warsaw.zip \
  https://mkuran.pl/gtfs/warsaw.zip

# Opcjonalnie: pełna Polska (~1.2GB)
# wget -O infrastructure/otp/data/poland-latest.osm.pbf \
#   https://download.geofabrik.de/europe/poland-latest.osm.pbf
```

### 8.3 Budowanie Grafu OTP

```bash
# Zbuduj graf (może trwać 5-15 minut)
docker compose --profile routing up otp-builder

# Uruchom OTP w trybie serve
docker compose up otp
```

---

## Appendix A: Mapowanie OTP Modes → MaaS Segments

| OTP Mode | MaaS Segment Type | Provider |
|----------|-------------------|----------|
| `WALK` | `WALK` | - |
| `BUS` | `BUS` | ztm-warsaw |
| `TRAM` | `TRAM` | ztm-warsaw |
| `SUBWAY` | `METRO` | ztm-warsaw |
| `RAIL` | `TRAIN` | koleje-mazowieckie |
| `BICYCLE_RENT` | `BIKE` | veturilo / nextbike |
| `SCOOTER_RENT` | `SCOOTER` | bolt / tier / lime |

---

## Appendix B: Troubleshooting

### OTP nie widzi pojazdów GBFS

1. Sprawdź logi OTP: `docker logs maas-otp`
2. Zweryfikuj URL GBFS: `curl -I <gbfs_url>`
3. Upewnij się, że `frequencySec` nie jest zbyt niski (min. 10s)

### Długi czas budowania grafu

- Zmniejsz obszar OSM (użyj `osmium extract`)
- Zwiększ pamięć JVM: `-Xmx8G`
- Użyj SSD dla danych

### GraphQL timeout

- Zwiększ `searchWindow` w router-config
- Ogranicz `numItineraries` do 3

---

*Dokument przygotowany przez Senior MaaS Architect*
*MaaS Platform - Faza 2: Routing Engine*
