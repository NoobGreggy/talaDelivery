import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError, type AxiosRequestConfig, type AxiosResponse } from 'axios';
import { randomUUID } from 'node:crypto';
import { REQUEST_CONTEXT_HEADERS, requestContext } from './request-context';

export interface ServiceCallFailure extends Error {
  status: number;
  code?: string;
  body: unknown;
}

/** Raised when a synchronous service-to-service call fails after retries/timeout. */
export class ServiceCallError extends Error implements ServiceCallFailure {
  readonly status: number;
  readonly code?: string;
  readonly body: unknown;

  constructor(message: string, status: number, body: unknown, code?: string) {
    super(message);
    this.name = 'ServiceCallError';
    this.status = status;
    this.body = body;
    this.code = code;
  }
}

export interface ServiceClientOptions {
  baseUrl: string;
  token: string;
  timeoutMs?: number;
  retries?: number;
}

/**
 * Minimal synchronous HTTP client for service-to-service calls.
 * Always includes the internal service token and correlation id.
 */
export class ServiceClient {
  constructor(private readonly options: ServiceClientOptions) {}

  private request<T>(config: AxiosRequestConfig): Promise<T> {
    const retries = this.options.retries ?? 1;
    let lastError: unknown;
    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        return this.doRequest<T>(config);
      } catch (error) {
        lastError = error;
        if (!shouldRetry(error) || attempt === retries) {
          break;
        }
      }
    }
    throw lastError;
  }

  private async doRequest<T>(config: AxiosRequestConfig): Promise<T> {
    const ctx = requestContext();
    const headers = {
      [REQUEST_CONTEXT_HEADERS.serviceToken]: this.options.token,
      ...(ctx.correlationId ? { [REQUEST_CONTEXT_HEADERS.correlationId]: ctx.correlationId } : {}),
      ...(ctx.requestId ? { [REQUEST_CONTEXT_HEADERS.requestId]: ctx.requestId } : {}),
      'x-request-id': ctx.requestId ?? randomUUID(),
      ...(config.headers ?? {}),
    };

    let response: AxiosResponse<{ success: boolean; message?: string; data?: unknown; code?: string }>;
    try {
      response = await axios.request<{ success: boolean; message?: string; data?: unknown; code?: string }>({
        ...config,
        baseURL: this.options.baseUrl,
        headers,
        timeout: this.options.timeoutMs ?? 5000,
        validateStatus: () => true,
      });
    } catch (error) {
      const axiosError = error as AxiosError;
      throw new ServiceCallError(
        `Service call failed: ${config.method ?? 'GET'} ${config.url ?? ''} - ${axiosError.message}`,
        axiosError.response?.status ?? 500,
        axiosError.response?.data ?? null,
      );
    }

    if (response.status >= 400) {
      throw new ServiceCallError(
        (response.data?.message as string | undefined) ?? 'Upstream service returned an error.',
        response.status,
        response.data,
        response.data?.code,
      );
    }

    return (response.data?.data ?? response.data) as T;
  }

  async get<T>(url: string, params?: Record<string, unknown>): Promise<T> {
    return this.request<T>({ method: 'GET', url, params });
  }

  async post<T>(url: string, data?: unknown): Promise<T> {
    return this.request<T>({ method: 'POST', url, data });
  }

  async put<T>(url: string, data?: unknown): Promise<T> {
    return this.request<T>({ method: 'PUT', url, data });
  }

  async patch<T>(url: string, data?: unknown): Promise<T> {
    return this.request<T>({ method: 'PATCH', url, data });
  }

  async delete<T>(url: string): Promise<T> {
    return this.request<T>({ method: 'DELETE', url });
  }
}

function shouldRetry(error: unknown): boolean {
  if (error instanceof ServiceCallError) {
    return error.status >= 500 || error.status === 0;
  }
  return false;
}

@Injectable()
export class ServiceClientFactory {
  constructor(private readonly config: ConfigService) {}

  create(target: string, overrides?: Partial<ServiceClientOptions>): ServiceClient {
    return new ServiceClient({
      baseUrl: this.config.get<string>(target) ?? '',
      token: this.config.get<string>('INTERNAL_API_TOKEN') ?? '',
      timeoutMs: Number(this.config.get('SERVICE_CALL_TIMEOUT_MS', 5000)),
      ...overrides,
    });
  }
}