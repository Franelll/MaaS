# MaaS Platform

## Mobility as a Service - Unified Mobility Platform

Platforma integrująca wszystkie formy mobilności miejskiej w jednej aplikacji mobilnej:
- 🚌 **Komunikacja miejska** (GTFS Static & Realtime)
- 🛴 **Mikromobilność** (GBFS: Bolt, Tier, Dott - hulajnogi i rowery)
- 🚕 **Taxi/Ride-hailing** (Bolt, Uber)

---

## 🏗️ Architektura

```
                    ┌─────────────────┐
                    │  Flutter App    │
                    │  (iOS/Android)  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   API Gateway   │
                    │   (Kong/Nginx)  │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼───────┐   ┌───────▼───────┐   ┌───────▼───────┐
│   Core API    │   │   Realtime    │   │   Ingester    │
│   (REST)      │   │  (WebSocket)  │   │   Workers     │
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
       ┌──────▼──────┐ ┌────▼────┐ ┌─────▼─────┐
       │ PostgreSQL  │ │  Redis  │ │   S3      │
       │  + PostGIS  │ │  Cache  │ │  (GTFS)   │
       └─────────────┘ └─────────┘ └───────────┘
```

---

## 📁 Struktura Projektu

```
maas-platform/
├── apps/
│   ├── api/                    # REST API (NestJS)
│   ├── realtime/               # WebSocket server (Socket.io)
│   └── ingester/               # Data ingestion workers
├── libs/
│   ├── common/                 # Shared types & utilities
│   ├── gtfs/                   # GTFS parsing & services
│   ├── gbfs/                   # GBFS polling & services
│   ├── taxi/                   # Taxi API integrations
│   ├── geo/                    # Geospatial utilities
│   └── cache/                  # Redis cache layer
├── database/
│   └── schema.sql              # PostgreSQL schema
├── infrastructure/
│   ├── docker-compose.yml      # Local development
│   └── k8s/                    # Kubernetes manifests
└── docs/
    └── PHASE_1_TECHNICAL_SPECIFICATION.md
```

---

## 🚀 Quick Start

### Prerequisites

- Node.js 20+
- Docker & Docker Compose
- PostgreSQL 16 (via Docker)
- Redis 7 (via Docker)

### 1. Clone & Install

```bash
git clone https://github.com/your-org/maas-platform.git
cd maas-platform
npm install
```

### 2. Environment Setup

```bash
cp .env.example .env
# Edit .env with your configuration
```

### 3. Start Infrastructure

```bash
# Start PostgreSQL, Redis, and other services
npm run docker:up

# Or with dev tools (pgAdmin, Redis Commander)
docker-compose -f infrastructure/docker-compose.yml --profile dev up -d
```

### 4. Run Database Migrations

```bash
npm run db:migrate
npm run db:seed
```

### 5. Start Development Servers

```bash
# Start all services in parallel
npm run dev

# Or start individually:
npm run dev:api        # REST API on :3000
npm run dev:realtime   # WebSocket on :3001
npm run dev:ingester   # Data workers
```

### 6. Access Services

- **API**: http://localhost:3000
- **API Docs**: http://localhost:3000/docs
- **WebSocket**: ws://localhost:3001
- **pgAdmin**: http://localhost:5050

---

## 📚 API Endpoints

### Map Entities

```bash
# Get entities in bounding box
GET /api/v1/map/entities?north=52.25&south=52.20&east=21.05&west=20.95

# Get nearby entities
GET /api/v1/map/nearby?lat=52.2297&lng=21.0122&radius=500

# Get nearby micromobility only
GET /api/v1/map/nearby/micromobility?lat=52.2297&lng=21.0122

# Get nearby transit stops
GET /api/v1/map/nearby/transit?lat=52.2297&lng=21.0122
```

### WebSocket Events

```javascript
// Connect to WebSocket
const socket = io('ws://localhost:3001');

// Subscribe to area updates
socket.emit('subscribe:area', {
  centerLocation: { lat: 52.2297, lng: 21.0122 },
  radiusMeters: 1000,
  entityTypes: ['scooter', 'bike', 'transit_stop']
});

// Receive vehicle updates
socket.on('vehicles:update', (data) => {
  console.log('New vehicles:', data.vehicles);
});
```

---

## 🧪 Testing

```bash
# Unit tests
npm run test

# E2E tests
npm run test:e2e

# Test coverage
npm run test:cov
```

---

## 📦 Deployment

### Docker Build

```bash
# Build all images
docker-compose -f infrastructure/docker-compose.prod.yml build

# Push to registry
docker-compose -f infrastructure/docker-compose.prod.yml push
```

### Kubernetes

```bash
# Apply manifests
kubectl apply -f infrastructure/k8s/namespace.yaml
kubectl apply -f infrastructure/k8s/configmap.yaml
kubectl apply -f infrastructure/k8s/secrets.yaml
kubectl apply -f infrastructure/k8s/deployments/
kubectl apply -f infrastructure/k8s/ingress.yaml
```

---

## 🔧 Configuration

### Provider Configuration

Providers are configured in `infrastructure/k8s/configmap.yaml`:

```json
{
  "micromobility": {
    "bolt": {
      "enabled": true,
      "gbfsFeedUrl": "https://mds.bolt.eu/gbfs/v2/{city}",
      "pollingInterval": 10000
    }
  }
}
```

### Environment Variables

See `.env.example` for all available configuration options.

---

## 📊 Monitoring

- **Health Check**: `GET /health`
- **Metrics**: `GET /metrics` (Prometheus format)
- **Logs**: Structured JSON logging

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Support

For questions or support, please contact the development team.
