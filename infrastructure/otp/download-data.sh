#!/bin/bash
# =============================================================================
# MaaS Platform - OTP Data Download Script
# Downloads OpenStreetMap and GTFS data for Warsaw, Poland
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"

echo "==================================================================="
echo "MaaS Platform - OpenTripPlanner Data Downloader"
echo "==================================================================="
echo ""

# Create data directory if it doesn't exist
mkdir -p "${DATA_DIR}"

# =============================================================================
# Download OSM Data (Mazowieckie region - includes Warsaw)
# =============================================================================
OSM_FILE="${DATA_DIR}/mazowieckie-latest.osm.pbf"
OSM_URL="https://download.geofabrik.de/europe/poland/mazowieckie-latest.osm.pbf"

if [ -f "${OSM_FILE}" ]; then
    echo "[OSM] File already exists: ${OSM_FILE}"
    echo "[OSM] Delete it manually if you want to re-download"
else
    echo "[OSM] Downloading Mazowieckie OSM data (~450MB)..."
    echo "[OSM] Source: ${OSM_URL}"
    wget -O "${OSM_FILE}" "${OSM_URL}" --progress=bar:force:noscroll
    echo "[OSM] Download complete!"
fi

echo ""

# =============================================================================
# Download GTFS Data (ZTM Warsaw - Public Transport)
# =============================================================================
GTFS_FILE="${DATA_DIR}/gtfs-warsaw.zip"
GTFS_URL="https://mkuran.pl/gtfs/warsaw.zip"
# Alternative: https://www.ztm.waw.pl/pliki/GTFS/gtfs.zip

if [ -f "${GTFS_FILE}" ]; then
    echo "[GTFS] File already exists: ${GTFS_FILE}"
    echo "[GTFS] Delete it manually if you want to re-download"
else
    echo "[GTFS] Downloading ZTM Warsaw GTFS data..."
    echo "[GTFS] Source: ${GTFS_URL}"
    wget -O "${GTFS_FILE}" "${GTFS_URL}" --progress=bar:force:noscroll
    echo "[GTFS] Download complete!"
fi

echo ""

# =============================================================================
# Verify Downloads
# =============================================================================
echo "==================================================================="
echo "Verification"
echo "==================================================================="

if [ -f "${OSM_FILE}" ] && [ -f "${GTFS_FILE}" ]; then
    echo ""
    echo "✅ All files downloaded successfully!"
    echo ""
    echo "Files in ${DATA_DIR}:"
    ls -lh "${DATA_DIR}"
    echo ""
    echo "==================================================================="
    echo "Next Steps:"
    echo "==================================================================="
    echo ""
    echo "1. Build the OTP graph (this may take 10-20 minutes):"
    echo "   docker compose --profile build-graph up otp-builder"
    echo ""
    echo "2. Start the OTP server:"
    echo "   docker compose --profile routing up otp"
    echo ""
    echo "3. Or start the full stack:"
    echo "   docker compose up"
    echo ""
    echo "4. Access OTP API at: http://localhost:8080/otp"
    echo "   GraphQL Playground: http://localhost:8080/otp/routers/default/index/graphql"
    echo ""
else
    echo ""
    echo "❌ Some files are missing. Please check the errors above."
    exit 1
fi
