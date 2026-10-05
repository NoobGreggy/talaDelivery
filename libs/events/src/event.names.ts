/**
 * Event names and queue names shared across services.
 * Keep naming stable: changing a name here is a breaking contract change.
 */

export const EventType = {
  // Order events (order-service publishes)
  OrderCreated: 'order.created',
  OrderConfirmed: 'order.confirmed',
  OrderPreparing: 'order.preparing',
  OrderReadyForPickup: 'order.ready_for_pickup',
  OrderCancelled: 'order.cancelled',
  OrderDelivered: 'order.delivered',
  OrderRiderAssigned: 'order.rider_assigned',

  // Delivery events (dispatch-service publishes)
  DeliveryCreated: 'delivery.created',
  DeliveryAssigned: 'delivery.assigned',
  RiderArrived: 'delivery.rider_arrived',
  DeliveryPickedUp: 'delivery.picked_up',
  DeliveryInTransit: 'delivery.out_for_delivery',
  DeliveryDelivered: 'delivery.delivered',
  DeliveryCancelled: 'delivery.cancelled',

  // Dispatch events
  DispatchOfferCreated: 'dispatch.offer_created',
  DispatchOfferRejected: 'dispatch.offer_rejected',
  DispatchOfferExpired: 'dispatch.offer_expired',
  DispatchRiderAssigned: 'dispatch.rider_assigned',

  // Notification job (any service can ask notification-service to emit + store)
  NotificationCreate: 'notification.create',

  /**
   * Socket fan-out request. The publisher states the audience as concrete
   * rooms; realtime-service only emits and never decides who may see what.
   */
  RealtimeEmit: 'realtime.emit',

  // Payment events (payment-service publishes)
  PaymentCreated: 'payment.created',
  PaymentPaid: 'payment.paid',
  PaymentFailed: 'payment.failed',
  PaymentRefunded: 'payment.refunded',

  // Location
  RiderLocationUpdated: 'rider.location.updated',
} as const;
export type EventType = (typeof EventType)[keyof typeof EventType];

/**
 * BullMQ queue names.
 *
 * One consumer process per queue (nestjs_api.md §20.14). A queue is owned by
 * exactly one service; when a second service needs the same event, the
 * publisher fans out to that service's own queue instead of both services
 * competing for one. `PaymentJobs` and `MerchantJobs` are the inbound queues
 * of payment-service and merchant-service — they carry events from other
 * domains and are deliberately distinct from the `PaymentEvents` /
 * `OrderEvents` queues those services would otherwise have to share.
 */
export const QueueName = {
  OrderEvents: 'order-events',
  DeliveryEvents: 'delivery-events',
  PaymentEvents: 'payment-events',
  PaymentJobs: 'payment-jobs',
  MerchantJobs: 'merchant-jobs',
  NotificationJobs: 'notification-jobs',
  OfferExpiry: 'offer-expiry',
  LocationEvents: 'location-events',
  RealtimeFeed: 'realtime-feed',
} as const;
export type QueueName = (typeof QueueName)[keyof typeof QueueName];

/**
 * Payload for {@link EventType.RealtimeEmit}.
 *
 * Publishers resolve the audience themselves and list the rooms explicitly.
 * Keeping the routing decision with the publisher means realtime-service can
 * stay a dumb pipe and cannot be tricked into broadcasting to a room the
 * publisher did not intend.
 */
export interface RealtimeEmitPayload {
  /** Socket.IO rooms, e.g. `admin:platform`, `merchant:1`, `user:42`. */
  rooms: string[];
  /** Client-side event name, e.g. `order.updated`. */
  event: string;
  data: Record<string, unknown>;
}

export const IdempotencyKeyPrefix = {
  EventConsumer: 'evt:',
  OrderCreate: 'order:create:',
  OfferAccept: 'offer:accept:',
  Payment: 'payment:',
  Webhook: 'webhook:',
} as const;

export const RedisKey = {
  RiderLocation: 'rider:loc:',
  OnlineRiders: 'riders:online',
} as const;