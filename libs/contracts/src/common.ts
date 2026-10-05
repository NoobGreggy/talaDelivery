import type {
  DeliveryStatus,
  OrderStatus,
  PaymentMethod,
  PaymentStatus,
  RiderStatus,
  Role,
  StoreStatus,
  UserStatus,
} from './enums';

/**
 * Stable machine-readable error codes (nestjs_api.md §20.20).
 * Transport layers translate these to HTTP/WebSocket/queue responses.
 */
export const ErrorCode = {
  OrderNotFound: 'ORDER_NOT_FOUND',
  OrderInvalidState: 'ORDER_INVALID_STATE',
  RiderNotAvailable: 'RIDER_NOT_AVAILABLE',
  DeliveryAlreadyAssigned: 'DELIVERY_ALREADY_ASSIGNED',
  PaymentAlreadyProcessed: 'PAYMENT_ALREADY_PROCESSED',
  MerchantClosed: 'MERCHANT_CLOSED',
  StoreNotFound: 'STORE_NOT_FOUND',
  ProductNotFound: 'PRODUCT_NOT_FOUND',
  ProductUnavailable: 'PRODUCT_UNAVAILABLE',
  InsufficientStock: 'INSUFFICIENT_STOCK',
  DeliveryNotAvailable: 'DELIVERY_NOT_AVAILABLE',
  OfferExpired: 'OFFER_EXPIRED',
  OfferNotAvailable: 'OFFER_NOT_AVAILABLE',
  OfferNotYours: 'OFFER_NOT_YOURS',
  DeliveryNotAssignable: 'DELIVERY_NOT_ASSIGNABLE',
  RiderBusy: 'RIDER_BUSY',
  DuplicateEmail: 'DUPLICATE_EMAIL',
  InvalidCredentials: 'INVALID_CREDENTIALS',
  AccountNotActive: 'ACCOUNT_NOT_ACTIVE',
  Unauthorized: 'UNAUTHORIZED',
  Forbidden: 'FORBIDDEN',
  NotFound: 'NOT_FOUND',
  ValidationFailed: 'VALIDATION_FAILED',
  RateLimited: 'RATE_LIMITED',
  Conflict: 'CONFLICT',
  InternalError: 'INTERNAL_ERROR',
  RoadDistanceUnavailable: 'ROAD_DISTANCE_UNAVAILABLE',
  ZoneOverlap: 'ZONE_OVERLAP',
  ZoneDuplicateCity: 'ZONE_DUPLICATE_CITY',
} as const;
export type ErrorCode = (typeof ErrorCode)[keyof typeof ErrorCode];

/** Standard success envelope (Laravel ApiResponse compatibility). */
export interface SuccessEnvelope<T = unknown> {
  success: true;
  message: string;
  data: T;
}

/** Standard error envelope (Laravel ApiResponse compatibility). */
export interface ErrorEnvelope {
  success: false;
  message: string;
  errors: Record<string, unknown> | null;
  code?: ErrorCode | string;
  requestId?: string;
}

/** Laravel-compatible paginated envelope: { data: { data, links, meta } }. */
export interface PaginatedEnvelope<T> {
  success: true;
  message: string;
  data: {
    data: T[];
    links: {
      first: string | null;
      last: string | null;
      prev: string | null;
      next: string | null;
    };
    meta: {
      current_page: number;
      from: number | null;
      last_page: number;
      path: string;
      per_page: number;
      to: number | null;
      total: number;
    };
  };
}

// ---------------------------------------------------------------------------
// Cross-service snapshot contracts (orders never join other databases).
// ---------------------------------------------------------------------------

export interface StoreSnapshot {
  deliveryZoneIds?: number[];
  categories?: Array<{ id: number; name: string; icon?: string; is_active: boolean }>;
  id: number;
  name: string;
  slug: string;
  status: StoreStatus;
  latitude: string | null;
  longitude: string | null;
  address: string | null;
  phone: string | null;
  openingHours: Record<string, { open: string; close: string; isClosed: boolean }> | null;
}

export interface ProductSnapshot {
  id: number;
  storeId: number;
  categoryId: number | null;
  name: string;
  price: string; // decimal string, e.g. "99.00"
  unitPriceMinor: number; // price in centavos (integer money)
  stock: number;
  isAvailable: boolean;
}

export interface UserSnapshot {
  id: number;
  name: string;
  email: string;
  phone: string | null;
  role: Role;
  status: UserStatus;
}

export interface RiderProfileSnapshot {
  id: number;
  userId: number;
  vehicleType: string;
  vehiclePlate: string | null;
  isOnline: boolean;
  status: RiderStatus;
  currentLatitude: string | null;
  currentLongitude: string | null;
}

export interface DeliverySnapshot {
  id: number;
  orderId: number;
  storeId: number;
  riderId: number | null;
  status: DeliveryStatus;
  distanceKm: string | null;
  deliveryFee: string | null;
  riderCommission: string | null;
  assignedAt: string | null;
  deliveredAt: string | null;
}

export interface OrderStatusProjection {
  orderId: number;
  orderNumber: string;
  status: OrderStatus;
  paymentMethod: PaymentMethod;
  paymentStatus: PaymentStatus;
  total: string;
  deliveryFee: string;
  subtotal: string;
  discount: string;
  customerId: number;
  storeId: number;
  deliveryId: number | null;
  // Snapshot fields
  customerName: string;
  customerPhone: string;
  deliveryAddress: string;
  deliveryLatitude: string | null;
  deliveryLongitude: string | null;
  createdAt: string;
}
