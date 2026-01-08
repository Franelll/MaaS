// ============================================================================
// MaaS Platform - WebSocket Gateway for Real-time Updates
// Socket.io server for pushing vehicle positions to mobile clients
// ============================================================================

import { Server, Socket } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { Redis } from 'ioredis';
import {
  GeoLocation,
  BoundingBox,
  UnifiedMapEntity,
  MapEntityType,
} from '@maas/common';

/**
 * Client subscription for real-time updates
 */
interface ClientSubscription {
  socketId: string;
  boundingBox?: BoundingBox;
  centerLocation?: GeoLocation;
  radiusMeters?: number;
  entityTypes: MapEntityType[];
  providers?: string[];
}

/**
 * WebSocket event types
 */
export enum WSEvent {
  // Client -> Server
  SUBSCRIBE_AREA = 'subscribe:area',
  UNSUBSCRIBE_AREA = 'unsubscribe:area',
  UPDATE_LOCATION = 'update:location',
  
  // Server -> Client
  VEHICLES_UPDATE = 'vehicles:update',
  STATIONS_UPDATE = 'stations:update',
  TRANSIT_UPDATE = 'transit:update',
  ERROR = 'error',
}

/**
 * Real-time Gateway Configuration
 */
export interface RealtimeGatewayConfig {
  redisUrl: string;
  corsOrigin: string | string[];
  pingInterval?: number;
  pingTimeout?: number;
}

/**
 * Real-time WebSocket Gateway
 * Manages client subscriptions and broadcasts vehicle updates
 */
export class RealtimeGateway {
  private io!: Server;
  private subscriptions: Map<string, ClientSubscription> = new Map();
  private pubClient!: Redis;
  private subClient!: Redis;

  constructor(private readonly config: RealtimeGatewayConfig) {}

  /**
   * Initialize the WebSocket server
   */
  async initialize(httpServer: any): Promise<void> {
    // Create Socket.io server
    this.io = new Server(httpServer, {
      cors: {
        origin: this.config.corsOrigin,
        methods: ['GET', 'POST'],
        credentials: true,
      },
      pingInterval: this.config.pingInterval || 25000,
      pingTimeout: this.config.pingTimeout || 20000,
      transports: ['websocket', 'polling'],
    });

    // Setup Redis adapter for horizontal scaling
    this.pubClient = new Redis(this.config.redisUrl);
    this.subClient = this.pubClient.duplicate();
    
    this.io.adapter(createAdapter(this.pubClient, this.subClient));

    // Setup connection handlers
    this.setupConnectionHandlers();

    console.log('[WebSocket] Gateway initialized');
  }

  /**
   * Setup connection and event handlers
   */
  private setupConnectionHandlers(): void {
    this.io.on('connection', (socket: Socket) => {
      console.log(`[WebSocket] Client connected: ${socket.id}`);

      // Handle area subscription
      socket.on(WSEvent.SUBSCRIBE_AREA, (data: SubscribeAreaPayload) => {
        this.handleSubscribeArea(socket, data);
      });

      // Handle unsubscription
      socket.on(WSEvent.UNSUBSCRIBE_AREA, () => {
        this.handleUnsubscribeArea(socket);
      });

      // Handle location update (for optimizing data sent to client)
      socket.on(WSEvent.UPDATE_LOCATION, (data: UpdateLocationPayload) => {
        this.handleUpdateLocation(socket, data);
      });

      // Handle disconnection
      socket.on('disconnect', (reason: string) => {
        console.log(`[WebSocket] Client disconnected: ${socket.id}, reason: ${reason}`);
        this.subscriptions.delete(socket.id);
      });

      // Handle errors
      socket.on('error', (error: Error) => {
        console.error(`[WebSocket] Socket error: ${socket.id}`, error);
      });
    });
  }

  /**
   * Handle client subscribing to an area
   */
  private handleSubscribeArea(socket: Socket, data: SubscribeAreaPayload): void {
    const subscription: ClientSubscription = {
      socketId: socket.id,
      entityTypes: data.entityTypes || ['scooter', 'bike', 'ebike', 'transit_stop'],
      providers: data.providers,
    };

    if (data.boundingBox) {
      subscription.boundingBox = data.boundingBox;
      // Join room based on grid cell
      const rooms = this.getBoundingBoxRooms(data.boundingBox);
      rooms.forEach(room => socket.join(room));
    } else if (data.centerLocation && data.radiusMeters) {
      subscription.centerLocation = data.centerLocation;
      subscription.radiusMeters = data.radiusMeters;
      // Join room based on center grid cell
      const room = this.getLocationRoom(data.centerLocation);
      socket.join(room);
    }

    this.subscriptions.set(socket.id, subscription);
    
    console.log(`[WebSocket] Client ${socket.id} subscribed to area`);
    
    // Acknowledge subscription
    socket.emit('subscribed', { 
      status: 'ok',
      entityTypes: subscription.entityTypes,
    });
  }

  /**
   * Handle client unsubscribing from area
   */
  private handleUnsubscribeArea(socket: Socket): void {
    const subscription = this.subscriptions.get(socket.id);
    if (subscription) {
      // Leave all rooms
      socket.rooms.forEach((room: string) => {
        if (room !== socket.id) {
          socket.leave(room);
        }
      });
      this.subscriptions.delete(socket.id);
    }
    
    socket.emit('unsubscribed', { status: 'ok' });
  }

  /**
   * Handle location update from client
   */
  private handleUpdateLocation(socket: Socket, data: UpdateLocationPayload): void {
    const subscription = this.subscriptions.get(socket.id);
    if (!subscription) return;

    // Update subscription location
    if (data.centerLocation) {
      subscription.centerLocation = data.centerLocation;
      
      // Update room membership
      const newRoom = this.getLocationRoom(data.centerLocation);
      socket.rooms.forEach((room: string) => {
        if (room !== socket.id && room !== newRoom) {
          socket.leave(room);
        }
      });
      socket.join(newRoom);
    }

    if (data.boundingBox) {
      subscription.boundingBox = data.boundingBox;
    }

    this.subscriptions.set(socket.id, subscription);
  }

  /**
   * Broadcast vehicle updates to subscribed clients
   */
  async broadcastVehicleUpdates(
    vehicles: UnifiedMapEntity[],
    providerId: string
  ): Promise<void> {
    if (vehicles.length === 0) return;

    // Group vehicles by grid cell rooms
    const vehiclesByRoom = new Map<string, UnifiedMapEntity[]>();

    for (const vehicle of vehicles) {
      const room = this.getLocationRoom(vehicle.location);
      if (!vehiclesByRoom.has(room)) {
        vehiclesByRoom.set(room, []);
      }
      vehiclesByRoom.get(room)!.push(vehicle);
    }

    // Broadcast to each room
    for (const [room, roomVehicles] of vehiclesByRoom) {
      this.io.to(room).emit(WSEvent.VEHICLES_UPDATE, {
        providerId,
        vehicles: roomVehicles,
        timestamp: new Date().toISOString(),
        count: roomVehicles.length,
      });
    }
  }

  /**
   * Broadcast to specific clients based on their subscriptions
   */
  async broadcastToSubscribers(
    vehicles: UnifiedMapEntity[],
    providerId: string
  ): Promise<void> {
    for (const [socketId, subscription] of this.subscriptions) {
      // Filter vehicles based on subscription
      const filteredVehicles = vehicles.filter(v => {
        // Filter by entity type
        if (!subscription.entityTypes.includes(v.type)) {
          return false;
        }

        // Filter by provider
        if (subscription.providers && !subscription.providers.includes(v.provider.slug)) {
          return false;
        }

        // Filter by location
        if (subscription.boundingBox) {
          return this.isInBoundingBox(v.location, subscription.boundingBox);
        }
        
        if (subscription.centerLocation && subscription.radiusMeters) {
          return this.isWithinRadius(
            v.location,
            subscription.centerLocation,
            subscription.radiusMeters
          );
        }

        return true;
      });

      if (filteredVehicles.length > 0) {
        this.io.to(socketId).emit(WSEvent.VEHICLES_UPDATE, {
          providerId,
          vehicles: filteredVehicles,
          timestamp: new Date().toISOString(),
          count: filteredVehicles.length,
        });
      }
    }
  }

  /**
   * Broadcast transit real-time updates
   */
  async broadcastTransitUpdates(
    vehicles: UnifiedMapEntity[],
    providerId: string
  ): Promise<void> {
    // Similar to vehicle updates but for transit
    const vehiclesByRoom = new Map<string, UnifiedMapEntity[]>();

    for (const vehicle of vehicles) {
      const room = this.getLocationRoom(vehicle.location);
      if (!vehiclesByRoom.has(room)) {
        vehiclesByRoom.set(room, []);
      }
      vehiclesByRoom.get(room)!.push(vehicle);
    }

    for (const [room, roomVehicles] of vehiclesByRoom) {
      this.io.to(room).emit(WSEvent.TRANSIT_UPDATE, {
        providerId,
        vehicles: roomVehicles,
        timestamp: new Date().toISOString(),
        count: roomVehicles.length,
      });
    }
  }

  /**
   * Get room name based on location (grid-based)
   * Uses ~1km grid cells for efficient broadcasting
   */
  private getLocationRoom(location: GeoLocation): string {
    // Round to 2 decimal places (~1km grid)
    const latGrid = Math.floor(location.lat * 100) / 100;
    const lngGrid = Math.floor(location.lng * 100) / 100;
    return `grid:${latGrid}:${lngGrid}`;
  }

  /**
   * Get all rooms that intersect with a bounding box
   */
  private getBoundingBoxRooms(bbox: BoundingBox): string[] {
    const rooms: string[] = [];
    const step = 0.01; // ~1km grid step

    for (let lat = Math.floor(bbox.south * 100) / 100; lat <= bbox.north; lat += step) {
      for (let lng = Math.floor(bbox.west * 100) / 100; lng <= bbox.east; lng += step) {
        rooms.push(`grid:${lat.toFixed(2)}:${lng.toFixed(2)}`);
      }
    }

    return rooms;
  }

  /**
   * Check if location is within bounding box
   */
  private isInBoundingBox(location: GeoLocation, bbox: BoundingBox): boolean {
    return (
      location.lat >= bbox.south &&
      location.lat <= bbox.north &&
      location.lng >= bbox.west &&
      location.lng <= bbox.east
    );
  }

  /**
   * Check if location is within radius of center
   */
  private isWithinRadius(
    location: GeoLocation,
    center: GeoLocation,
    radiusMeters: number
  ): boolean {
    const distance = this.calculateDistance(location, center);
    return distance <= radiusMeters;
  }

  /**
   * Calculate distance between two points (Haversine formula)
   */
  private calculateDistance(point1: GeoLocation, point2: GeoLocation): number {
    const R = 6371000; // Earth radius in meters
    const dLat = this.toRad(point2.lat - point1.lat);
    const dLng = this.toRad(point2.lng - point1.lng);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(point1.lat)) *
        Math.cos(this.toRad(point2.lat)) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  private toRad(deg: number): number {
    return deg * (Math.PI / 180);
  }

  /**
   * Get connection statistics
   */
  getStats(): { connectedClients: number; subscriptions: number } {
    return {
      connectedClients: this.io?.sockets.sockets.size || 0,
      subscriptions: this.subscriptions.size,
    };
  }

  /**
   * Shutdown the gateway
   */
  async shutdown(): Promise<void> {
    this.io?.close();
    await this.pubClient?.quit();
    await this.subClient?.quit();
    console.log('[WebSocket] Gateway shutdown');
  }
}

// ==========================================================================
// Payload Types
// ==========================================================================

interface SubscribeAreaPayload {
  boundingBox?: BoundingBox;
  centerLocation?: GeoLocation;
  radiusMeters?: number;
  entityTypes?: MapEntityType[];
  providers?: string[];
}

interface UpdateLocationPayload {
  centerLocation?: GeoLocation;
  boundingBox?: BoundingBox;
}
