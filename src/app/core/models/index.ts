export interface User {
  id: number;
  name: string;
  email: string;
  phone?: string;
  role: 'platform_admin' | 'store_admin';
  store_id?: number;
  avatar?: string;
}

/**
 * Platform-admin account as returned by `GET /admin/users`. Mirrors the
 * identity-service `UserResource`: `rider`/`stores` stay empty and
 * `orders_count`/`total_spent` are 0 because those facts live in dispatch-
 * and order-service.
 */
export type AdminUserStatus = 'ACTIVE' | 'INACTIVE' | 'SUSPENDED';

export interface AdminUser {
  id: number;
  name: string;
  email: string;
  phone: string | null;
  role: 'platform_admin';
  status: AdminUserStatus;
  roles: string[];
  permissions: string[];
  created_at: string | null;
  rider: unknown | null;
  stores: unknown[];
  orders_count: number;
  total_spent: number;
}

/**
 * Write model for `POST /admin/users`. There is deliberately no `role` field:
 * the endpoint only ever grants `platform_admin`, so the UI cannot offer a role
 * choice it would silently ignore.
 */
export interface CreateAdminUserRequest {
  name: string;
  email: string;
  phone?: string | null;
  password: string;
  status?: AdminUserStatus;
}

export interface Store {
  deliveryZoneIds?: number[];
  categories?: Array<{ id: number; name: string; is_active: boolean }>;
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
  payment_status?: string;
  status: OrderStatus;
  created_at: string;
}

export type OrderStatus =
  | 'PENDING'
  | 'CONFIRMED'
  | 'PREPARING'
  | 'READY_FOR_PICKUP'
  | 'RIDER_ASSIGNED'
  | 'PICKED_UP'
  | 'OUT_FOR_DELIVERY'
  | 'DELIVERED'
  | 'CANCELLED';

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
  distance_km: number;
  delivery_fee: number;
  rider_commission: number;
  commission_type?: 'PERCENTAGE' | 'FIXED' | null;
  commission_value?: number | null;
  pickup_address: string;
  pickup_latitude?: number | null;
  pickup_longitude?: number | null;
  delivery_address: string;
  delivery_latitude?: number | null;
  delivery_longitude?: number | null;
  rider_location?: RiderLocation | null;
  timeline: DeliveryEvent[];
  created_at: string;
}

export interface RiderLocation {
  latitude: number;
  longitude: number;
  accuracy_m?: number | null;
  heading_deg?: number | null;
  speed_mps?: number | null;
  recorded_at?: string | null;
}

export interface RiderLocationEvent extends RiderLocation {
  delivery_id: number;
  rider_id: number;
  sequence: number;
}

export type DeliveryStatus =
  | 'FINDING_RIDER'
  | 'RIDER_ASSIGNED'
  | 'ASSIGNED'
  | 'ACCEPTED'
  | 'PICKED_UP'
  | 'OUT_FOR_DELIVERY'
  | 'IN_TRANSIT'
  | 'DELIVERED'
  | 'FAILED'
  | 'CANCELLED';

export interface DeliveryEvent {
  label: string;
  time?: string;
  completed: boolean;
  active: boolean;
}

export interface Rider {
  tala_coins_balance?: number;
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

export interface StoreCategory {
  icon: string;
  id: number;
  name: string;
  description: string | null;
  is_active: boolean;
  store_count: number;
  created_at: string;
  updated_at: string;
}

export interface RiderCoinTransaction {
  id: number;
  type: 'TOP_UP' | 'DELIVERY_DEDUCTION';
  amount: string;
  balance_after: string;
  delivery_id: number | null;
  delivery_zone_id: number | null;
  deduction_percent: string | null;
  actor_id: number | null;
  note: string | null;
  created_at: string;
}

export interface Address {
  id: number;
  label: string;
  address: string;
  latitude: number;
  longitude: number;
}

/**
 * Read model. Decimal columns arrive from the API as strings (`"base_fee":"49.00"`,
 * mirroring the Laravel decimal casts) and are coerced to numbers by
 * `ZoneService` so templates, sorting and currency pipes get real numbers.
 */
export interface DeliveryZone {
  tala_coins_percent?: number;
  id: number;
  name: string;
  city: string | null;
  province: string;
  boundary_geojson?: GeoJsonBoundary | null;
  base_fee: number;
  included_km: number;
  maximum_delivery_km?: number | null;
  extra_fee_per_km: number;
  maximum_delivery_fee?: number | null;
  distance_rounding_km: number;
  effective_from?: string | null;
  status: DeliveryZoneStatus;
  updated_by?: { id: number; name: string } | null;
  revision_count?: number;
  revisions?: DeliveryZoneRevision[];
  created_at?: string;
  updated_at?: string;
}

export type DeliveryZoneStatus = 'DRAFT' | 'ACTIVE' | 'SUSPENDED' | 'ARCHIVED';

/**
 * Write model for create/update. Every decimal field is a STRING because the
 * DTOs validate with `@IsString() @Matches(/^(0|[1-9]\d*)(\.\d+)?$/)`; sending
 * JSON numbers is rejected with 422 "base_fee must be a string".
 */
export interface DeliveryZoneWrite {
  tala_coins_percent?: string;
  name?: string;
  city?: string | null;
  province?: string;
  boundary_geojson?: GeoJsonBoundary | null;
  base_fee?: string;
  included_km?: string;
  maximum_delivery_km?: string | null;
  extra_fee_per_km?: string;
  maximum_delivery_fee?: string | null;
  distance_rounding_km?: string;
  effective_from?: string | null;
  status?: DeliveryZoneStatus;
}

export interface GeoJsonPolygon {
  type: 'Polygon';
  coordinates: number[][][];
}

export interface GeoJsonMultiPolygon {
  type: 'MultiPolygon';
  coordinates: number[][][][];
}

export type GeoJsonBoundary = GeoJsonPolygon | GeoJsonMultiPolygon;

export interface PlaceBoundaryResult {
  place_id: string;
  name: string;
  display_name: string;
  type: string;
  city?: string | null;
  province?: string | null;
  geometry: GeoJsonBoundary;
  bounding_box: number[];
}

export interface DeliveryZoneRevision {
  id: number;
  action: 'CREATED' | 'UPDATED' | 'ARCHIVED';
  before?: Record<string, unknown> | null;
  after?: Record<string, unknown> | null;
  user?: { id: number; name: string } | null;
  created_at: string;
}

export interface ZonePricingPreview {
  covered: boolean;
  reason?: string;
  delivery_fee?: number;
  distance_km?: number;
  billable_distance_km?: number;
  distance_method?: 'STRAIGHT_LINE' | 'ROAD_ROUTE';
  rider_commission?: number;
}

export interface PlatformSettings {
  rider_commission_type: 'PERCENTAGE' | 'FIXED';
  rider_commission_value: number;
  earnings_week_type: 'ROLLING_SEVEN_DAYS' | 'CALENDAR_WEEK';
  week_starts_on: number;
  settlement_timezone: string;
  settlement_day_starts_at: string;
  distance_method: 'STRAIGHT_LINE' | 'ROAD_ROUTE';
  updated_at?: string;
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
  /** Body text, as returned by the notification service. */
  body: string;
  data: Record<string, unknown>;
  is_read: boolean;
  read_at: string | null;
  sent_at?: string | null;
  created_at: string;
}

export type RealtimeStatus = 'disconnected' | 'connecting' | 'connected' | 'error';

/** `realtime.emit` payload from order-service (`order.updated`). */
export interface OrderUpdatedRealtimeEvent {
  orderId: number;
  orderNumber: string;
  storeId: number;
  customerId: number;
  deliveryId: number | null;
  status: OrderStatus;
  paymentStatus: string;
  total: string;
  eventType: string;
  updatedAt: string;
}

/** `realtime.emit` payload from identity-service (`rider.application`). */
export interface RiderApplicationRealtimeEvent {
  userId: number;
  riderId: number;
  name: string;
  email: string;
  vehicleType: string;
  appliedAt: string;
}

/** `rider.location` broadcast by the gateway from dispatch's location events. */
export interface RiderLocationRealtimeEvent {
  deliveryId: number;
  riderId: number;
  latitude: number;
  longitude: number;
  accuracyM: number | null;
  headingDeg: number | null;
  speedMps: number | null;
  timestamp: string;
}
