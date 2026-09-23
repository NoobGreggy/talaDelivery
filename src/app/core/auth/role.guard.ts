import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

export const roleGuard: CanActivateFn = (route) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  const requiredRole = route.data['role'] as string;

  if (!authService.isAuthenticated()) {
    return router.createUrlTree(['/login']);
  }

  if (requiredRole && !authService.hasRole(requiredRole)) {
    return router.createUrlTree(['/dashboard']);
  }

  return true;
};
