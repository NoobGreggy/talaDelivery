import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { DomainError, fromMinor } from '@taladelivery/common';
import { buildEnvelope, EventPublisher, EventType, QueueName } from '@taladelivery/events';
import { Rider } from '../entities/rider.entity';
import { Delivery } from '../entities/delivery.entity';
import { RiderCoinTransaction } from '../entities/rider-coin-transaction.entity';
import { RemoteReferencesService } from './remote-references.service';
import { TopUpRiderCoinsDto } from '../dto/rider-coins.dto';

@Injectable()
export class RiderCoinsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RiderCoinsService.name);
  private timer?: ReturnType<typeof setInterval>;
  private flushing = false;

  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(RiderCoinTransaction)
    private readonly transactions: Repository<RiderCoinTransaction>,
    private readonly refs: RemoteReferencesService,
    private readonly events: EventPublisher,
  ) {}

  onModuleInit(): void {
    this.timer = setInterval(() => {
      void this.flushAlerts();
    }, 10000);
    this.timer.unref();
    void this.flushAlerts();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async history(riderId: number, page: number, perPage: number) {
    const [items, total] = await this.transactions.findAndCount({
      where: { riderId },
      order: { id: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return {
      items: items.map((row) => ({
        id: row.id,
        type: row.type,
        amount: row.amount,
        balance_after: row.balanceAfter,
        delivery_id: row.deliveryId,
        delivery_zone_id: row.deliveryZoneId,
        deduction_percent: row.deductionPercent,
        actor_id: row.actorId,
        note: row.note,
        created_at: row.createdAt.toISOString(),
      })),
      total,
    };
  }

  async topUp(riderId: number, dto: TopUpRiderCoinsDto, actorId: number): Promise<Rider> {
    const amountMinor = this.decimalMinor(dto.amount);
    if (amountMinor <= 0) throw new DomainError('Top-up amount must be greater than zero.');
    return this.dataSource.transaction(async (manager) => {
      const rider = await this.lockRider(manager, riderId);
      const repository = manager.getRepository(RiderCoinTransaction);
      const existing = await repository.findOneBy({ requestId: dto.request_id });
      if (existing) {
        if (
          existing.riderId !== riderId ||
          existing.amount !== fromMinor(amountMinor) ||
          existing.actorId !== actorId
        ) {
          throw new DomainError('This top-up request has already been used.');
        }
        return rider;
      }
      const balanceMinor = this.decimalMinor(rider.talaCoinsBalance ?? '0') + amountMinor;
      this.assertBalanceRange(balanceMinor);
      rider.talaCoinsBalance = fromMinor(balanceMinor);
      await manager
        .getRepository(Rider)
        .update({ id: rider.id }, { talaCoinsBalance: rider.talaCoinsBalance });
      await repository.save(
        repository.create({
          riderId,
          requestId: dto.request_id,
          deliveryId: null,
          type: 'TOP_UP',
          amount: fromMinor(amountMinor),
          balanceAfter: rider.talaCoinsBalance,
          actorId,
          note: dto.note?.trim() || null,
          adminAlertPending: false,
        }),
      );
      return rider;
    });
  }

  // Called inside the delivery completion transaction after the delivery row is locked.
  async deduct(manager: EntityManager, delivery: Delivery): Promise<void> {
    const percentMinor = this.decimalMinor(delivery.talaCoinsPercent ?? '0');
    const feeMinor = this.decimalMinor(delivery.deliveryFee ?? '0');
    if (percentMinor < 0 || percentMinor > 10000 || feeMinor < 0) {
      throw new DomainError('Invalid delivery deduction amount or percentage.');
    }
    const deductionMinor = Number((BigInt(feeMinor) * BigInt(percentMinor) + 5000n) / 10000n);
    if (deductionMinor <= 0 || delivery.riderId == null) return;
    const rider = await this.lockRider(manager, delivery.riderId);
    const beforeMinor = this.decimalMinor(rider.talaCoinsBalance ?? '0');
    const balanceMinor = beforeMinor - deductionMinor;
    this.assertBalanceRange(balanceMinor);
    const repository = manager.getRepository(RiderCoinTransaction);
    await manager
      .getRepository(Rider)
      .update({ id: rider.id }, { talaCoinsBalance: fromMinor(balanceMinor) });
    await repository.save(
      repository.create({
        riderId: rider.id,
        deliveryId: delivery.id,
        requestId: null,
        type: 'DELIVERY_DEDUCTION',
        amount: fromMinor(-deductionMinor),
        balanceAfter: fromMinor(balanceMinor),
        deductionPercent: delivery.talaCoinsPercent,
        deliveryZoneId: delivery.deliveryZoneId,
        actorId: null,
        note: null,
        adminAlertPending: beforeMinor >= 0 && balanceMinor < 0,
      }),
    );
  }

  private async lockRider(manager: EntityManager, riderId: number): Promise<Rider> {
    const rider = await manager
      .getRepository(Rider)
      .createQueryBuilder('rider')
      .setLock('pessimistic_write')
      .where('rider.id = :id', { id: riderId })
      .getOne();
    if (!rider) throw new DomainError('Rider not found.');
    return rider;
  }

  private decimalMinor(value: string): number {
    const match = /^(-?)(\d+)(?:\.(\d{1,2}))?$/.exec(value.trim());
    if (!match) throw new DomainError('Invalid Tala Coins amount.');
    const absolute = BigInt(match[2]) * 100n + BigInt((match[3] ?? '').padEnd(2, '0'));
    const minor = Number(match[1] ? -absolute : absolute);
    this.assertBalanceRange(minor);
    return minor;
  }

  private assertBalanceRange(minor: number): void {
    if (!Number.isSafeInteger(minor) || Math.abs(minor) > 999999999999) {
      throw new DomainError('Tala Coins balance exceeds the supported range.');
    }
  }

  async flushAlerts(): Promise<void> {
    if (this.flushing) return;
    this.flushing = true;
    try {
      const pending = await this.transactions.find({
        where: { adminAlertPending: true },
        order: { id: 'ASC' },
        take: 50,
      });
      if (pending.length === 0) return;
      const admins = await this.refs.activePlatformAdmins();
      if (admins.length === 0) return;
      for (const entry of pending) {
        const rider = await this.dataSource
          .getRepository(Rider)
          .findOneByOrFail({ id: entry.riderId });
        const user = await this.refs.userById(rider.userId);
        if (!user) throw new Error('Rider contact details are temporarily unavailable.');
        const body = `${user.name}'s Tala Coins balance became ${entry.balanceAfter} after delivery #${entry.deliveryId}. Call ${user.phone || 'the rider'} to arrange a top-up.`;
        for (const admin of admins) {
          const envelope = buildEnvelope(EventType.NotificationCreate, {
            userId: admin.id,
            sourceKey: `rider-coins:${entry.id}:${admin.id}`,
            type: 'admin.rider_coins_negative',
            title: 'Rider Tala Coins balance is negative',
            body,
            data: {
              riderId: rider.id,
              name: user.name,
              phone: user.phone,
              balance: entry.balanceAfter,
              deliveryId: entry.deliveryId,
            },
          });
          const enqueued = await this.events.addJob(QueueName.NotificationJobs, 'event', envelope, {
            jobId: envelope.eventId,
          });
          if (!enqueued) throw new Error('Notification queue is unavailable.');
        }
        await this.transactions.update({ id: entry.id }, { adminAlertPending: false });
      }
    } catch (error) {
      this.logger.warn(`Tala Coins alerts will retry: ${(error as Error).message}`);
    } finally {
      this.flushing = false;
    }
  }
}
