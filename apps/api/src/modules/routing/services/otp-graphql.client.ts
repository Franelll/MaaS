// ============================================================================
// MaaS Platform - OTP GraphQL Client
// HTTP client for communicating with OpenTripPlanner GraphQL API
// ============================================================================

import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom, timeout, retry, catchError } from 'rxjs';
import { AxiosError, AxiosResponse } from 'axios';
import {
  OtpPlanResponse,
  OtpPlanQueryVariables,
} from '../interfaces/otp-response.interface';
import {
  PLAN_TRIP_QUERY,
  HEALTH_CHECK_QUERY,
} from '../constants/otp-queries';

@Injectable()
export class OtpGraphqlClient implements OnModuleInit {
  private readonly logger = new Logger(OtpGraphqlClient.name);
  private otpUrl: string;
  private readonly defaultTimeout = 25000; // 25 seconds

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
  ) {
    // Default to local Docker network URL
    this.otpUrl = this.configService.get<string>(
      'OTP_URL',
      'http://otp:8080/otp/routers/default/index/graphql',
    );
  }

  async onModuleInit(): Promise<void> {
    this.logger.log(`OTP GraphQL Client initialized with URL: ${this.otpUrl}`);
    
    // Check OTP connectivity on startup (non-blocking)
    this.healthCheck()
      .then((isHealthy) => {
        if (isHealthy) {
          this.logger.log('✅ OTP connection successful');
        } else {
          this.logger.warn('⚠️ OTP connection failed - routing will not work');
        }
      })
      .catch((error) => {
        this.logger.warn('⚠️ OTP health check failed on startup', error);
      });
  }

  /**
   * Execute a GraphQL query against OTP
   */
  async query<T>(
    query: string,
    variables: Record<string, unknown> = {},
    options?: { timeoutMs?: number; retryCount?: number; retryDelayMs?: number },
  ): Promise<T> {
    this.logger.debug(`Executing OTP query with variables: ${JSON.stringify(variables)}`);

    const timeoutMs = options?.timeoutMs ?? this.defaultTimeout;
    const retryCount = options?.retryCount ?? 2;
    const retryDelayMs = options?.retryDelayMs ?? 1000;

    try {
      const response = await firstValueFrom<AxiosResponse<T>>(
        this.httpService
          .post<T>(
            this.otpUrl,
            {
              query,
              variables,
            },
            {
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            },
          )
          .pipe(
            timeout(timeoutMs),
            retry({ count: retryCount, delay: retryDelayMs }),
            catchError((error: AxiosError) => {
              this.logger.error(`OTP query failed: ${error.message}`);
              throw error;
            }),
          ),
      );

      return response.data;
    } catch (error) {
      this.logger.error(`OTP GraphQL query failed`, error);
      throw error;
    }
  }

  /**
   * Plan a trip using OTP
   */
  async planTrip(variables: OtpPlanQueryVariables): Promise<OtpPlanResponse> {
    this.logger.log(
      `Planning trip: (${variables.from.lat}, ${variables.from.lon}) → (${variables.to.lat}, ${variables.to.lon})`,
    );

    const response = await this.query<OtpPlanResponse>(PLAN_TRIP_QUERY, variables);

    // Log any routing errors
    if (response.data?.plan?.routingErrors?.length) {
      this.logger.warn(
        `OTP routing errors: ${JSON.stringify(response.data.plan.routingErrors)}`,
      );
    }

    return response;
  }

  /**
   * Check if OTP is healthy and responding
   */
  async healthCheck(): Promise<boolean> {
    try {
      const response = await this.query<{ data: { serviceTimeRange: { start: number; end: number } } }>(
        HEALTH_CHECK_QUERY,
        {},
        { timeoutMs: 2000, retryCount: 0 },
      );
      return !!response.data?.serviceTimeRange;
    } catch (error) {
      this.logger.debug('OTP health check failed', error);
      return false;
    }
  }

  /**
   * Get the configured OTP URL
   */
  getOtpUrl(): string {
    return this.otpUrl;
  }
}
