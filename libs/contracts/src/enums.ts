/**
 * Domain enums shared across all TalaDelivery services.
 *
 * These mirror the Laravel reference app exactly (tala-api/app/Enums).
 * String values are the persisted column values.
 */

export const Role = {
  PlatformAdmin: 'platform_admin',
  StoreAdmin: 'store_admin',
  Rider: 'rider',
  Customer: 'customer',
} as const;
export type Role = (typeof Role)[keyof typeof Role];

export const UserStatus = {
  Active: 'ACTIVE',
  Inactive: 'INACTIVE',
  Suspended: 'SUSPENDED',
} as const;
export type UserStatus = (typeof UserStatus)[keyof typeof UserStatus];

export const OrderStatus = {
  Pending: 'PENDING',
  Confirmed: 'CONFIRMED',
  Preparing: 'PREPARING',
  ReadyForPickup: 'READY_FOR_PICKUP',
  RiderAssigned: 'RIDER_ASSIGNED',
  PickedUp: 'PICKED_UP',
  OutForDelivery: 'OUT_FOR_DELIVERY',
  Delivered: 'DELIVERED',
  Cancelled: 'CANCELLED',
} as const;
export type OrderStatus = (typeof OrderStatus)[keyof typeof OrderStatus];

export const OrderStatusLabel: Record<OrderStatus, string> = {
  [OrderStatus.Pending]: 'Pending',
  [OrderStatus.Confirmed]: 'Confirmed',
  [OrderStatus.Preparing]: 'Preparing',
  [OrderStatus.ReadyForPickup]: 'Ready for pickup',
  [OrderStatus.RiderAssigned]: 'Rider assigned',
  [OrderStatus.PickedUp]: 'Picked up',
  [OrderStatus.OutForDelivery]: 'Out for delivery',
  [OrderStatus.Delivered]: 'Delivered',
  [OrderStatus.Cancelled]: 'Cancelled',
};

export const DeliveryStatus = {
  Unassigned: 'UNASSIGNED',
  Assigned: 'ASSIGNED',
  Accepted: 'ACCEPTED',
  PickedUp: 'PICKED_UP',
  InTransit: 'IN_TRANSIT',
  Delivered: 'DELIVERED',
  Failed: 'FAILED',
  Cancelled: 'CANCELLED',
} as const;
export type DeliveryStatus = (typeof DeliveryStatus)[keyof typeof DeliveryStatus];

export const DeliveryOfferStatus = {
  Pending: 'PENDING',
  Accepted: 'ACCEPTED',
  Rejected: 'REJECTED',
  Expired: 'EXPIRED',
} as const;
export type DeliveryOfferStatus = (typeof DeliveryOfferStatus)[keyof typeof DeliveryOfferStatus];

export const RiderStatus = {
  Pending: 'PENDING',
  Rejected: 'REJECTED',
  Offline: 'OFFLINE',
  Online: 'ONLINE',
  Busy: 'BUSY',
  Suspended: 'SUSPENDED',
} as const;
export type RiderStatus = (typeof RiderStatus)[keyof typeof RiderStatus];

export const StoreStatus = {
  Active: 'ACTIVE',
  Inactive: 'INACTIVE',
  Suspended: 'SUSPENDED',
} as const;
export type StoreStatus = (typeof StoreStatus)[keyof typeof StoreStatus];

export const PaymentMethod = {
  Cod: 'COD',
  Gcash: 'GCASH',
  Maya: 'MAYA',
  Card: 'CARD',
} as const;
export type PaymentMethod = (typeof PaymentMethod)[keyof typeof PaymentMethod];

export const PaymentStatus = {
  Pending: 'PENDING',
  Paid: 'PAID',
  Failed: 'FAILED',
  Refunded: 'REFUNDED',
} as const;
export type PaymentStatus = (typeof PaymentStatus)[keyof typeof PaymentStatus];

export const VehicleType = {
  Motorcycle: 'MOTORCYCLE',
  Bicycle: 'BICYCLE',
  Car: 'CAR',
} as const;
export type VehicleType = (typeof VehicleType)[keyof typeof VehicleType];

export const DeliveryZoneStatus = {
  Draft: 'DRAFT',
  Active: 'ACTIVE',
  Suspended: 'SUSPENDED',
  Archived: 'ARCHIVED',
} as const;
export type DeliveryZoneStatus = (typeof DeliveryZoneStatus)[keyof typeof DeliveryZoneStatus];

export const CommissionType = {
  Fixed: 'FIXED',
  Percentage: 'PERCENTAGE',
} as const;
export type CommissionType = (typeof CommissionType)[keyof typeof CommissionType];

export const DistanceMethod = {
  StraightLine: 'STRAIGHT_LINE',
  RoadRoute: 'ROAD_ROUTE',
} as const;
export type DistanceMethod = (typeof DistanceMethod)[keyof typeof DistanceMethod];

export const EarningsWeekType = {
  RollingSevenDays: 'ROLLING_SEVEN_DAYS',
  CalendarWeek: 'CALENDAR_WEEK',
} as const;
export type EarningsWeekType = (typeof EarningsWeekType)[keyof typeof EarningsWeekType];

export const ALL_TRACKABLE_DELIVERY_STATUSES: readonly DeliveryStatus[] = [
  DeliveryStatus.Assigned,
  DeliveryStatus.Accepted,
  DeliveryStatus.PickedUp,
  DeliveryStatus.InTransit,
];

/**
 * Finite state machine for order transitions matching Laravel OrderService.
 */
export const ORDER_TRANSITIONS: Record<OrderStatus, readonly OrderStatus[]> = {
  [OrderStatus.Pending]: [OrderStatus.Confirmed, OrderStatus.Cancelled],
  [OrderStatus.Confirmed]: [OrderStatus.Preparing, OrderStatus.ReadyForPickup, OrderStatus.Cancelled],
  [OrderStatus.Preparing]: [OrderStatus.ReadyForPickup, OrderStatus.Cancelled],
  [OrderStatus.ReadyForPickup]: [OrderStatus.RiderAssigned, OrderStatus.Cancelled],
  [OrderStatus.RiderAssigned]: [OrderStatus.Cancelled],
  [OrderStatus.PickedUp]: [OrderStatus.OutForDelivery, OrderStatus.Cancelled],
  [OrderStatus.OutForDelivery]: [OrderStatus.Delivered, OrderStatus.Cancelled],
  [OrderStatus.Delivered]: [],
  [OrderStatus.Cancelled]: [],
};