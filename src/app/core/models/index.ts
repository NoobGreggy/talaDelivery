export interface User {
  id: number;
  name: string;
  email: string;
  phone?: string;
  role: 'platform_admin' | 'store_admin';
  store_id?: number;
  avatar?: string;
}

export interface Store {
  id: number;
  name: string;
  slug?: string;
  description?: string;
  phone: string;
  email?: string;
  address: string;
  latitude?: number;
  longitude?: number;
  status: 'ACTIVE' | 'INACTIVE' | 'SUSPENDED';
  opening_time?: string;
  closing_time?: string;
  orders_today: number;
  created_at: string;
}

export interface Product {
  id: number;
  store_id: number;
  name: string;
  sku: string;
  category: string;
  price: number;
  stock: number;
  image?: string;
  available: boolean;
}

export interface Order {
  id: number;
  order_number: string;
  customer?: Customer | null;
  store?: Store | null;
  items: OrderItem[];
  subtotal: number;
  delivery_fee: number;
  total: number;
  payment_method: string;
  status: OrderStatus;
  created_at: string;
}

export type OrderStatus = 'PENDING' | 'CONFIRMED' | 'PREPARING' | 'READY_FOR_PICKUP' | 'RIDER_ASSIGNED' | 'PICKED_UP' | 'OUT_FOR_DELIVERY' | 'DELIVERED' | 'CANCELLED';

export interface OrderItem {
  id: number;
  product?: Product | null;
  quantity: number;
  price: number;
}

export interface Delivery {
  id: number;
  delivery_number: string;
  order?: Order | null;
  store?: Store | null;
  customer?: Customer | null;
  rider?: Rider | null;
  status: DeliveryStatus;
  distance: number;
  delivery_fee: number;
  pickup_address: string;
  delivery_address: string;
  timeline: DeliveryEvent[];
  created_at: string;
}

export type DeliveryStatus = 'FINDING_RIDER' | 'RIDER_ASSIGNED' | 'PICKED_UP' | 'OUT_FOR_DELIVERY' | 'DELIVERED' | 'FAILED' | 'CANCELLED';

export interface DeliveryEvent {
  label: string;
  time?: string;
  completed: boolean;
  active: boolean;
}

export interface Rider {
  id: number;
  user?: User | null;
  name: string;
  phone: string;
  vehicle_type?: string;
  vehicle_plate?: string;
  vehicle: string;
  plate_number: string;
  license_number?: string;
  is_online?: boolean;
  status: RiderStatus;
  current_delivery?: Delivery | null;
  completed_deliveries: number;
  total_earnings: number;
  recent_deliveries?: Delivery[];
  created_at: string;
}

export type RiderStatus = 'PENDING' | 'REJECTED' | 'ONLINE' | 'OFFLINE' | 'BUSY' | 'SUSPENDED';

export interface Customer {
  id: number;
  name: string;
  phone: string;
  orders_count: number;
  total_spent: number;
  status: 'ACTIVE' | 'INACTIVE';
  addresses: Address[];
  created_at: string;
}

export interface Address {
  id: number;
  label: string;
  address: string;
  latitude: number;
  longitude: number;
}

export interface DeliveryZone {
  id: number;
  name: string;
  city?: string;
  province?: string;
  base_fee: number;
  included_km: number;
  extra_fee_per_km: number;
  status: 'ACTIVE' | 'INACTIVE' | 'SUSPENDED';
}

export interface DashboardData {
  orders_today: number;
  active_deliveries: number;
  online_riders: number;
  active_stores: number;
  delivered_today: number;
  cancelled_today: number;
  revenue_today: number;
  delivery_fees_today: number;
  alerts: OperationalAlert[];
  recent_deliveries: Delivery[];
}

export interface OperationalAlert {
  id: number;
  type: 'no_rider' | 'delivery_failed' | 'order_cancelled' | 'rider_rejected' | 'new_order';
  message: string;
  action_label: string;
  action_route: string;
}

export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  links?: Record<string, string | null>;
  meta: {
    current_page: number;
    from: number | null;
    last_page: number;
    path: string;
    per_page: number;
    to: number | null;
    total: number;
  };
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  user: User;
  token: string;
}

export interface AppNotification {
  id: number;
  type: string;
  title: string;
  message: string;
  data: Record<string, unknown>;
  is_read: boolean;
  read_at: string | null;
  created_at: string;
}
