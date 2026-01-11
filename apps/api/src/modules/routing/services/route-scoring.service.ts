// ============================================================================
// MaaS Platform - Route Scoring Service
// Algorithm for scoring and ranking routes based on user preferences
// ============================================================================

import { Injectable, Logger } from '@nestjs/common';
import {
  PlannedRouteDto,
  OptimizationMode,
  SegmentType,
} from '../dto/trip-plan.dto';

/**
 * Weights for different optimization modes
 */
interface ScoringWeights {
  time: number;
  cost: number;
  comfort: number;
  transfers: number;
}

/**
 * Normalization constants
 */
interface NormalizationConstants {
  maxDuration: number;      // Maximum expected trip duration (seconds)
  maxCost: number;          // Maximum expected trip cost (PLN)
  maxTransfers: number;     // Maximum expected transfers
  maxWalkDistance: number;  // Maximum expected walk distance (meters)
}

@Injectable()
export class RouteScoringService {
  private readonly logger = new Logger(RouteScoringService.name);

  /**
   * Scoring weights for each optimization mode
   */
  private readonly weights: Record<OptimizationMode, ScoringWeights> = {
    [OptimizationMode.FASTEST]: {
      time: 0.60,
      cost: 0.10,
      comfort: 0.15,
      transfers: 0.15,
    },
    [OptimizationMode.CHEAPEST]: {
      time: 0.15,
      cost: 0.55,
      comfort: 0.15,
      transfers: 0.15,
    },
    [OptimizationMode.COMFORTABLE]: {
      time: 0.20,
      cost: 0.10,
      comfort: 0.45,
      transfers: 0.25,
    },
  };

  /**
   * Normalization constants for scoring
   */
  private readonly normalization: NormalizationConstants = {
    maxDuration: 7200,      // 2 hours
    maxCost: 50,            // 50 PLN
    maxTransfers: 5,        // 5 transfers
    maxWalkDistance: 3000,  // 3 km
  };

  /**
   * Comfort penalties by segment type
   * Lower value = more comfortable
   */
  private readonly comfortPenalties: Record<SegmentType, number> = {
    [SegmentType.METRO]: 0.1,     // Very comfortable
    [SegmentType.RAIL]: 0.15,    // Comfortable
    [SegmentType.TRAM]: 0.2,     // Comfortable
    [SegmentType.BUS]: 0.3,      // Moderate
    [SegmentType.TAXI]: 0.1,     // Very comfortable
    [SegmentType.CAR]: 0.15,     // Comfortable
    [SegmentType.BIKE]: 0.4,     // Physical effort
    [SegmentType.SCOOTER]: 0.35, // Physical effort, weather dependent
    [SegmentType.WALK]: 0.5,     // Physical effort
  };

  /**
   * Score and rank routes based on optimization mode
   */
  scoreAndRankRoutes(
    routes: PlannedRouteDto[],
    mode: OptimizationMode,
  ): PlannedRouteDto[] {
    if (routes.length === 0) {
      return [];
    }

    this.logger.debug(`Scoring ${routes.length} routes with mode: ${mode}`);

    // Calculate scores for each route
    const scoredRoutes = routes.map(route => ({
      ...route,
      score: this.calculateRouteScore(route, mode),
    }));

    // Sort by overall score (descending - higher is better)
    scoredRoutes.sort((a, b) => b.score.overall - a.score.overall);

    // Log top route
    if (scoredRoutes.length > 0) {
      this.logger.debug(
        `Top route: ${scoredRoutes[0].summary} (score: ${scoredRoutes[0].score.overall.toFixed(3)})`,
      );
    }

    return scoredRoutes;
  }

  /**
   * Calculate comprehensive score for a single route
   */
  private calculateRouteScore(
    route: PlannedRouteDto,
    mode: OptimizationMode,
  ): PlannedRouteDto['score'] {
    const w = this.weights[mode];

    // Calculate individual dimension scores (0-1, higher is better)
    const timeScore = this.calculateTimeScore(route);
    const costScore = this.calculateCostScore(route);
    const comfortScore = this.calculateComfortScore(route);
    const transferScore = this.calculateTransferScore(route);

    // Calculate weighted overall score
    const overall =
      w.time * timeScore +
      w.cost * costScore +
      w.comfort * comfortScore +
      w.transfers * transferScore;

    return {
      overall: Math.round(overall * 1000) / 1000,
      time: Math.round(timeScore * 1000) / 1000,
      cost: Math.round(costScore * 1000) / 1000,
      comfort: Math.round(comfortScore * 1000) / 1000,
    };
  }

  /**
   * Calculate time efficiency score
   * Shorter trip = higher score
   */
  private calculateTimeScore(route: PlannedRouteDto): number {
    const normalized = route.duration / this.normalization.maxDuration;
    // Clamp to 0-1 range and invert (shorter = better)
    return Math.max(0, Math.min(1, 1 - normalized));
  }

  /**
   * Calculate cost efficiency score
   * Cheaper trip = higher score
   */
  private calculateCostScore(route: PlannedRouteDto): number {
    const normalized = route.estimatedCost / this.normalization.maxCost;
    // Clamp to 0-1 range and invert (cheaper = better)
    return Math.max(0, Math.min(1, 1 - normalized));
  }

  /**
   * Calculate comfort score based on multiple factors
   */
  private calculateComfortScore(route: PlannedRouteDto): number {
    let comfortScore = 1.0;

    // 1. Penalize based on transport modes used
    for (const segment of route.segments) {
      const penalty = this.comfortPenalties[segment.type] ?? 0.3;
      const segmentWeight = segment.duration / route.duration;
      comfortScore -= penalty * segmentWeight;
    }

    // 2. Penalize excessive walking
    const walkRatio = route.walkDistance / this.normalization.maxWalkDistance;
    const walkPenalty = Math.min(0.3, walkRatio * 0.3);
    comfortScore -= walkPenalty;

    // 3. Penalize waiting time
    const waitRatio = route.waitTime / route.duration;
    const waitPenalty = Math.min(0.2, waitRatio * 0.4);
    comfortScore -= waitPenalty;

    // 4. Bonus for direct routes (no transfers)
    if (route.transfers === 0) {
      comfortScore += 0.1;
    }

    // 5. Bonus for metro-heavy routes (fast and reliable)
    const metroSegments = route.segments.filter(s => s.type === SegmentType.METRO);
    if (metroSegments.length > 0) {
      comfortScore += 0.05;
    }

    // Clamp to 0-1 range
    return Math.max(0, Math.min(1, comfortScore));
  }

  /**
   * Calculate transfer efficiency score
   * Fewer transfers = higher score
   */
  private calculateTransferScore(route: PlannedRouteDto): number {
    const normalized = route.transfers / this.normalization.maxTransfers;
    // Clamp to 0-1 range and invert (fewer = better)
    return Math.max(0, Math.min(1, 1 - normalized));
  }

  /**
   * Get explanation for why a route was ranked highly
   */
  getScoreExplanation(route: PlannedRouteDto, mode: OptimizationMode): string[] {
    const explanations: string[] = [];
    const score = route.score;

    switch (mode) {
      case OptimizationMode.FASTEST:
        if (score.time > 0.7) {
          explanations.push('Najszybsza opcja');
        }
        if (route.transfers === 0) {
          explanations.push('Bezpośrednie połączenie');
        }
        break;

      case OptimizationMode.CHEAPEST:
        if (score.cost > 0.8) {
          explanations.push('Najtańsza opcja');
        }
        if (route.estimatedCost === 0) {
          explanations.push('Darmowa trasa (spacer)');
        } else if (route.estimatedCost < 5) {
          explanations.push('Tylko transport publiczny');
        }
        break;

      case OptimizationMode.COMFORTABLE:
        if (score.comfort > 0.7) {
          explanations.push('Najbardziej komfortowa');
        }
        if (route.walkDistance < 500) {
          explanations.push('Mało spacerowania');
        }
        if (route.transfers <= 1) {
          explanations.push('Minimalne przesiadki');
        }
        break;
    }

    // Add general observations
    const hasScooter = route.segments.some(s => s.type === SegmentType.SCOOTER);
    const hasBike = route.segments.some(s => s.type === SegmentType.BIKE);

    if (hasScooter) {
      explanations.push('Wykorzystuje hulajnogę (first/last mile)');
    }
    if (hasBike) {
      explanations.push('Wykorzystuje rower');
    }

    return explanations;
  }

  /**
   * Filter routes that don't meet minimum criteria
   */
  filterViableRoutes(routes: PlannedRouteDto[]): PlannedRouteDto[] {
    return routes.filter(route => {
      // Remove routes that are too long
      if (route.duration > this.normalization.maxDuration * 1.5) {
        return false;
      }

      // Remove routes with too many transfers
      if (route.transfers > this.normalization.maxTransfers) {
        return false;
      }

      // Remove routes with excessive walking
      if (route.walkDistance > this.normalization.maxWalkDistance * 1.5) {
        return false;
      }

      return true;
    });
  }

  /**
   * Compare two routes and return the better one based on mode
   */
  compareTwoRoutes(
    routeA: PlannedRouteDto,
    routeB: PlannedRouteDto,
    mode: OptimizationMode,
  ): PlannedRouteDto {
    const scoreA = this.calculateRouteScore(routeA, mode);
    const scoreB = this.calculateRouteScore(routeB, mode);
    
    return scoreA.overall >= scoreB.overall ? routeA : routeB;
  }

  /**
   * Get diversity bonus - prefer varied route options
   * Returns routes with different main modes of transport
   */
  ensureRouteDiversity(routes: PlannedRouteDto[], maxRoutes: number = 5): PlannedRouteDto[] {
    if (routes.length <= maxRoutes) {
      return routes;
    }

    const selectedRoutes: PlannedRouteDto[] = [];
    const seenMainModes = new Set<string>();

    // First pass: select routes with unique main transport mode
    for (const route of routes) {
      if (selectedRoutes.length >= maxRoutes) break;

      const mainMode = this.getMainTransportMode(route);
      if (!seenMainModes.has(mainMode)) {
        selectedRoutes.push(route);
        seenMainModes.add(mainMode);
      }
    }

    // Second pass: fill remaining slots with best scoring routes
    for (const route of routes) {
      if (selectedRoutes.length >= maxRoutes) break;
      if (!selectedRoutes.includes(route)) {
        selectedRoutes.push(route);
      }
    }

    return selectedRoutes;
  }

  /**
   * Determine the main transport mode of a route
   */
  private getMainTransportMode(route: PlannedRouteDto): string {
    let maxDuration = 0;
    let mainMode = SegmentType.WALK;

    for (const segment of route.segments) {
      // Skip walking for main mode determination
      if (segment.type !== SegmentType.WALK && segment.duration > maxDuration) {
        maxDuration = segment.duration;
        mainMode = segment.type;
      }
    }

    return mainMode;
  }
}
