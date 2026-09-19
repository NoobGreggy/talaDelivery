import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from './auth.service';
import { environment } from '../../../environments/environment';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  const router = inject(Router);
  const token = authService.getToken();

  const authReq = token
    ? req.clone({
        setHeaders: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/json',
          'X-App-Key': environment.appKey,
          ...(req.url.includes('/store/') && authService.getStoreId()
            ? { 'X-Store-Id': String(authService.getStoreId()) }
            : {})
        }
      })
    : req.clone({
        setHeaders: {
          Accept: 'application/json',
          'X-App-Key': environment.appKey
        }
      });

  return next(authReq);
};