<?php

namespace App\Console\Commands;

use App\Services\OrderService;
use App\Services\RiderMatchingService;
use App\Models\Store;
use App\Models\User;
use Illuminate\Console\Command;

class CreateDemoOffer extends Command
{
    protected $signature = 'tala:demo-offer {--store=cabanatuan-food-corner}';

    protected $description = 'Create a demo order, advance it to ready, and match an online rider synchronously so the delivery.offered event fires.';

    public function handle(OrderService $orderService, RiderMatchingService $matching): int
    {
        $store = Store::query()->where('slug', $this->option('store'))->first();

        if (! $store) {
            $this->error("Store not found for slug '{$this->option('store')}'.");

            return self::FAILURE;
        }

        $customer = User::query()
            ->role('customer')
            ->where('status', 'ACTIVE')
            ->with('addresses')
            ->first();

        if (! $customer) {
            $this->error('No active customer found.');

            return self::FAILURE;
        }

        $address = $customer->addresses()->first();

        $products = $store->products()->where('is_available', true)->where('stock', '>', 0)->get();

        if ($products->isEmpty()) {
            $this->error('No available products for this store.');

            return self::FAILURE;
        }

        $items = $products->random(rand(1, 3))
            ->map(fn ($product) => [
                'product_id' => $product->id,
                'quantity' => rand(1, 3),
            ])
            ->values()
            ->all();

        $order = $orderService->create([
            'store_id' => $store->id,
            'items' => $items,
            'delivery_address' => $address?->address_line ?? '123 Demo Street',
            'delivery_latitude' => $address?->latitude ?? 15.4865,
            'delivery_longitude' => $address?->longitude ?? 120.9734,
            'city' => $address?->city ?? 'Cabanatuan City',
            'province' => $address?->province ?? 'Nueva Ecija',
            'payment_method' => 'COD',
        ], $customer);

        if ($order->delivery) {
            $orderService->confirm($order);
            $orderService->preparing($order);
            $orderService->ready($order);

            $this->info("Order {$order->order_number} advanced to READY_FOR_PICKUP.");

            $offer = $matching->match($order->delivery);

            if (! $offer) {
                $this->error('No online rider available — make sure a rider went online first.');

                return self::FAILURE;
            }

            $this->info(
                "Offer #{$offer->id} sent to rider #{$offer->rider_id} — delivery.offered fired on user.{$offer->rider_id}."
            );

            return self::SUCCESS;
        }

        $this->error('Delivery record was not created.');

        return self::FAILURE;
    }
}