<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\OrderStatus;
use App\Enums\RiderStatus;
use App\Enums\StoreStatus;
use App\Events\OrderUpdated;
use App\Jobs\MatchRider;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\Store;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class OrderService
{
    public function __construct(
        public PricingService $pricing,
        public RiderCommissionService $commissions,
        public NotificationService $notifications,
    ) {}

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(array $data, User $customer): Order
    {
        $store = Store::findOrFail($data['store_id']);

        if ($store->status !== StoreStatus::Active) {
            throw new \DomainException('This store is not accepting orders right now.');
        }

        $subtotal = 0.0;
        $lineItems = [];

        foreach ($data['items'] as $line) {
            $product = Product::where('id', $line['product_id'])
                ->where('store_id', $store->id)
                ->firstOrFail();

            if (! $product->is_available) {
                throw new \DomainException("{$product->name} is currently unavailable.");
            }

            if ($product->stock < (int) $line['quantity']) {
                throw new \DomainException("Insufficient stock for {$product->name}.");
            }

            $quantity = (int) $line['quantity'];
            $unitPrice = (float) $product->price;
            $subtotal += $unitPrice * $quantity;

            $lineItems[] = [
                'product' => $product,
                'quantity' => $quantity,
                'unit_price' => $unitPrice,
            ];
        }

        $priceBreakdown = $this->pricing->calculate(
            $store->latitude !== null ? (float) $store->latitude : null,
            $store->longitude !== null ? (float) $store->longitude : null,
            isset($data['delivery_latitude']) ? (float) $data['delivery_latitude'] : null,
            isset($data['delivery_longitude']) ? (float) $data['delivery_longitude'] : null,
            $data['city'] ?? null,
            $data['province'] ?? null,
        );

        $discount = (float) ($data['discount'] ?? 0);
        $deliveryFee = $priceBreakdown['delivery_fee'];
        $commission = $this->commissions->calculate($deliveryFee);
        $total = $subtotal + $deliveryFee - $discount;

        $order = DB::transaction(function () use ($data, $customer, $store, $lineItems, $subtotal, $deliveryFee, $discount, $total, $priceBreakdown, $commission) {
            $order = Order::query()->create([
                'order_number' => $this->generateOrderNumber(),
                'customer_id' => $customer->id,
                'store_id' => $store->id,
                'subtotal' => round($subtotal, 2),
                'delivery_fee' => $deliveryFee,
                'discount' => $discount,
                'total' => round($total, 2),
                'payment_method' => $data['payment_method'] ?? 'COD',
                'payment_status' => 'PENDING',
                'status' => OrderStatus::Pending,
                'customer_name' => $data['customer_name'] ?? $customer->name,
                'customer_phone' => $data['customer_phone'] ?? $customer->phone ?? '',
                'delivery_address' => $data['delivery_address'],
                'delivery_latitude' => $data['delivery_latitude'] ?? null,
                'delivery_longitude' => $data['delivery_longitude'] ?? null,
                'notes' => $data['notes'] ?? null,
            ]);

            foreach ($lineItems as $line) {
                OrderItem::query()->create([
                    'order_id' => $order->id,
                    'product_id' => $line['product']->id,
                    'product_name' => $line['product']->name,
                    'quantity' => $line['quantity'],
                    'unit_price' => $line['unit_price'],
                    'subtotal' => round($line['unit_price'] * $line['quantity'], 2),
                ]);

                $line['product']->decrement('stock', $line['quantity']);
            }

            $order->delivery()->create([
                'store_id' => $store->id,
                'status' => DeliveryStatus::Unassigned,
                'pickup_address' => $store->address,
                'pickup_latitude' => $store->latitude,
                'pickup_longitude' => $store->longitude,
                'delivery_address' => $data['delivery_address'],
                'delivery_latitude' => $data['delivery_latitude'] ?? null,
                'delivery_longitude' => $data['delivery_longitude'] ?? null,
                'distance_km' => $priceBreakdown['distance_km'],
                'delivery_fee' => $deliveryFee,
                'rider_commission' => $commission['amount'],
                'commission_type' => $commission['type'],
                'commission_value' => $commission['value'],
            ]);

            return $order;
        });

        $this->notifyStoreNewOrder($order);

        OrderUpdated::dispatch($order);

        return $order->load('store', 'items', 'delivery');
    }

    public function restoreStock(Order $order): void
    {
        foreach ($order->items as $item) {
            if ($item->product_id !== null) {
                $item->product?->increment('stock', $item->quantity);
            }
        }
    }

    public function generateOrderNumber(): string
    {
        return 'TLD-'.date('Ymd').'-'.strtoupper(Str::random(6));
    }

    public function notifyStoreNewOrder(Order $order): void
    {
        $storeAdmins = $order->store->storeUsers()
            ->with('user')
            ->get()
            ->pluck('user');

        foreach ($storeAdmins as $admin) {
            $this->notifications->notify(
                $admin,
                'order.received',
                'New order received',
                'New order '.$order->order_number.' is waiting for confirmation.',
                ['order_id' => $order->id],
            );
        }
    }

    public function confirm(Order $order): Order
    {
        $this->assertStatus($order, [OrderStatus::Pending], 'Only pending orders can be confirmed.');

        $order->update([
            'status' => OrderStatus::Confirmed,
            'confirmed_at' => now(),
        ]);

        $this->notifyCustomer($order, 'Order confirmed', 'Your order has been confirmed by the store.');

        OrderUpdated::dispatch($order);

        return $order->fresh();
    }

    public function preparing(Order $order): Order
    {
        $this->assertStatus($order, [OrderStatus::Confirmed], 'Only confirmed orders can be marked as preparing.');

        $order->update([
            'status' => OrderStatus::Preparing,
            'prepared_at' => now(),
        ]);

        $this->notifyCustomer($order, 'Order preparing', 'The store is preparing your order.');

        OrderUpdated::dispatch($order);

        return $order->fresh();
    }

    public function ready(Order $order): Order
    {
        $this->assertStatus(
            $order,
            [OrderStatus::Confirmed, OrderStatus::Preparing],
            'Only confirmed or preparing orders can be marked ready.',
        );

        $order->update([
            'status' => OrderStatus::ReadyForPickup,
            'ready_at' => now(),
        ]);

        $this->notifyCustomer($order, 'Order ready', 'Your order is ready and waiting for a rider.');

        if ($order->delivery) {
            MatchRider::dispatch($order->delivery);
        }

        OrderUpdated::dispatch($order);

        return $order->fresh();
    }

    public function cancel(Order $order, string $cancelledBy, ?string $reason = null): Order
    {
        if ($order->status === OrderStatus::Delivered || $order->status === OrderStatus::Cancelled) {
            throw new \DomainException('This order can no longer be cancelled.');
        }

        return DB::transaction(function () use ($order, $cancelledBy, $reason) {
            $this->restoreStock($order);

            $order->update([
                'status' => OrderStatus::Cancelled,
                'cancelled_by' => $cancelledBy,
                'cancellation_reason' => $reason,
                'cancelled_at' => now(),
            ]);

            $delivery = $order->delivery;

            if ($delivery && $delivery->status !== DeliveryStatus::Cancelled) {
                $delivery->update([
                    'status' => DeliveryStatus::Cancelled,
                    'cancelled_by' => $cancelledBy,
                    'cancellation_reason' => $reason,
                    'cancelled_at' => now(),
                ]);

                if ($delivery->rider_id !== null) {
                    $delivery->rider?->rider?->updateQuietly(['status' => RiderStatus::Online]);
                }
            }

            $this->notifyStore($order, 'Order cancelled', 'Order '.$order->order_number.' was cancelled.');
            $this->notifyCustomer($order, 'Order cancelled', 'Your order has been cancelled.');

            OrderUpdated::dispatch($order);

            return $order->fresh();
        });
    }

    private function assertStatus(Order $order, array $allowed, string $message): void
    {
        if (! in_array($order->status, $allowed, true)) {
            throw new \DomainException($message);
        }
    }

    private function notifyCustomer(Order $order, string $title, string $message): void
    {
        $this->notifications->notify(
            $order->customer_id,
            'order.status',
            $title,
            $message,
            ['order_id' => $order->id],
        );
    }

    private function notifyStore(Order $order, string $title, string $message): void
    {
        foreach ($order->store->storeUsers()->with('user')->get()->pluck('user') as $admin) {
            $this->notifications->notify(
                $admin,
                'order.status',
                $title,
                $message,
                ['order_id' => $order->id],
            );
        }
    }
}
