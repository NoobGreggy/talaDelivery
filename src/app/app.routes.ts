import { Routes } from '@angular/router';
import { authGuard } from './core/auth/auth.guard';
import { roleGuard } from './core/auth/role.guard';

export const routes: Routes = [
  {
    path: 'login',
    title: 'Sign in | TalaDelivery',
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
        title: 'Dashboard | TalaDelivery',
        loadComponent: () => import('./features/dashboard/dashboard-page/dashboard-page').then(m => m.DashboardPageComponent)
      },
      {
        path: 'orders',
        title: 'Orders | TalaDelivery',
        loadComponent: () => import('./features/orders/order-list/order-list').then(m => m.OrderListComponent)
      },
      {
        path: 'orders/:id',
        title: 'Order Detail | TalaDelivery',
        loadComponent: () => import('./features/orders/order-detail/order-detail').then(m => m.OrderDetailComponent)
      },
      {
        path: 'deliveries',
        title: 'Deliveries | TalaDelivery',
        loadComponent: () => import('./features/deliveries/delivery-list/delivery-list').then(m => m.DeliveryListComponent)
      },
      {
        path: 'deliveries/:id',
        title: 'Delivery Detail | TalaDelivery',
        loadComponent: () => import('./features/deliveries/delivery-detail/delivery-detail').then(m => m.DeliveryDetailComponent)
      },
      {
        path: 'stores',
        title: 'Stores | TalaDelivery',
        loadComponent: () => import('./features/stores/store-list/store-list').then(m => m.StoreListComponent)
      },
      {
        path: 'stores/:id',
        title: 'Store | TalaDelivery',
        loadComponent: () => import('./features/stores/store-detail/store-detail').then(m => m.StoreDetailComponent)
      },
      {
        path: 'stores/:id/products',
        title: 'Products | TalaDelivery',
        loadComponent: () => import('./features/products/product-list/product-list').then(m => m.ProductListComponent)
      },
      {
        path: 'riders',
        title: 'Riders | TalaDelivery',
        canActivate: [roleGuard],
        data: { role: 'platform_admin' },
        loadComponent: () => import('./features/riders/rider-list/rider-list').then(m => m.RiderListComponent)
      },
      {
        path: 'riders/:id',
        title: 'Rider | TalaDelivery',
        canActivate: [roleGuard],
        data: { role: 'platform_admin' },
        loadComponent: () => import('./features/riders/rider-detail/rider-detail').then(m => m.RiderDetailComponent)
      },
      {
        path: 'customers',
        title: 'Customers | TalaDelivery',
        canActivate: [roleGuard],
        data: { role: 'platform_admin' },
        loadComponent: () => import('./features/customers/customer-list/customer-list').then(m => m.CustomerListComponent)
      },
      {
        path: 'customers/:id',
        title: 'Customer | TalaDelivery',
        canActivate: [roleGuard],
        data: { role: 'platform_admin' },
        loadComponent: () => import('./features/customers/customer-detail/customer-detail').then(m => m.CustomerDetailComponent)
      },
      {
        path: 'zones',
        title: 'Delivery Zones | TalaDelivery',
        canActivate: [roleGuard],
        data: { role: 'platform_admin' },
        loadComponent: () => import('./features/zones/zone-list/zone-list').then(m => m.ZoneListComponent)
      },
      {
        path: 'settings',
        title: 'Settings | TalaDelivery',
        canActivate: [roleGuard],
        data: { role: 'platform_admin' },
        loadComponent: () => import('./features/settings/settings-page/settings-page').then(m => m.SettingsPageComponent)
      }
    ]
  },
  { path: '**', redirectTo: 'dashboard' }
];