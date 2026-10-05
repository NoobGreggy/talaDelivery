import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { TokenService } from '@taladelivery/auth';
import { Role } from '@taladelivery/contracts';
import { ServiceClientFactory } from '@taladelivery/common';

interface AuthenticatedSocket extends Socket {
  user?: {
    sub: number;
    role: Role;
    email: string;
  };
}

@WebSocketGateway({
  cors: { origin: true, credentials: true },
  namespace: '/realtime',
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(RealtimeGateway.name);
  private readonly connectedSockets = new Map<string, AuthenticatedSocket>();

  constructor(private readonly tokens: TokenService, private readonly factory: ServiceClientFactory) {}

  async handleConnection(client: AuthenticatedSocket): Promise<void> {
    try {
      const token = client.handshake.auth?.token as string | undefined;
      if (!token) {
        client.disconnect(true);
        return;
      }

      // verifyAccess (not a raw jwt.verify) so a refresh token — which shares
      // the signing shape — cannot be replayed as a socket credential.
      const payload = await this.tokens.verifyAccess(token);
      client.user = {
        sub: payload.sub,
        role: payload.role,
        email: payload.email,
      };

      this.connectedSockets.set(client.id, client);
      this.logger.log(`Client connected: ${client.id} (user: ${client.user.sub})`);
    } catch {
      this.logger.warn(`Rejected unauthenticated socket ${client.id}`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: AuthenticatedSocket): void {
    this.connectedSockets.delete(client.id);
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('subscribe')
  async handleSubscribe(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() body: { room: string },
  ): Promise<{ success: boolean; error?: string }> {
    if (!client.user) return { success: false, error: 'Unauthorized.' };
    if (typeof body?.room !== 'string') return { success: false, error: 'Room is required.' };

    if (!this.canSubscribe(client.user, body.room)) {
      return { success: false, error: 'Forbidden.' };
    }

    if (client.user.role !== Role.PlatformAdmin &&
        (body.room.startsWith('order:') || body.room.startsWith('delivery:'))) {
      try {
        const order = await this.factory.create('ORDER_SERVICE_URL').get<{
          id: number; customerId: number; storeId: number; deliveryId: number | null;
        }>(body.room.startsWith('delivery:')
          ? `/internal/orders/by-delivery/${body.room.slice(9)}`
          : `/internal/orders/${body.room.slice(6)}`);
        if (client.user.role === Role.Customer) {
          if (order.customerId !== client.user.sub) return { success: false, error: 'Forbidden.' };
        } else if (client.user.role === Role.Rider && order.deliveryId !== null) {
          const [delivery, rider] = await Promise.all([
            this.factory.create('DISPATCH_SERVICE_URL').get<{ riderId: number | null }>(
              `/internal/deliveries/${order.deliveryId}`),
            this.factory.create('DISPATCH_SERVICE_URL').get<{ id: number }>(
              `/internal/riders/by-user/${client.user.sub}`),
          ]);
          if (delivery.riderId !== rider.id) return { success: false, error: 'Forbidden.' };
        } else if (client.user.role === Role.StoreAdmin) {
          const stores = await this.factory.create('MERCHANT_SERVICE_URL')
            .get<Array<{ id: number }>>(`/internal/stores/by-user/${client.user.sub}`);
          if (!stores.some(store => store.id === order.storeId)) return { success: false, error: 'Forbidden.' };
        } else return { success: false, error: 'Forbidden.' };
      } catch { return { success: false, error: 'Tracking authorization unavailable.' }; }
    }
    if (body.room.startsWith('rider:') && client.user.role === Role.Rider) {
      try {
        const rider = await this.factory.create('DISPATCH_SERVICE_URL').get<{ id: number }>(
          `/internal/riders/by-user/${client.user.sub}`);
        if (body.room !== `rider:${rider.id}`) return { success: false, error: 'Forbidden.' };
      } catch { return { success: false, error: 'Tracking authorization unavailable.' }; }
    }

    if (body.room.startsWith('merchant:') && client.user.role === Role.StoreAdmin) {
      try {
        const stores = await this.factory.create('MERCHANT_SERVICE_URL').get<Array<{ id: number }>>(
          `/internal/stores/by-user/${client.user.sub}`);
        if (!stores.some((store) => body.room === `merchant:${store.id}`)) return { success: false, error: 'Forbidden.' };
      } catch { return { success: false, error: 'Store membership unavailable.' }; }
    }

    await client.join(body.room);
    return { success: true };
  }

  @SubscribeMessage('unsubscribe')
  async handleUnsubscribe(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() body: { room: string },
  ): Promise<{ success: boolean }> {
    if (!body.room) return { success: false };
    await client.leave(body.room);
    return { success: true };
  }

  @SubscribeMessage('location:update')
  async handleLocationUpdate(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() body: { deliveryId: number; latitude: number; longitude: number },
  ): Promise<{ success: boolean; error?: string }> {
    // Location must pass dispatch ownership, timestamp and coordinate validation.
    // Never allow a socket to spoof an arbitrary rider/delivery position.
    return { success: false, error: 'Use authenticated POST /rider/location to update location.' };
  }

  canSubscribe(user: { sub: number; role: Role }, room: string): boolean {
    if (room.startsWith('user:')) {
      return Number(room.slice(5)) === user.sub;
    }
    if (room.startsWith('order:') || room.startsWith('delivery:')) {
      return /^(order|delivery):[1-9]\d*$/.test(room);
    }
    // Platform-wide operations feed: new rider applications, new stores.
    // Platform admins only — this is the room those events are broadcast to.
    if (room === 'admin:platform' || room.startsWith('admin:')) {
      return user.role === Role.PlatformAdmin;
    }
    if (room.startsWith('merchant:')) {
      return user.role === Role.StoreAdmin || user.role === Role.PlatformAdmin;
    }
    if (room.startsWith('rider:')) {
      return user.role === Role.Rider || user.role === Role.PlatformAdmin;
    }
    if (room.startsWith('customer:')) {
      return user.role === Role.Customer || user.role === Role.PlatformAdmin;
    }
    return false;
  }

  getStats(): { connectedSockets: number; rooms: string[] } {
    const rooms = new Set<string>();
    for (const socket of this.connectedSockets.values()) {
      for (const room of socket.rooms) {
        if (room !== socket.id) rooms.add(room);
      }
    }
    return { connectedSockets: this.connectedSockets.size, rooms: [...rooms] };
  }

  emitToRoom(room: string, event: string, data: unknown): void {
    this.server.to(room).emit(event, data);
  }
}
