import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DomainError } from '@taladelivery/common';
import { EVENTS_REDIS_CLIENT } from '@taladelivery/events';
import type Redis from 'ioredis';
import axios, { type AxiosResponse } from 'axios';
import { createHash } from 'node:crypto';

export interface PlaceBoundaryResult {
  place_id: string;
  name: string;
  display_name: string;
  type: string;
  city: string | null;
  province: string | null;
  geometry: { type: string; coordinates: unknown };
  bounding_box: number[];
}

export type PlaceType = 'city' | 'province';

/**
 * Nominatim boundary search with Redis caching (mirrors
 * PlaceBoundarySearchService). Errors match Laravel exactly.
 */
@Injectable()
export class PlaceBoundarySearchService {
  private readonly logger = new Logger(PlaceBoundarySearchService.name);
  private readonly cachePrefix = 'taladelivery:place-boundary:';

  constructor(
    private readonly config: ConfigService,
    @Inject(EVENTS_REDIS_CLIENT) private readonly redis: Redis,
  ) {}

  async search(query: string, type: string): Promise<PlaceBoundaryResult[]> {
    const normalizedQuery = query.replace(/\s+/g, ' ').trim().toLowerCase();
    const cacheKey =
      this.cachePrefix + `${type}:${createHash('sha1').update(normalizedQuery).digest('hex')}`;

    const cached = await this.redis.get(cacheKey);
    if (cached !== null) {
      return JSON.parse(cached) as PlaceBoundaryResult[];
    }

    const results = await this.request(query, type);
    const ttlDays = Number(this.config.get('GEOCODING_CACHE_DAYS', 30));
    await this.redis.set(cacheKey, JSON.stringify(results), 'EX', Math.floor(ttlDays * 86400));
    return results;
  }

  private async request(query: string, type: string): Promise<PlaceBoundaryResult[]> {
    const baseUrl = this.config.get<string>('GEOCODING_BASE_URL', '').trim().replace(/\/+$/, '');
    if (baseUrl === '') {
      throw new DomainError('Boundary search is not configured.');
    }

    let response: AxiosResponse;
    try {
      response = await axios.get(`${baseUrl}/search`, {
        headers: {
          Accept: 'application/json',
          'User-Agent': this.config.get<string>('GEOCODING_USER_AGENT', 'taladelivery-backend'),
        },
        params: {
          q: query,
          format: 'jsonv2',
          addressdetails: 1,
          polygon_geojson: 1,
          polygon_threshold: 0.0005,
          countrycodes: 'ph',
          featureType: type === 'province' ? 'state' : 'city',
          limit: 5,
        },
        timeout: 15000,
      });
    } catch {
      throw new DomainError('The boundary search service is temporarily unavailable.');
    }

    const body = response.data;
    if (!Array.isArray(body) || body.some((item) => !item || typeof item !== 'object')) {
      throw new DomainError('The boundary search service is temporarily unavailable.');
    }

    return body
      .filter(
        (result): boolean =>
          result.geojson !== undefined &&
          (result.geojson.type === 'Polygon' || result.geojson.type === 'MultiPolygon'),
      )
      .map((result): PlaceBoundaryResult => this.normalizeResult(result));
  }

  private normalizeResult(result: Record<string, unknown>): PlaceBoundaryResult {
    const address = (result.address ?? {}) as Record<string, unknown>;
    const addressValue = (...keys: string[]): string | null => {
      for (const key of keys) {
        const value = address[key];
        if (typeof value === 'string' && value !== '') {
          return value;
        }
      }
      return null;
    };

    return {
      place_id: String(result.place_id ?? ''),
      name: String(result.name ?? result.display_name ?? ''),
      display_name: String(result.display_name ?? ''),
      type: String(result.addresstype ?? result.type ?? 'administrative'),
      city: addressValue('city', 'municipality', 'town', 'city_district', 'county'),
      province: addressValue('state', 'region', 'province'),
      geometry: result.geojson as { type: string; coordinates: unknown },
      bounding_box: Array.isArray(result.boundingbox)
        ? (result.boundingbox as unknown[]).map((value) => Number(value))
        : [],
    };
  }
}