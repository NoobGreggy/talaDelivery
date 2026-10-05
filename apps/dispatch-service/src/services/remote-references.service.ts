import { Injectable } from '@nestjs/common';
import {
  ServiceClientFactory,
  type ServiceClient,
} from '@taladelivery/common';
import type { StoreSnapshot, UserSnapshot } from '@taladelivery/contracts';

export interface OrderReferenceItem {
  id: number;
  productId: number;
  productName: string;
  quantity: number;
  unitPrice: string;
  subtotal: string;
}

export interface OrderReference {
  id: number;
  orderNumber: string;
  status: string;
  paymentMethod: string;
  paymentStatus: string;
  total: string;
  deliveryFee: string;
  subtotal: string;
  discount: string;
  customerId: number;
  storeId: number;
  deliveryId: number | null;
  customerName: string;
  customerPhone: string;
  deliveryAddress: string;
  deliveryLatitude: string | null;
  deliveryLongitude: string | null;
  createdAt: string;
  items: OrderReferenceItem[];
}

/**
 * Synchronous remote-reference resolvers used to assemble API resources.
 * Dispatch is the single writer for riders/deliveries/offers; order, store and
 * user rows stay in their owning services.
 */
@Injectable()
export class RemoteReferencesService {
  private readonly order: ServiceClient;
  private readonly store: ServiceClient;
  private readonly user: ServiceClient;

  constructor(factory: ServiceClientFactory) {
    this.order = factory.create('ORDER_SERVICE_URL');
    this.store = factory.create('MERCHANT_SERVICE_URL');
    this.user = factory.create('IDENTITY_SERVICE_URL');
  }

  async orderById(orderId: number): Promise<OrderReference | null> {
    try {
      return await this.order.get<OrderReference>(`/internal/orders/${orderId}`);
    } catch {
      return null;
    }
  }

  async activePlatformAdmins(): Promise<UserSnapshot[]> {
    return this.user.get<UserSnapshot[]>('/internal/admin/active-users');
  }

  async storeById(storeId: number): Promise<StoreSnapshot | null> {
    try {
      return await this.store.get<StoreSnapshot>(`/internal/stores/${storeId}`);
    } catch {
      return null;
    }
  }

  async userById(userId: number): Promise<UserSnapshot | null> {
    try {
      return await this.user.get<UserSnapshot>(`/internal/users/${userId}`);
    } catch {
      return null;
    }
  }

  async usersByIds(ids: number[]): Promise<Map<number, UserSnapshot>> {
    if (ids.length === 0) {
      return new Map();
    }
    try {
      const users = await this.user.get<UserSnapshot[]>(
        `/internal/users/batch?ids=${ids.join(',')}`,
      );
      return new Map(users.map((user) => [user.id, user]));
    } catch {
      return new Map();
    }
  }
}
