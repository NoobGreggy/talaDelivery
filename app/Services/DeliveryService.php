<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Enums\RiderStatus;
use App\Events\OrderUpdated;
use App\Models\Delivery;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class DeliveryService
{
    public function __construct(
        public NotificationService $notifications,
        public OrderService $orderService,
    ) {}

    public function assign(Delivery $delivery, User $rider): Delivery
    {
        if (($delivery->rider_id !== null) || $delivery->status !== DeliveryStatus::Unassigned) {
            throw new \DomainException('A rider has already been assigned to this delivery.');
        }

        $riderProfile = $rider->rider;

        if (! $riderProfile || $riderProfile->status === RiderStatus::Suspended) {
            throw new \DomainException('This user is not an active rider.');
        }

        return DB::transaction(function () use ($delivery, $rider, $riderProfile) {
            $locked = Delivery::whereKey($delivery->id)->lockForUpdate()->first();
            $locked->update([
                'rider_id' => $rider->id,
                'status' => DeliveryStatus::Assigned,
                'assigned_at' => now(),
            ]);

            $riderProfile->updateQuietly(['status' => RiderStatus::Busy]);

            $locked->order?->update([
                'status' => OrderStatus::RiderAssigned,
            ]);

            if ($locked->order) {
                OrderUpdated::dispatch($locked->order);
            }

            return $locked->fresh('order');
        });
    }

    public function arrived(Delivery $delivery, User $rider): Delivery
    {
        $this->assertAssignedRider($delivery, $rider);
        $this->assertStatus($delivery, DeliveryStatus::Assigned);

        $delivery->update([
            'status' => DeliveryStatus::Accepted,
            'accepted_at' => now(),
        ]);

        $this->notifyStore($delivery, 'Rider arrived', 'The rider has arrived at the store.');

        return $delivery->fresh('order');
    }

    public function pickup(Delivery $delivery, User $rider): Delivery
    {
        $this->assertAssignedRider($delivery, $rider);
        $this->assertStatus($delivery, DeliveryStatus::Accepted);

        $delivery->update([
            'status' => DeliveryStatus::PickedUp,
            'picked_up_at' => now(),
        ]);

        $delivery->order?->update(['status' => OrderStatus::PickedUp]);

        if ($delivery->order) {
            OrderUpdated::dispatch($delivery->order);
        }

        $this->notifyCustomer($delivery, 'Order picked up', 'Your order has been picked up by the rider.');
        $this->notifyStore($delivery, 'Order picked up', 'The order has been picked up.');

        return $delivery->fresh('order');
    }

    public function start(Delivery $delivery, User $rider): Delivery
    {
        $this->assertAssignedRider($delivery, $rider);
        $this->assertStatus($delivery, DeliveryStatus::PickedUp);

        $delivery->update([
            'status' => DeliveryStatus::InTransit,
            'started_at' => now(),
        ]);

        $delivery->order?->update(['status' => OrderStatus::OutForDelivery]);

        if ($delivery->order) {
            OrderUpdated::dispatch($delivery->order);
        }

        $this->notifyCustomer($delivery, 'Out for delivery', 'Your order is on the way to you.');

        return $delivery->fresh('order');
    }

    public function complete(Delivery $delivery, User $rider): Delivery
    {
        $this->assertAssignedRider($delivery, $rider);

        if ($delivery->status !== DeliveryStatus::InTransit && $delivery->status !== DeliveryStatus::PickedUp) {
            throw new \DomainException('Delivery can only be completed after the order has been picked up.');
        }

        return DB::transaction(function () use ($delivery) {
            $delivery->update([
                'status' => DeliveryStatus::Delivered,
                'delivered_at' => now(),
            ]);

            $delivery->order?->update([
                'status' => OrderStatus::Delivered,
                'payment_status' => PaymentStatus::Paid,
                'delivered_at' => now(),
            ]);

            $delivery->rider?->rider?->updateQuietly(['status' => RiderStatus::Online]);

            if ($delivery->order) {
                OrderUpdated::dispatch($delivery->order);
            }

            $this->notifyCustomer($delivery, 'Order delivered', 'Your order has been delivered. Enjoy!');

            return $delivery->fresh('order');
        });
    }

    public function cancel(Delivery $delivery, string $cancelledBy, ?string $reason = null, bool $cancelOrder = true): Delivery
    {
        return DB::transaction(function () use ($delivery, $cancelledBy, $reason, $cancelOrder) {
            $delivery->update([
                'status' => DeliveryStatus::Cancelled,
                'cancelled_by' => $cancelledBy,
                'cancellation_reason' => $reason,
                'cancelled_at' => now(),
            ]);

            if ($delivery->rider_id !== null) {
                $delivery->rider?->rider?->updateQuietly(['status' => RiderStatus::Online]);
            }

            if ($cancelOrder && $delivery->order) {
                $this->orderService->restoreStock($delivery->order);
                $delivery->order->update([
                    'status' => OrderStatus::Cancelled,
                    'cancelled_by' => $cancelledBy,
                    'cancellation_reason' => $reason ?? 'Delivery cancelled.',
                    'cancelled_at' => now(),
                ]);

                $this->notifyStore($delivery, 'Order cancelled', 'The delivery for order '.$delivery->order->order_number.' was cancelled.');
                $this->notifyCustomer($delivery, 'Order cancelled', 'Your order was cancelled.');

                OrderUpdated::dispatch($delivery->order);
            }

            return $delivery->fresh('order');
        });
    }

    private function assertAssignedRider(Delivery $delivery, User $rider): void
    {
        if ($delivery->rider_id === null || $delivery->rider_id !== $rider->id) {
            throw new \DomainException('Only the assigned rider can update this delivery.');
        }
    }

    private function assertStatus(Delivery $delivery, DeliveryStatus $expected): void
    {
        if ($delivery->status !== $expected) {
            throw new \DomainException("Delivery must be {$expected->value} to perform this action.");
        }
    }

    private function notifyCustomer(Delivery $delivery, string $title, string $message): void
    {
        if ($delivery->order) {
            $this->notifications->notify(
                $delivery->order->customer_id,
                'order.status',
                $title,
                $message,
                ['order_id' => $delivery->order->id, 'delivery_id' => $delivery->id],
            );
        }
    }

    private function notifyStore(Delivery $delivery, string $title, string $message): void
    {
        $storeAdmins = $delivery->store?->storeUsers()->with('user')->get()->pluck('user');

        foreach ($storeAdmins ?? [] as $admin) {
            $this->notifications->notify(
                $admin,
                'delivery.status',
                $title,
                $message,
                ['delivery_id' => $delivery->id],
            );
        }
    }
}
