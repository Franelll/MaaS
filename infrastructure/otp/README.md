# OpenTripPlanner Setup for MaaS Platform

This directory contains the configuration and setup files for OpenTripPlanner v2.5, which provides multimodal routing capabilities for the MaaS platform.

## Quick Start

### 1. Download Data

**Windows (PowerShell):**
```powershell
cd infrastructure/otp
powershell -ExecutionPolicy Bypass -File download-data.ps1
```

**Linux/Mac:**
```bash
cd infrastructure/otp
chmod +x download-data.sh
./download-data.sh
```

This will download:
- `mazowieckie-latest.osm.pbf` (~450MB) - OpenStreetMap data for the Mazowieckie region
- `gtfs-warsaw.zip` (~15MB) - GTFS transit data for ZTM Warsaw

### 2. Build the Graph

The graph must be built before OTP can serve routing requests. This process typically takes 10-20 minutes.

```bash
docker compose --profile build-graph up otp-builder
```

After the build completes, you should see a `graph.obj` file in the `data/` directory.

### 3. Start OTP Server

**Standalone OTP:**
```bash
docker compose --profile routing up otp
```

**Full Stack (with API):**
```bash
docker compose up
```

### 4. Verify Installation

Once OTP is running, you can verify it's working:

- **Health Check:** http://localhost:8080/otp/actuators/health
- **GraphQL Playground:** http://localhost:8080/otp/routers/default/index/graphql
- **API Documentation:** http://localhost:8080/otp

## Configuration Files

### build-config.json
Controls how the graph is built from OSM and GTFS data.

Key settings:
- `areaVisibility`: Enables area-based accessibility
- `platformEntriesLinking`: Links platforms to stops
- `osmDefaults.timeZone`: Set to "Europe/Warsaw"

### router-config.json
Controls runtime behavior and real-time updates.

Key settings:
- `routingDefaults`: Default values for trip planning
- `vehicleRental`: GBFS integration settings
- `updaters`: Real-time GBFS feed configuration

## GBFS Integration

OTP automatically polls GBFS feeds to get real-time vehicle availability:

| Provider | Network ID | Update Frequency |
|----------|------------|------------------|
| Bolt Scooters | bolt-scooters | 30s |
| TIER | tier-scooters | 30s |
| Lime | lime-scooters | 30s |
| Veturilo | veturilo-bikes | 60s |

## Troubleshooting

### Graph Build Fails

**Out of Memory:**
```bash
# Increase memory in docker-compose.yml
environment:
  JAVA_OPTS: "-Xmx12G -Xms4G"
```

**Corrupted OSM/GTFS Data:**
```bash
# Delete and re-download
rm data/mazowieckie-latest.osm.pbf
rm data/gtfs-warsaw.zip
./download-data.sh
```

### OTP Slow to Start

The first start after building a graph can take 2-3 minutes while OTP loads the graph into memory. Subsequent starts are faster.

### GBFS Updates Not Working

1. Check OTP logs: `docker logs maas-otp`
2. Verify GBFS URLs are accessible
3. Check for rate limiting from GBFS providers

### No Routes Found

1. Verify origin/destination are within the graph bounds (Warsaw area)
2. Check if transit service is available for the requested date
3. Try increasing `maxWalkDistance` in the request

## API Usage

### Plan a Trip (REST)

```bash
curl -X POST http://localhost:8080/otp/routers/default/plan \
  -H "Content-Type: application/json" \
  -d '{
    "fromPlace": "52.2297,21.0122",
    "toPlace": "52.1850,20.9890",
    "time": "08:30am",
    "date": "01-09-2026",
    "mode": "WALK,TRANSIT,BICYCLE_RENT"
  }'
```

### Plan a Trip (GraphQL)

```graphql
query {
  plan(
    from: { lat: 52.2297, lon: 21.0122 }
    to: { lat: 52.1850, lon: 20.9890 }
    numItineraries: 3
    transportModes: [
      { mode: WALK }
      { mode: TRANSIT }
      { mode: BICYCLE, qualifier: RENT }
    ]
  ) {
    itineraries {
      duration
      walkDistance
      legs {
        mode
        from { name lat lon }
        to { name lat lon }
        duration
      }
    }
  }
}
```

## Data Sources

| Type | Source | URL |
|------|--------|-----|
| OSM | Geofabrik | https://download.geofabrik.de/europe/poland/mazowieckie-latest.osm.pbf |
| GTFS | ZTM Warsaw | https://mkuran.pl/gtfs/warsaw.zip |
| GTFS (alt) | ZTM Official | https://www.ztm.waw.pl/pliki/GTFS/gtfs.zip |

## Memory Requirements

| Operation | Recommended RAM |
|-----------|-----------------|
| Graph Build | 8-12 GB |
| Graph Serve | 4-6 GB |
| Full Stack | 8+ GB total |

## License

OpenTripPlanner is licensed under the LGPL. OSM data is © OpenStreetMap contributors.
