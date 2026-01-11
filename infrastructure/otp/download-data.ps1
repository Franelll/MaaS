# =============================================================================
# MaaS Platform - OTP Data Download Script (Windows PowerShell)
# Downloads OpenStreetMap and GTFS data for Warsaw, Poland
# =============================================================================

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir = Join-Path $ScriptDir "data"

Write-Host "==================================================================="
Write-Host "MaaS Platform - OpenTripPlanner Data Downloader"
Write-Host "==================================================================="
Write-Host ""

# Create data directory if it doesn't exist
if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir | Out-Null
}

# =============================================================================
# Download OSM Data (Mazowieckie region - includes Warsaw)
# =============================================================================
$OsmFile = Join-Path $DataDir "mazowieckie-latest.osm.pbf"
$OsmUrl = "https://download.geofabrik.de/europe/poland/mazowieckie-latest.osm.pbf"

if (Test-Path $OsmFile) {
    Write-Host "[OSM] File already exists: $OsmFile"
    Write-Host "[OSM] Delete it manually if you want to re-download"
} else {
    Write-Host "[OSM] Downloading Mazowieckie OSM data (~450MB)..."
    Write-Host "[OSM] Source: $OsmUrl"
    
    # Use BITS for better download experience
    try {
        Start-BitsTransfer -Source $OsmUrl -Destination $OsmFile -DisplayName "Downloading OSM Data"
    } catch {
        # Fallback to Invoke-WebRequest if BITS fails
        Write-Host "[OSM] BITS failed, using Invoke-WebRequest..."
        Invoke-WebRequest -Uri $OsmUrl -OutFile $OsmFile -UseBasicParsing
    }
    
    Write-Host "[OSM] Download complete!"
}

Write-Host ""

# =============================================================================
# Download GTFS Data (ZTM Warsaw - Public Transport)
# =============================================================================
$GtfsFile = Join-Path $DataDir "gtfs-warsaw.zip"
$GtfsUrl = "https://mkuran.pl/gtfs/warsaw.zip"
# Alternative: https://www.ztm.waw.pl/pliki/GTFS/gtfs.zip

if (Test-Path $GtfsFile) {
    Write-Host "[GTFS] File already exists: $GtfsFile"
    Write-Host "[GTFS] Delete it manually if you want to re-download"
} else {
    Write-Host "[GTFS] Downloading ZTM Warsaw GTFS data..."
    Write-Host "[GTFS] Source: $GtfsUrl"
    
    try {
        Start-BitsTransfer -Source $GtfsUrl -Destination $GtfsFile -DisplayName "Downloading GTFS Data"
    } catch {
        Write-Host "[GTFS] BITS failed, using Invoke-WebRequest..."
        Invoke-WebRequest -Uri $GtfsUrl -OutFile $GtfsFile -UseBasicParsing
    }
    
    Write-Host "[GTFS] Download complete!"
}

Write-Host ""

# =============================================================================
# Verify Downloads
# =============================================================================
Write-Host "==================================================================="
Write-Host "Verification"
Write-Host "==================================================================="

$OsmExists = Test-Path $OsmFile
$GtfsExists = Test-Path $GtfsFile

if ($OsmExists -and $GtfsExists) {
    Write-Host ""
    Write-Host "✅ All files downloaded successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Files in $DataDir`:"
    Get-ChildItem $DataDir | Format-Table Name, Length, LastWriteTime
    Write-Host ""
    Write-Host "==================================================================="
    Write-Host "Next Steps:"
    Write-Host "==================================================================="
    Write-Host ""
    Write-Host "1. Build the OTP graph (this may take 10-20 minutes):"
    Write-Host "   docker compose --profile build-graph up otp-builder" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. Start the OTP server:"
    Write-Host "   docker compose --profile routing up otp" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "3. Or start the full stack:"
    Write-Host "   docker compose up" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "4. Access OTP API at: http://localhost:8080/otp"
    Write-Host "   GraphQL Playground: http://localhost:8080/otp/routers/default/index/graphql"
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Some files are missing. Please check the errors above." -ForegroundColor Red
    exit 1
}
