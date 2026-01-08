-- ============================================================================
-- MaaS Platform - Database Schema
-- PostgreSQL 16 + PostGIS 3.4 + TimescaleDB
-- ============================================================================

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;           -- Spatial data support
CREATE EXTENSION IF NOT EXISTS postgis_topology;  -- Network topology
CREATE EXTENSION IF NOT EXISTS timescaledb;       -- Time-series optimization
CREATE EXTENSION IF NOT EXISTS pg_trgm;           -- Text search (trigrams)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";       -- UUID generation

-- ============================================================================
-- CUSTOM TYPES
-- ============================================================================

-- Provider types
CREATE TYPE provider_type AS ENUM (
    'transit',           -- Public transportation (GTFS)
    'micromobility',     -- Scooters, bikes (GBFS)
    'taxi',              -- Taxi/ride-hailing
    'carsharing'         -- Car sharing (future)
);

-- Vehicle types
CREATE TYPE vehicle_type AS ENUM (
    'bus',
    'tram',
    'metro',
    'train',
    'ferry',
    'scooter',
    'bike',
    'ebike',
    'moped',
    'car',
    'taxi'
);

-- Vehicle status
CREATE TYPE vehicle_status AS ENUM (
    'available',
    'reserved',
    'in_use',
    'maintenance',
    'offline',
    'low_battery'
);

-- Trip status
CREATE TYPE trip_status AS ENUM (
    'planned',
    'searching',
    'confirmed',
    'in_progress',
    'completed',
    'cancelled'
);

-- ============================================================================
-- TABLE: providers
-- Master table for all mobility service providers
-- ============================================================================

CREATE TABLE providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Basic info
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(50) NOT NULL UNIQUE,
    type provider_type NOT NULL,
    
    -- Branding
    logo_url VARCHAR(500),
    primary_color VARCHAR(7),           -- Hex color e.g., #00FF00
    secondary_color VARCHAR(7),
    
    -- API Configuration (encrypted in production)
    api_base_url VARCHAR(500),
    api_key_encrypted TEXT,
    api_version VARCHAR(20),
    
    -- GBFS/GTFS specific
    gbfs_feed_url VARCHAR(500),
    gtfs_feed_url VARCHAR(500),
    gtfs_realtime_url VARCHAR(500),
    
    -- Deep linking
    deep_link_scheme VARCHAR(100),      -- e.g., "bolt://", "tier://"
    deep_link_pattern_unlock TEXT,      -- Pattern for vehicle unlock
    deep_link_pattern_ride TEXT,        -- Pattern for ride request
    app_store_url VARCHAR(500),
    play_store_url VARCHAR(500),
    fallback_web_url VARCHAR(500),
    
    -- Coverage area (polygon or multipolygon)
    coverage_area GEOMETRY(MultiPolygon, 4326),
    
    -- Configuration
    polling_interval_seconds INT DEFAULT 10,
    is_active BOOLEAN DEFAULT true,
    supported_vehicle_types vehicle_type[] DEFAULT '{}',
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT providers_polling_interval_check CHECK (polling_interval_seconds >= 5)
);

-- Indexes for providers
CREATE INDEX idx_providers_type ON providers(type);
CREATE INDEX idx_providers_active ON providers(is_active) WHERE is_active = true;
CREATE INDEX idx_providers_coverage_gist ON providers USING GIST(coverage_area);

-- ============================================================================
-- TABLE: vehicles
-- Real-time vehicle positions and status (micromobility & taxi)
-- ============================================================================

CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    
    -- External identifiers
    external_id VARCHAR(100) NOT NULL,  -- ID from provider's system
    vehicle_code VARCHAR(50),           -- Human-readable code (e.g., "BOLT-12345")
    
    -- Vehicle details
    vehicle_type vehicle_type NOT NULL,
    status vehicle_status DEFAULT 'available',
    
    -- Current location (real-time updated)
    current_location GEOMETRY(Point, 4326) NOT NULL,
    heading DECIMAL(5,2),               -- Direction in degrees (0-360)
    speed DECIMAL(6,2),                 -- Current speed in km/h
    
    -- Battery/Fuel (for electric vehicles)
    battery_level INT,                  -- Percentage 0-100
    estimated_range INT,                -- Estimated range in meters
    
    -- Pricing (cached from provider)
    pricing_unlock_fee DECIMAL(10,2),
    pricing_per_minute DECIMAL(10,2),
    pricing_per_km DECIMAL(10,2),
    pricing_currency VARCHAR(3) DEFAULT 'PLN',
    
    -- Metadata
    model VARCHAR(100),
    license_plate VARCHAR(20),
    max_speed INT,
    
    -- Station association (for docked systems)
    station_id UUID REFERENCES stations(id),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    location_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraint: one external_id per provider
    CONSTRAINT vehicles_provider_external_unique UNIQUE (provider_id, external_id)
);

-- Spatial index for proximity queries (critical for performance)
CREATE INDEX idx_vehicles_location_gist ON vehicles USING GIST(current_location);

-- Composite index for filtered spatial queries
CREATE INDEX idx_vehicles_available_location ON vehicles(provider_id, status) 
    INCLUDE (current_location, battery_level) 
    WHERE status = 'available';

-- Index for vehicle type filtering
CREATE INDEX idx_vehicles_type_status ON vehicles(vehicle_type, status);

-- Index for recent updates (for sync optimization)
CREATE INDEX idx_vehicles_location_updated ON vehicles(location_updated_at DESC);

-- ============================================================================
-- TABLE: stations
-- Docking stations for bikes/scooters and transit stops
-- ============================================================================

CREATE TABLE stations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    
    -- External identifiers
    external_id VARCHAR(100) NOT NULL,
    station_code VARCHAR(50),
    
    -- Basic info
    name VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- Location
    location GEOMETRY(Point, 4326) NOT NULL,
    address VARCHAR(300),
    city VARCHAR(100),
    postal_code VARCHAR(20),
    
    -- Capacity (for docking stations)
    total_capacity INT,
    available_vehicles INT DEFAULT 0,
    available_docks INT DEFAULT 0,
    
    -- Station type
    station_type VARCHAR(50),           -- 'dock', 'virtual_station', 'transit_stop'
    
    -- Facilities
    is_charging_station BOOLEAN DEFAULT false,
    is_covered BOOLEAN DEFAULT false,
    has_payment_terminal BOOLEAN DEFAULT false,
    
    -- Operational status
    is_active BOOLEAN DEFAULT true,
    is_renting BOOLEAN DEFAULT true,    -- Can rent from this station
    is_returning BOOLEAN DEFAULT true,  -- Can return to this station
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraint
    CONSTRAINT stations_provider_external_unique UNIQUE (provider_id, external_id)
);

-- Spatial index for station queries
CREATE INDEX idx_stations_location_gist ON stations USING GIST(location);

-- Active stations index
CREATE INDEX idx_stations_active ON stations(provider_id, is_active) WHERE is_active = true;

-- ============================================================================
-- TABLE: trips
-- User trips across all mobility modes
-- ============================================================================

CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_session_id UUID NOT NULL REFERENCES user_sessions(id),
    
    -- Provider & Vehicle info
    provider_id UUID NOT NULL REFERENCES providers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    external_trip_id VARCHAR(100),      -- Trip ID from provider
    
    -- Trip type
    trip_type vehicle_type NOT NULL,
    status trip_status DEFAULT 'planned',
    
    -- Origin
    origin_location GEOMETRY(Point, 4326) NOT NULL,
    origin_address VARCHAR(300),
    origin_station_id UUID REFERENCES stations(id),
    
    -- Destination
    destination_location GEOMETRY(Point, 4326),
    destination_address VARCHAR(300),
    destination_station_id UUID REFERENCES stations(id),
    
    -- Actual route (recorded during trip)
    actual_route GEOMETRY(LineString, 4326),
    
    -- Times
    planned_start_time TIMESTAMP WITH TIME ZONE,
    actual_start_time TIMESTAMP WITH TIME ZONE,
    planned_end_time TIMESTAMP WITH TIME ZONE,
    actual_end_time TIMESTAMP WITH TIME ZONE,
    
    -- Distance & Duration
    estimated_distance_meters INT,
    actual_distance_meters INT,
    estimated_duration_seconds INT,
    actual_duration_seconds INT,
    
    -- Pricing
    estimated_price DECIMAL(10,2),
    actual_price DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'PLN',
    
    -- Deep link used
    deep_link_url TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for user trip history
CREATE INDEX idx_trips_user_session ON trips(user_session_id, created_at DESC);

-- Index for provider analytics
CREATE INDEX idx_trips_provider_status ON trips(provider_id, status);

-- Spatial index for origin/destination queries
CREATE INDEX idx_trips_origin_gist ON trips USING GIST(origin_location);
CREATE INDEX idx_trips_destination_gist ON trips USING GIST(destination_location);

-- ============================================================================
-- TABLE: user_sessions
-- Anonymous user sessions for trip planning and history
-- ============================================================================

CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Session identification
    device_id VARCHAR(200),             -- Unique device identifier
    session_token VARCHAR(500) NOT NULL UNIQUE,
    
    -- User preferences (stored locally, synced optionally)
    preferred_language VARCHAR(5) DEFAULT 'pl',
    preferred_currency VARCHAR(3) DEFAULT 'PLN',
    preferred_vehicle_types vehicle_type[] DEFAULT '{}',
    favorite_providers UUID[] DEFAULT '{}',
    
    -- Last known location (for personalization)
    last_known_location GEOMETRY(Point, 4326),
    last_known_city VARCHAR(100),
    
    -- Push notifications
    push_token VARCHAR(500),
    push_enabled BOOLEAN DEFAULT false,
    
    -- Session status
    is_active BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP + INTERVAL '90 days'
);

-- Index for session lookup
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX idx_user_sessions_device ON user_sessions(device_id);
CREATE INDEX idx_user_sessions_active ON user_sessions(is_active, expires_at);

-- ============================================================================
-- GTFS TABLES (Public Transit)
-- Standard GTFS structure with PostGIS enhancements
-- ============================================================================

-- GTFS: agencies
CREATE TABLE gtfs_agencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    
    agency_id VARCHAR(100) NOT NULL,
    agency_name VARCHAR(200) NOT NULL,
    agency_url VARCHAR(500),
    agency_timezone VARCHAR(50) DEFAULT 'Europe/Warsaw',
    agency_lang VARCHAR(5) DEFAULT 'pl',
    agency_phone VARCHAR(50),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT gtfs_agencies_unique UNIQUE (provider_id, agency_id)
);

-- GTFS: routes
CREATE TABLE gtfs_routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    agency_id UUID REFERENCES gtfs_agencies(id),
    
    route_id VARCHAR(100) NOT NULL,
    route_short_name VARCHAR(50),       -- e.g., "15", "M1"
    route_long_name VARCHAR(300),       -- e.g., "Dworzec Główny - Lotnisko"
    route_type INT NOT NULL,            -- GTFS route type (0=tram, 1=metro, etc.)
    route_color VARCHAR(6),             -- Hex without #
    route_text_color VARCHAR(6),
    route_sort_order INT,
    
    -- Computed vehicle type
    vehicle_type vehicle_type GENERATED ALWAYS AS (
        CASE route_type
            WHEN 0 THEN 'tram'::vehicle_type
            WHEN 1 THEN 'metro'::vehicle_type
            WHEN 2 THEN 'train'::vehicle_type
            WHEN 3 THEN 'bus'::vehicle_type
            WHEN 4 THEN 'ferry'::vehicle_type
            ELSE 'bus'::vehicle_type
        END
    ) STORED,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT gtfs_routes_unique UNIQUE (provider_id, route_id)
);

CREATE INDEX idx_gtfs_routes_type ON gtfs_routes(route_type);
CREATE INDEX idx_gtfs_routes_short_name ON gtfs_routes(route_short_name);

-- GTFS: stops
CREATE TABLE gtfs_stops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    
    stop_id VARCHAR(100) NOT NULL,
    stop_code VARCHAR(50),
    stop_name VARCHAR(200) NOT NULL,
    stop_desc TEXT,
    
    -- Location with PostGIS
    location GEOMETRY(Point, 4326) NOT NULL,
    
    -- Original lat/lon for reference
    stop_lat DECIMAL(10,7) NOT NULL,
    stop_lon DECIMAL(10,7) NOT NULL,
    
    zone_id VARCHAR(50),
    stop_url VARCHAR(500),
    location_type INT DEFAULT 0,        -- 0=stop, 1=station, 2=entrance
    parent_station_id UUID REFERENCES gtfs_stops(id),
    
    -- Accessibility
    wheelchair_boarding INT DEFAULT 0,
    
    -- Platform info
    platform_code VARCHAR(20),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT gtfs_stops_unique UNIQUE (provider_id, stop_id)
);

-- Critical spatial index for stop proximity queries
CREATE INDEX idx_gtfs_stops_location_gist ON gtfs_stops USING GIST(location);
CREATE INDEX idx_gtfs_stops_name_trgm ON gtfs_stops USING GIN(stop_name gin_trgm_ops);

-- GTFS: calendar
CREATE TABLE gtfs_calendar (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    
    service_id VARCHAR(100) NOT NULL,
    monday BOOLEAN DEFAULT false,
    tuesday BOOLEAN DEFAULT false,
    wednesday BOOLEAN DEFAULT false,
    thursday BOOLEAN DEFAULT false,
    friday BOOLEAN DEFAULT false,
    saturday BOOLEAN DEFAULT false,
    sunday BOOLEAN DEFAULT false,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT gtfs_calendar_unique UNIQUE (provider_id, service_id)
);

-- GTFS: calendar_dates (exceptions)
CREATE TABLE gtfs_calendar_dates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    
    service_id VARCHAR(100) NOT NULL,
    exception_date DATE NOT NULL,
    exception_type INT NOT NULL,        -- 1=added, 2=removed
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT gtfs_calendar_dates_unique UNIQUE (provider_id, service_id, exception_date)
);

-- GTFS: trips
CREATE TABLE gtfs_trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    route_id UUID NOT NULL REFERENCES gtfs_routes(id),
    
    trip_id VARCHAR(100) NOT NULL,
    service_id VARCHAR(100) NOT NULL,
    trip_headsign VARCHAR(200),
    trip_short_name VARCHAR(100),
    direction_id INT,
    block_id VARCHAR(100),
    shape_id VARCHAR(100),
    wheelchair_accessible INT DEFAULT 0,
    bikes_allowed INT DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT gtfs_trips_unique UNIQUE (provider_id, trip_id)
);

CREATE INDEX idx_gtfs_trips_route ON gtfs_trips(route_id);
CREATE INDEX idx_gtfs_trips_service ON gtfs_trips(service_id);

-- GTFS: stop_times
CREATE TABLE gtfs_stop_times (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    trip_id UUID NOT NULL REFERENCES gtfs_trips(id),
    stop_id UUID NOT NULL REFERENCES gtfs_stops(id),
    
    arrival_time TIME NOT NULL,
    departure_time TIME NOT NULL,
    stop_sequence INT NOT NULL,
    stop_headsign VARCHAR(200),
    pickup_type INT DEFAULT 0,
    drop_off_type INT DEFAULT 0,
    timepoint INT DEFAULT 1,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Critical indexes for departure board queries
CREATE INDEX idx_gtfs_stop_times_stop ON gtfs_stop_times(stop_id, departure_time);
CREATE INDEX idx_gtfs_stop_times_trip ON gtfs_stop_times(trip_id, stop_sequence);

-- GTFS: shapes (route geometries)
CREATE TABLE gtfs_shapes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    
    shape_id VARCHAR(100) NOT NULL,
    shape_pt_sequence INT NOT NULL,
    shape_pt_location GEOMETRY(Point, 4326) NOT NULL,
    shape_dist_traveled DECIMAL(10,4),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_gtfs_shapes_id ON gtfs_shapes(shape_id, shape_pt_sequence);
CREATE INDEX idx_gtfs_shapes_location_gist ON gtfs_shapes USING GIST(shape_pt_location);

-- ============================================================================
-- TIMESCALEDB: vehicle_positions_history
-- Time-series table for historical position tracking
-- ============================================================================

CREATE TABLE vehicle_positions_history (
    time TIMESTAMP WITH TIME ZONE NOT NULL,
    vehicle_id UUID NOT NULL,
    provider_id UUID NOT NULL,
    
    location GEOMETRY(Point, 4326) NOT NULL,
    heading DECIMAL(5,2),
    speed DECIMAL(6,2),
    battery_level INT,
    status vehicle_status,
    
    -- For GTFS-RT
    trip_id VARCHAR(100),
    route_id VARCHAR(100),
    current_stop_sequence INT,
    current_status VARCHAR(50),         -- 'INCOMING_AT', 'STOPPED_AT', 'IN_TRANSIT_TO'
    
    PRIMARY KEY (time, vehicle_id)
);

-- Convert to TimescaleDB hypertable (partitioned by time)
SELECT create_hypertable('vehicle_positions_history', 'time', 
    chunk_time_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

-- Compression policy (compress chunks older than 24 hours)
ALTER TABLE vehicle_positions_history SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'vehicle_id, provider_id'
);

SELECT add_compression_policy('vehicle_positions_history', INTERVAL '24 hours');

-- Retention policy (keep 30 days of data)
SELECT add_retention_policy('vehicle_positions_history', INTERVAL '30 days');

-- Indexes for time-series queries
CREATE INDEX idx_vehicle_positions_vehicle ON vehicle_positions_history(vehicle_id, time DESC);
CREATE INDEX idx_vehicle_positions_provider ON vehicle_positions_history(provider_id, time DESC);
CREATE INDEX idx_vehicle_positions_location ON vehicle_positions_history USING GIST(location);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function: Get nearby vehicles
CREATE OR REPLACE FUNCTION get_nearby_vehicles(
    p_lat DECIMAL,
    p_lng DECIMAL,
    p_radius_meters INT DEFAULT 500,
    p_vehicle_types vehicle_type[] DEFAULT NULL,
    p_limit INT DEFAULT 50
)
RETURNS TABLE (
    vehicle_id UUID,
    provider_name VARCHAR,
    vehicle_type vehicle_type,
    vehicle_code VARCHAR,
    lat DECIMAL,
    lng DECIMAL,
    distance_meters DECIMAL,
    battery_level INT,
    pricing_unlock DECIMAL,
    pricing_per_minute DECIMAL,
    deep_link TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id AS vehicle_id,
        p.name AS provider_name,
        v.vehicle_type,
        v.vehicle_code,
        ST_Y(v.current_location)::DECIMAL AS lat,
        ST_X(v.current_location)::DECIMAL AS lng,
        ST_Distance(
            v.current_location::geography,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
        )::DECIMAL AS distance_meters,
        v.battery_level,
        v.pricing_unlock_fee AS pricing_unlock,
        v.pricing_per_minute,
        REPLACE(
            REPLACE(p.deep_link_pattern_unlock, '{vehicle_id}', v.external_id),
            '{lat}', p_lat::TEXT
        ) AS deep_link
    FROM vehicles v
    JOIN providers p ON v.provider_id = p.id
    WHERE 
        v.status = 'available'
        AND (p_vehicle_types IS NULL OR v.vehicle_type = ANY(p_vehicle_types))
        AND ST_DWithin(
            v.current_location::geography,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
            p_radius_meters
        )
    ORDER BY distance_meters ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Get upcoming departures
CREATE OR REPLACE FUNCTION get_upcoming_departures(
    p_lat DECIMAL,
    p_lng DECIMAL,
    p_radius_meters INT DEFAULT 500,
    p_minutes_ahead INT DEFAULT 30,
    p_limit INT DEFAULT 50
)
RETURNS TABLE (
    stop_id UUID,
    stop_name VARCHAR,
    route_name VARCHAR,
    route_color VARCHAR,
    vehicle_type vehicle_type,
    departure_time TIME,
    distance_meters DECIMAL,
    trip_headsign VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        gs.id AS stop_id,
        gs.stop_name::VARCHAR,
        gr.route_short_name::VARCHAR AS route_name,
        gr.route_color::VARCHAR,
        gr.vehicle_type,
        gst.departure_time,
        ST_Distance(
            gs.location::geography,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
        )::DECIMAL AS distance_meters,
        gt.trip_headsign::VARCHAR
    FROM gtfs_stops gs
    JOIN gtfs_stop_times gst ON gs.id = gst.stop_id
    JOIN gtfs_trips gt ON gst.trip_id = gt.id
    JOIN gtfs_routes gr ON gt.route_id = gr.id
    WHERE 
        ST_DWithin(
            gs.location::geography,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
            p_radius_meters
        )
        AND gst.departure_time BETWEEN CURRENT_TIME AND CURRENT_TIME + (p_minutes_ahead || ' minutes')::INTERVAL
    ORDER BY gst.departure_time ASC, distance_meters ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all relevant tables
CREATE TRIGGER update_providers_timestamp
    BEFORE UPDATE ON providers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_timestamp
    BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stations_timestamp
    BEFORE UPDATE ON stations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trips_timestamp
    BEFORE UPDATE ON trips
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_sessions_timestamp
    BEFORE UPDATE ON user_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SAMPLE DATA: Providers
-- ============================================================================

INSERT INTO providers (name, slug, type, primary_color, gbfs_feed_url, deep_link_scheme, deep_link_pattern_unlock, supported_vehicle_types, polling_interval_seconds) VALUES
('Bolt Scooters', 'bolt-scooters', 'micromobility', '#34D186', 'https://mds.bolt.eu/gbfs/v2/waw/free_bike_status', 'bolt', 'bolt://scooter/unlock?id={vehicle_id}', ARRAY['scooter']::vehicle_type[], 10),
('Tier', 'tier', 'micromobility', '#69D2AA', 'https://platform.tier-services.io/v2/gbfs/warsaw/free_bike_status', 'tier', 'tier://vehicle/{vehicle_id}', ARRAY['scooter', 'ebike']::vehicle_type[], 10),
('Dott', 'dott', 'micromobility', '#FCCD00', 'https://gbfs.api.ridedott.com/public/v2/warsaw/free_bike_status.json', 'dott', 'dott://unlock/{vehicle_id}', ARRAY['scooter', 'ebike']::vehicle_type[], 10),
('Bolt Taxi', 'bolt-taxi', 'taxi', '#34D186', NULL, 'bolt', 'bolt://ride?pickup_lat={lat}&pickup_lng={lng}', ARRAY['taxi']::vehicle_type[], 30),
('Uber', 'uber', 'taxi', '#000000', NULL, 'uber', 'uber://?action=setPickup&pickup[latitude]={lat}&pickup[longitude]={lng}', ARRAY['taxi']::vehicle_type[], 30),
('ZTM Warszawa', 'ztm-warszawa', 'transit', '#C20831', NULL, NULL, NULL, ARRAY['bus', 'tram', 'metro']::vehicle_type[], 5);

-- Update GTFS URLs for transit provider
UPDATE providers 
SET 
    gtfs_feed_url = 'https://www.ztm.waw.pl/google-transit/gtfs.zip',
    gtfs_realtime_url = 'https://www.ztm.waw.pl/gtfsrt/'
WHERE slug = 'ztm-warszawa';
