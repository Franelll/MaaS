# MaaS Platform - Faza 1: Specyfikacja Techniczna

**Wersja:** 1.0  
**Data:** 2026-01-08  
**Autor:** System Architect

---

## Spis Treści

1. [Przegląd Systemu](#1-przegląd-systemu)
2. [Architektura Systemu](#2-architektura-systemu)
3. [Schemat Bazy Danych](#3-schemat-bazy-danych)
4. [Strategia Integracji API](#4-strategia-integracji-api)
5. [Infrastruktura Chmurowa](#5-infrastruktura-chmurowa)
6. [Struktura Projektu](#6-struktura-projektu)

---

## 1. Przegląd Systemu

### 1.1 Cel Projektu

Platforma MaaS (Mobility as a Service) integrująca:
- **Komunikację miejską** (GTFS Static & Realtime)
- **Mikromobilność** (GBFS: Bolt, Tier, Dott - hulajnogi i rowery)
- **Taxi/Ride-hailing** (Bolt, Uber API)

### 1.2 Wymagania Niefunkcjonalne

| Parametr | Wymaganie |
|----------|-----------|
| Opóźnienie Real-time | < 5 sekund |
| Częstotliwość aktualizacji | 5-10 sekund |
| Dostępność | 99.9% |
| Czas odpowiedzi API | < 200ms (p95) |
| Zasięg przestrzenny | Promień 200m - 5km |

---

## 2. Architektura Systemu

### 2.1 Wybór Architektury: Modular Monolith → Microservices Ready

Rekomendowana architektura **Modular Monolith** z możliwością ewolucji do Microservices:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FLUTTER MOBILE APP                                 │
│                    (iOS/Android - Unified Codebase)                         │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          API GATEWAY (Kong/Nginx)                           │
│                    Rate Limiting, Auth, Load Balancing                      │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CORE API      │    │  REALTIME SVC   │    │  ROUTING SVC    │
│   (REST/GraphQL)│    │  (WebSocket)    │    │  (Trip Planner) │
│   Port: 3000    │    │  Port: 3001     │    │  Port: 3002     │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
         │                      │                      │
         └──────────────────────┼──────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SHARED SERVICE LAYER                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ GTFS Module │  │ GBFS Module │  │ Taxi Module │  │ User Module │        │
│  │ (Transit)   │  │ (Micro-     │  │ (Bolt/Uber) │  │ (Sessions)  │        │
│  │             │  │  mobility)  │  │             │  │             │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
└─────────┼────────────────┼────────────────┼────────────────┼────────────────┘
          │                │                │                │
          ▼                ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DATA INGESTION LAYER                                │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     REDIS CLUSTER (Cache Layer)                       │  │
│  │              vehicle:locations, gtfs:realtime, sessions               │  │
│  │                        TTL: 10-30 seconds                             │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ GTFS-RT     │  │ GBFS        │  │ Bolt/Uber   │  │ Vehicle     │        │
│  │ Ingester    │  │ Poller      │  │ Webhook     │  │ Tracker     │        │
│  │ (5s cycle)  │  │ (10s cycle) │  │ Receiver    │  │ Aggregator  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      PERSISTENCE LAYER                                       │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │              PostgreSQL 16 + PostGIS 3.4 + TimescaleDB                │  │
│  │                                                                       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │  │
│  │  │  providers  │  │  vehicles   │  │  stations   │  │   trips     │  │  │
│  │  │             │  │  (spatial)  │  │  (spatial)  │  │ (temporal)  │  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │  │
│  │                                                                       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────────┐   │  │
│  │  │user_sessions│  │gtfs_routes  │  │  vehicle_positions_history  │   │  │
│  │  │             │  │gtfs_stops   │  │  (TimescaleDB hypertable)   │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Przepływ Danych Real-time

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  EXTERNAL APIS   │     │  DATA INGESTION  │     │     STORAGE      │
│                  │     │                  │     │                  │
│  ┌────────────┐  │     │  ┌────────────┐  │     │  ┌────────────┐  │
│  │ GTFS-RT    │──┼─────┼─▶│ Ingester   │──┼─────┼─▶│ Redis      │  │
│  │ Feed       │  │     │  │ Worker     │  │     │  │ (Hot Data) │  │
│  └────────────┘  │     │  └────────────┘  │     │  └─────┬──────┘  │
│                  │     │        │         │     │        │         │
│  ┌────────────┐  │     │        ▼         │     │        ▼         │
│  │ GBFS       │──┼─────┼─▶┌────────────┐  │     │  ┌────────────┐  │
│  │ Endpoints  │  │     │  │ Normalizer │  │     │  │ PostgreSQL │  │
│  └────────────┘  │     │  │ (Unified   │──┼─────┼─▶│ + PostGIS  │  │
│                  │     │  │  Format)   │  │     │  │ (Cold Data)│  │
│  ┌────────────┐  │     │  └────────────┘  │     │  └────────────┘  │
│  │ Taxi APIs  │──┼─────┼─────────┘        │     │                  │
│  └────────────┘  │     │                  │     │                  │
└──────────────────┘     └──────────────────┘     └──────────────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │   DISTRIBUTION   │
                         │                  │
                         │  ┌────────────┐  │
                         │  │ WebSocket  │  │
                         │  │ Server     │──┼─────▶ Flutter App
                         │  │ (Socket.io)│  │
                         │  └────────────┘  │
                         └──────────────────┘
```

### 2.3 Komponenty Modułowe

#### Core Modules:

| Moduł | Odpowiedzialność | Technologia |
|-------|------------------|-------------|
| `@maas/gtfs` | Import/parsing GTFS Static, Realtime | Node.js, gtfs-realtime-bindings |
| `@maas/gbfs` | Polling GBFS feeds (Bolt, Tier, Dott) | Node.js, cron jobs |
| `@maas/taxi` | Integracja Bolt/Uber API | Node.js, OAuth2 |
| `@maas/geo` | Zapytania przestrzenne, routing | PostGIS, OSRM |
| `@maas/cache` | Redis abstraction layer | ioredis |
| `@maas/realtime` | WebSocket management | Socket.io |

---

## 3. Schemat Bazy Danych

### 3.1 Rozszerzenia PostgreSQL

```sql
-- Wymagane rozszerzenia
CREATE EXTENSION IF NOT EXISTS postgis;           -- Dane przestrzenne
CREATE EXTENSION IF NOT EXISTS postgis_topology;  -- Topologia sieci
CREATE EXTENSION IF NOT EXISTS timescaledb;       -- Time-series data
CREATE EXTENSION IF NOT EXISTS pg_trgm;           -- Wyszukiwanie tekstowe
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";       -- UUID generation
```

### 3.2 Pełny Schemat SQL

Schemat znajduje się w pliku: `database/schema.sql`

### 3.3 Indeksy Przestrzenne

```sql
-- Indeksy dla zapytań "najbliższy pojazd w promieniu X metrów"
CREATE INDEX idx_vehicles_location_gist ON vehicles USING GIST (current_location);
CREATE INDEX idx_stations_location_gist ON stations USING GIST (location);
CREATE INDEX idx_gtfs_stops_location_gist ON gtfs_stops USING GIST (location);

-- Indeks kompozytowy dla filtrowania po provider + status + lokalizacja
CREATE INDEX idx_vehicles_provider_status_location 
ON vehicles (provider_id, status) 
INCLUDE (current_location) 
WHERE status = 'available';
```

### 3.4 Przykładowe Zapytania Przestrzenne

```sql
-- Znajdź wszystkie dostępne hulajnogi w promieniu 200m od użytkownika
SELECT 
    v.id,
    v.vehicle_code,
    p.name AS provider_name,
    v.battery_level,
    ST_Distance(
        v.current_location::geography, 
        ST_SetSRID(ST_MakePoint(:user_lng, :user_lat), 4326)::geography
    ) AS distance_meters,
    v.pricing_unlock_fee,
    v.pricing_per_minute
FROM vehicles v
JOIN providers p ON v.provider_id = p.id
WHERE 
    v.status = 'available'
    AND v.vehicle_type IN ('scooter', 'bike')
    AND ST_DWithin(
        v.current_location::geography,
        ST_SetSRID(ST_MakePoint(:user_lng, :user_lat), 4326)::geography,
        200  -- promień w metrach
    )
ORDER BY distance_meters ASC
LIMIT 20;

-- Znajdź przystanki komunikacji miejskiej z nadchodzącymi odjazdami
SELECT 
    gs.stop_id,
    gs.stop_name,
    gr.route_short_name,
    gr.route_color,
    gst.departure_time,
    ST_Distance(
        gs.location::geography,
        ST_SetSRID(ST_MakePoint(:user_lng, :user_lat), 4326)::geography
    ) AS distance_meters
FROM gtfs_stops gs
JOIN gtfs_stop_times gst ON gs.stop_id = gst.stop_id
JOIN gtfs_trips gt ON gst.trip_id = gt.trip_id
JOIN gtfs_routes gr ON gt.route_id = gr.route_id
WHERE 
    ST_DWithin(
        gs.location::geography,
        ST_SetSRID(ST_MakePoint(:user_lng, :user_lat), 4326)::geography,
        500
    )
    AND gst.departure_time > CURRENT_TIME
    AND gst.departure_time < CURRENT_TIME + INTERVAL '30 minutes'
ORDER BY gst.departure_time ASC;
```

---

## 4. Strategia Integracji API

### 4.1 Unifikacja GTFS i GBFS

```typescript
// Zunifikowany interfejs pojazdu/przystanku dla widoku mapy
interface UnifiedMapEntity {
  id: string;
  type: 'transit_stop' | 'scooter' | 'bike' | 'taxi' | 'bus_realtime';
  provider: string;
  location: {
    lat: number;
    lng: number;
  };
  metadata: TransitStopMeta | MicromobilityMeta | TaxiMeta;
  availability: AvailabilityStatus;
  lastUpdated: Date;
}

interface TransitStopMeta {
  stopName: string;
  routes: Array<{
    routeId: string;
    routeName: string;
    color: string;
    nextDepartures: Date[];
  }>;
  facilities: string[];
}

interface MicromobilityMeta {
  vehicleCode: string;
  batteryLevel: number;
  range: number;
  pricing: {
    unlockFee: number;
    perMinute: number;
    currency: string;
  };
  deepLink: string;
}
```

### 4.2 Strategia Deep Linking

```typescript
// Deep Link Generator dla aplikacji zewnętrznych
const DeepLinkStrategy = {
  bolt: {
    scooter: (vehicleId: string, lat: number, lng: number) => 
      `bolt://scooter/unlock?id=${vehicleId}&lat=${lat}&lng=${lng}`,
    taxi: (pickupLat: number, pickupLng: number, destLat?: number, destLng?: number) =>
      `bolt://ride?pickup_lat=${pickupLat}&pickup_lng=${pickupLng}` +
      (destLat ? `&dest_lat=${destLat}&dest_lng=${destLng}` : ''),
    fallback: 'https://bolt.eu/app'
  },
  tier: {
    scooter: (vehicleId: string) => 
      `tier://vehicle/${vehicleId}`,
    fallback: 'https://tier.app'
  },
  uber: {
    taxi: (pickupLat: number, pickupLng: number, destLat?: number, destLng?: number) =>
      `uber://?action=setPickup&pickup[latitude]=${pickupLat}&pickup[longitude]=${pickupLng}` +
      (destLat ? `&dropoff[latitude]=${destLat}&dropoff[longitude]=${destLng}` : ''),
    fallback: 'https://m.uber.com'
  }
};
```

### 4.3 Flow Integracji

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA INTEGRATION FLOW                         │
└─────────────────────────────────────────────────────────────────┘

GTFS Static (Daily Import)          GBFS (10s Polling)
        │                                   │
        ▼                                   ▼
┌───────────────────┐            ┌───────────────────┐
│ Parse & Validate  │            │ Fetch & Normalize │
│ - routes.txt      │            │ - free_bike_status│
│ - stops.txt       │            │ - station_status  │
│ - stop_times.txt  │            │ - system_info     │
└─────────┬─────────┘            └─────────┬─────────┘
          │                                │
          ▼                                ▼
┌───────────────────┐            ┌───────────────────┐
│ PostgreSQL        │            │ Redis Cache       │
│ (Static Data)     │            │ (Live Positions)  │
└─────────┬─────────┘            └─────────┬─────────┘
          │                                │
          └────────────┬───────────────────┘
                       ▼
              ┌───────────────────┐
              │ Unified API Layer │
              │ GET /api/v1/map   │
              │   ?bbox=...       │
              │   ?types=...      │
              └─────────┬─────────┘
                        ▼
              ┌───────────────────┐
              │ Response:         │
              │ {                 │
              │   entities: [     │
              │     {type:'stop'},│
              │     {type:'scoot'}│
              │   ]               │
              │ }                 │
              └───────────────────┘
```

---

## 5. Infrastruktura Chmurowa

### 5.1 Architektura AWS (Rekomendowana)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS CLOUD                                       │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                         VPC (10.0.0.0/16)                              │ │
│  │                                                                        │ │
│  │  ┌─────────────────────────┐    ┌─────────────────────────┐          │ │
│  │  │   Public Subnet A       │    │   Public Subnet B       │          │ │
│  │  │   10.0.1.0/24          │    │   10.0.2.0/24          │          │ │
│  │  │                         │    │                         │          │ │
│  │  │  ┌─────────────────┐   │    │  ┌─────────────────┐   │          │ │
│  │  │  │ ALB (API GW)    │   │    │  │ ALB (WebSocket) │   │          │ │
│  │  │  └────────┬────────┘   │    │  └────────┬────────┘   │          │ │
│  │  └───────────┼────────────┘    └───────────┼────────────┘          │ │
│  │              │                             │                        │ │
│  │  ┌───────────┼─────────────────────────────┼───────────────────────┐│ │
│  │  │           ▼         Private Subnet      ▼                       ││ │
│  │  │   ┌─────────────────────────────────────────────────────────┐  ││ │
│  │  │   │              EKS Cluster (Kubernetes)                    │  ││ │
│  │  │   │                                                          │  ││ │
│  │  │   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │  ││ │
│  │  │   │  │ Core API │ │ Realtime │ │ Routing  │ │ Ingester │   │  ││ │
│  │  │   │  │ Pod x3   │ │ Pod x2   │ │ Pod x2   │ │ Pod x3   │   │  ││ │
│  │  │   │  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │  ││ │
│  │  │   │                                                          │  ││ │
│  │  │   └──────────────────────────────────────────────────────────┘  ││ │
│  │  │                                                                  ││ │
│  │  │   ┌──────────────────────────────────────────────────────────┐  ││ │
│  │  │   │                    Data Layer                             │  ││ │
│  │  │   │                                                           │  ││ │
│  │  │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │  ││ │
│  │  │   │  │ RDS         │  │ ElastiCache │  │ S3 Bucket   │      │  ││ │
│  │  │   │  │ PostgreSQL  │  │ Redis       │  │ GTFS Files  │      │  ││ │
│  │  │   │  │ Multi-AZ    │  │ Cluster     │  │             │      │  ││ │
│  │  │   │  └─────────────┘  └─────────────┘  └─────────────┘      │  ││ │
│  │  │   │                                                           │  ││ │
│  │  │   └───────────────────────────────────────────────────────────┘  ││ │
│  │  └──────────────────────────────────────────────────────────────────┘│ │
│  │                                                                        │ │
│  │  ┌────────────────────────────────────────────────────────────────┐   │ │
│  │  │                    Serverless Components                        │   │ │
│  │  │                                                                 │   │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐│   │ │
│  │  │  │ Lambda:     │  │ Lambda:     │  │ EventBridge Scheduler   ││   │ │
│  │  │  │ GTFS Import │  │ GBFS Poller │  │ (Cron triggers)         ││   │ │
│  │  │  │ (Daily)     │  │ (10s)       │  │                         ││   │ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────────────────┘│   │ │
│  │  │                                                                 │   │ │
│  │  └─────────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                         Monitoring & Observability                      │ │
│  │  CloudWatch │ X-Ray │ CloudWatch Logs │ SNS Alerts │ Grafana            │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Konfiguracja Docker Compose (Development)

Konfiguracja znajduje się w pliku: `infrastructure/docker-compose.yml`

### 5.3 Kubernetes Manifests

Manifesty znajdują się w katalogu: `infrastructure/k8s/`

---

## 6. Struktura Projektu

```
maas-platform/
├── apps/
│   ├── api/                          # Main REST API
│   │   ├── src/
│   │   │   ├── main.ts
│   │   │   ├── app.module.ts
│   │   │   ├── config/
│   │   │   │   ├── database.config.ts
│   │   │   │   ├── redis.config.ts
│   │   │   │   └── app.config.ts
│   │   │   └── modules/
│   │   │       ├── health/
│   │   │       ├── auth/
│   │   │       └── map/
│   │   ├── test/
│   │   ├── Dockerfile
│   │   └── package.json
│   │
│   ├── realtime/                     # WebSocket Server
│   │   ├── src/
│   │   │   ├── main.ts
│   │   │   ├── gateway/
│   │   │   │   └── vehicles.gateway.ts
│   │   │   └── services/
│   │   │       └── broadcast.service.ts
│   │   ├── Dockerfile
│   │   └── package.json
│   │
│   └── ingester/                     # Data Ingestion Workers
│       ├── src/
│       │   ├── main.ts
│       │   ├── workers/
│       │   │   ├── gtfs-realtime.worker.ts
│       │   │   ├── gbfs.worker.ts
│       │   │   └── taxi.worker.ts
│       │   └── processors/
│       │       └── vehicle-normalizer.ts
│       ├── Dockerfile
│       └── package.json
│
├── libs/                             # Shared Libraries
│   ├── gtfs/                         # GTFS Module
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   ├── gtfs.module.ts
│   │   │   ├── services/
│   │   │   │   ├── gtfs-static.service.ts
│   │   │   │   └── gtfs-realtime.service.ts
│   │   │   ├── dto/
│   │   │   └── entities/
│   │   └── package.json
│   │
│   ├── gbfs/                         # GBFS Module
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   ├── gbfs.module.ts
│   │   │   ├── services/
│   │   │   │   ├── gbfs-poller.service.ts
│   │   │   │   └── providers/
│   │   │   │       ├── bolt.provider.ts
│   │   │   │       ├── tier.provider.ts
│   │   │   │       └── dott.provider.ts
│   │   │   └── interfaces/
│   │   └── package.json
│   │
│   ├── taxi/                         # Taxi/Ride-hailing Module
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   ├── taxi.module.ts
│   │   │   ├── services/
│   │   │   │   ├── bolt-taxi.service.ts
│   │   │   │   └── uber.service.ts
│   │   │   └── interfaces/
│   │   └── package.json
│   │
│   ├── geo/                          # Geospatial Utilities
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   ├── geo.module.ts
│   │   │   ├── services/
│   │   │   │   ├── spatial-query.service.ts
│   │   │   │   └── routing.service.ts
│   │   │   └── utils/
│   │   │       └── distance.util.ts
│   │   └── package.json
│   │
│   ├── cache/                        # Redis Cache Layer
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   ├── cache.module.ts
│   │   │   └── services/
│   │   │       ├── vehicle-cache.service.ts
│   │   │       └── session-cache.service.ts
│   │   └── package.json
│   │
│   └── common/                       # Shared Types & Utils
│       ├── src/
│       │   ├── index.ts
│       │   ├── interfaces/
│       │   │   ├── unified-entity.interface.ts
│       │   │   └── provider.interface.ts
│       │   ├── dto/
│       │   ├── decorators/
│       │   └── utils/
│       └── package.json
│
├── database/
│   ├── schema.sql                    # Main database schema
│   ├── migrations/
│   │   ├── 001_initial_schema.sql
│   │   ├── 002_add_gtfs_tables.sql
│   │   └── 003_add_timescale.sql
│   └── seeds/
│       └── providers.sql
│
├── infrastructure/
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   ├── k8s/
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── secrets.yaml
│   │   ├── deployments/
│   │   │   ├── api.yaml
│   │   │   ├── realtime.yaml
│   │   │   └── ingester.yaml
│   │   ├── services/
│   │   └── ingress.yaml
│   └── terraform/
│       ├── main.tf
│       ├── variables.tf
│       ├── eks.tf
│       ├── rds.tf
│       └── elasticache.tf
│
├── docs/
│   ├── PHASE_1_TECHNICAL_SPECIFICATION.md
│   ├── API.md
│   ├── DEPLOYMENT.md
│   └── diagrams/
│
├── scripts/
│   ├── import-gtfs.ts
│   ├── seed-providers.ts
│   └── health-check.ts
│
├── package.json                      # Root package.json (Nx/Turborepo)
├── nx.json                           # Nx workspace config
├── tsconfig.base.json
├── .env.example
└── README.md
```

---

## Następne Kroki

### Faza 1 - Milestone'y:

1. **Tydzień 1-2:** Setup infrastruktury (Docker, PostgreSQL, Redis)
2. **Tydzień 3-4:** Implementacja modułu GTFS Static
3. **Tydzień 5-6:** Implementacja modułu GBFS (Bolt, Tier, Dott)
4. **Tydzień 7-8:** Unified API + Real-time WebSocket
5. **Tydzień 9-10:** Integracja z Flutter App, Deep Linking
6. **Tydzień 11-12:** Testing, Performance Tuning, Deployment

### Metryki Sukcesu Fazy 1:

- [ ] Import GTFS Static dla min. 1 miasta
- [ ] Real-time tracking hulajnóg (3 providerów)
- [ ] API response time < 200ms
- [ ] WebSocket latency < 100ms
- [ ] Dostępność 99.5%

---

*Dokument wygenerowany: 2026-01-08*
