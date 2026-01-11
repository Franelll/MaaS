// ============================================================================
// MaaS Platform - ZTM Warsaw Realtime Service
// Fetches live bus/tram positions from Warsaw Public Transport API
// ============================================================================

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import {
  TransitVehicleEntity,
  ProviderInfo,
  TransitVehicleMetadata,
} from '@maas/common';

/**
 * ZTM API Response Format
 */
interface ZTMApiResponse {
  result: Array<{
    Lines: string;
    Lon: number;
    Lat: number;
    VehicleNumber: string;
    Time: string;
    Brigade: string;
  }>;
}

@Injectable()
export class ZtmPollerService {
  private readonly logger = new Logger(ZtmPollerService.name);
  private readonly apiKey: string;
  private readonly baseUrl = 'https://api.um.warszawa.pl/api/action';
  
  private readonly BUS_RESOURCE_ID = 'f2e5503e-927d-4ad3-9500-4ab9e55deb59';
  private readonly TRAM_RESOURCE_ID = '3bb6c9b5-d2d0-4393-9c67-c1a8c8e16c87';

  private readonly providerInfo: ProviderInfo = {
    id: 'ztm-warszawa',
    name: 'ZTM Warszawa',
    slug: 'ztm',
    type: 'transit',
    color: '#E30613',
  };

  constructor(
    private readonly configService: ConfigService,
    private readonly httpService: HttpService,
  ) {
    this.apiKey = this.configService.get<string>('ZTM_API_KEY') || process.env.ZTM_API_KEY || '';
    
    if (!this.apiKey) {
      this.logger.warn('⚠️  ZTM_API_KEY not found in environment!');
    } else {
      this.logger.log(`✅ ZTM Poller initialized with API key: ${this.apiKey.substring(0, 8)}...`);
    }
  }

  async fetchBuses(): Promise<TransitVehicleEntity[]> {
    return this.fetchVehicles('bus', this.BUS_RESOURCE_ID);
  }

  async fetchTrams(): Promise<TransitVehicleEntity[]> {
    return this.fetchVehicles('tram', this.TRAM_RESOURCE_ID);
  }

  async fetchAll(): Promise<TransitVehicleEntity[]> {
    const [buses, trams] = await Promise.all([
      this.fetchBuses(),
      this.fetchTrams(),
    ]);

    this.logger.log(`📡 ZTM Data: ${buses.length} buses + ${trams.length} trams = ${buses.length + trams.length} total`);
    console.log(`[ZTM] Fetched ${buses.length + trams.length} vehicles from Warsaw API`);
    
    return [...buses, ...trams];
  }

  private async fetchVehicles(
    type: 'bus' | 'tram',
    resourceId: string,
  ): Promise<TransitVehicleEntity[]> {
    try {
      const url = `${this.baseUrl}/busestrams_get/`;
      const params = {
        resource_id: resourceId,
        apikey: this.apiKey,
        type: type === 'bus' ? '1' : '2',
      };

      this.logger.debug(`🔄 Fetching ${type}s...`);
      
      const response = await firstValueFrom(
        this.httpService.get<ZTMApiResponse>(url, { params }),
      );

      const vehicles = response.data.result || [];
      return vehicles.map(v => this.mapToEntity(v, type));
    } catch (error) {
      this.logger.error(`❌ Error fetching ${type}s:`, error instanceof Error ? error.message : String(error));
      return [];
    }
  }

  private mapToEntity(
    ztmVehicle: ZTMApiResponse['result'][0],
    type: 'bus' | 'tram',
  ): TransitVehicleEntity {
    const entityType = type === 'bus' ? 'bus_realtime' : 'tram_realtime';
    
    return {
      id: `ztm-${type}-${ztmVehicle.VehicleNumber}`,
      type: entityType,
      provider: this.providerInfo,
      location: {
        lat: ztmVehicle.Lat,
        lng: ztmVehicle.Lon,
      },
      lastUpdated: new Date(ztmVehicle.Time),
      metadata: {
        vehicleId: ztmVehicle.VehicleNumber,
        tripId: `${ztmVehicle.Lines}-${ztmVehicle.Brigade}`,
        routeId: ztmVehicle.Lines,
        routeShortName: ztmVehicle.Lines,
        routeColor: type === 'bus' ? '#E30613' : '#FFD800',
        headsign: `Line ${ztmVehicle.Lines}`,
        heading: 0,
        speed: 0,
        currentStopSequence: 0,
        status: 'IN_TRANSIT_TO',
        delay: undefined,
      } as TransitVehicleMetadata,
    };
  }
}
