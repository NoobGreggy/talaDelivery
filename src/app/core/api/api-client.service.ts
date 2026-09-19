import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, map } from 'rxjs';
import { environment } from '../../../environments/environment';

interface Envelope<T> {
  success: boolean;
  message: string;
  data: T;
}

@Injectable({ providedIn: 'root' })
export class ApiClientService {
  private http = inject(HttpClient);
  private baseUrl = environment.apiBaseUrl;

  get<T>(path: string, params?: Record<string, string>): Observable<T> {
    let httpParams = new HttpParams();
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value) httpParams = httpParams.set(key, value);
      });
    }
    return this.http
      .get<Envelope<T>>(`${this.baseUrl}${path}`, { params: httpParams })
      .pipe(map((response) => response.data));
  }

  post<T>(path: string, body?: unknown): Observable<T> {
    return this.http
      .post<Envelope<T>>(`${this.baseUrl}${path}`, body)
      .pipe(map((response) => response.data));
  }

  put<T>(path: string, body?: unknown): Observable<T> {
    return this.http
      .put<Envelope<T>>(`${this.baseUrl}${path}`, body)
      .pipe(map((response) => response.data));
  }

  patch<T>(path: string, body?: unknown): Observable<T> {
    return this.http
      .patch<Envelope<T>>(`${this.baseUrl}${path}`, body)
      .pipe(map((response) => response.data));
  }

  delete<T>(path: string): Observable<T> {
    return this.http
      .delete<Envelope<T>>(`${this.baseUrl}${path}`)
      .pipe(map((response) => response.data));
  }
}