import { Injectable, Logger } from '@nestjs/common';
import { EventType, EventWorkerManager, QueueName } from '@taladelivery/events';
import { RealtimeGateway } from '../realtime.gateway';

/** Mirrors dispatch-service `RiderService.updateLocation` payload exactly. */
interface RiderLocationPayload {
  deliveryId: number;
  orderId: number;
  riderId: number;
  latitude: string;
  longitude: string;
  accuracyM: number | null;
  headingDeg: number | null;
  speedMps: number | null;
  recordedAt: string;
}

/**
 * Fans rider location updates out over Socket.IO.
 *
 * dispatch-service publishes `rider.location.updated` to `location-events`
 * and is its only publisher; realtime-service is its only consumer, so the
 * queue has exactly one worker and no event can be claimed and discarded by a
 * process that does not want it.
 */
@Injectable()
export class LocationEventsConsumer {
  private readonly logger = new Logger(LocationEventsConsumer.name);

  constructor(
    private readonly workerManager: EventWorkerManager,
    private readonly gateway: RealtimeGateway,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.workerManager.on(
      QueueName.LocationEvents,
      async (data: unknown) => {
        const payload = data as RiderLocationPayload;
        const body = {
          deliveryId: payload.deliveryId,
          orderId: payload.orderId,
          riderId: payload.riderId,
          latitude: Number(payload.latitude),
          longitude: Number(payload.longitude),
          accuracyM: payload.accuracyM,
          headingDeg: payload.headingDeg,
          speedMps: payload.speedMps,
          timestamp: payload.recordedAt,
        };
        // The customer following this delivery, and dispatch watching the
        // rider, are separate audiences.
        this.gateway.emitToRoom(`delivery:${payload.deliveryId}`, 'rider.location', body);
        if (payload.orderId) this.gateway.emitToRoom(`order:${payload.orderId}`, 'rider.location', body);
        this.gateway.emitToRoom(`rider:${payload.riderId}`, 'rider.location', body);
        this.logger.debug(
          `Broadcast location for rider ${payload.riderId} on delivery ${payload.deliveryId}`,
        );
      },
      { eventTypes: [EventType.RiderLocationUpdated] },
    );
    this.logger.log('Location events consumer registered');
  }
}
