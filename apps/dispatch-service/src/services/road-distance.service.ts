import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError, type AxiosResponse } from 'axios';

/**
 * OSRM driving distance client (mirrors Laravel RoadDistanceService).
 * Returns null when routing is not configured or the provider fails so the
 * caller can fall back to the Laravel-exact error message.
 */
@Injectable()
export class RoadDistanceService {
  private readonly logger = new Logger(RoadDistanceService.name);

  constructor(private readonly config: ConfigService) {}

  async distanceKm(
    fromLat: number,
    fromLng: number,
    toLat: number,
    toLng: number,
  ): Promise<number | null> {
    const baseUrl = this.config.get<string>('ROUTING_BASE_URL', '');
    if (baseUrl === undefined || baseUrl.trim() === '') {
      return null;
    }

    const coordinates = `${fromLng},${fromLat};${toLng},${toLat}`;
    const connectTimeout = Number(this.config.get('ROUTING_CONNECT_TIMEOUT_MS', 2000));
    const timeout = Number(this.config.get('ROUTING_TIMEOUT_MS', 5000));

    let response: AxiosResponse;
    try {
      response = await axios.get(
        `${baseUrl.replace(/\/+$/, '')}/route/v1/driving/${coordinates}`,
        {
          params: { overview: 'false', alternatives: 'false' },
          timeout: timeout + connectTimeout,
        },
      );
    } catch (error) {
      this.logger.warn(`Routing provider unreachable: ${(error as AxiosError).message}`);
      return null;
    }

    const body = response.data as { code?: string; routes?: Array<{ distance?: number }> };
    if (body.code !== 'Ok') {
      return null;
    }

    const distanceMeters = body.routes?.[0]?.distance;
    if (typeof distanceMeters !== 'number' || Number.isNaN(distanceMeters)) {
      return null;
    }
    return distanceMeters / 1000;
  }
}