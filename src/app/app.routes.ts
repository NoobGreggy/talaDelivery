import { Routes } from '@angular/router';
import { authGuard } from './core/auth/auth.guard';

export const routes: Routes = [
  {
    path: 'login',
    title: 'Sign in | TalaDelivery Merchant',
    loadComponent: () => import('./features/auth/login/login').then(m => m.LoginComponent)
  },
  {
    path: '',
    canActivate: [authGuard],
    loadComponent: () => import('./layout/admin-layout/admin-layout').then(m => m.AdminLayoutComponent),
    children: [
      { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
      {
        path: 'dashboard',
        title: 'Dashboard | TalaDelivery Merchant',
        loadComponent: () => import('./features/dashboard/dashboard-page/dashboard-page').then(m => m.DashboardPageComponent)
      },
      {
        path: 'orders',
        title: 'Orders | TalaDelivery Merchant',
        loadComponent: () => import('./features/orders/order-list/order-list').then(m => m.OrderListComponent)
      },
      {
        path: 'orders/:id',
        title: 'Order | TalaDelivery Merchant',
        loadComponent: () => import('./features/orders/order-detail/order-detail').then(m => m.OrderDetailComponent)
      },
      {
        path: 'products',
        title: 'Products | TalaDelivery Merchant',
        loadComponent: () => import('./features/products/product-list/product-list').then(m => m.ProductListComponent)
      },
      {
        path: 'categories',
        title: 'Categories | TalaDelivery Merchant',
        loadComponent: () => import('./features/categories/category-list/category-list').then(m => m.CategoryListComponent)
      },
      {
        path: 'settings',
        title: 'Store Settings | TalaDelivery Merchant',
        loadComponent: () => import('./features/settings/settings-page/settings-page').then(m => m.SettingsPageComponent)
      }
    ]
  },
  { path: '**', redirectTo: 'dashboard' }
];