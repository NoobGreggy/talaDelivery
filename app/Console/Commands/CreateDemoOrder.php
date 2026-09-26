<?php

namespace App\Console\Commands;

use App\Models\Store;
use App\Models\User;
use App\Services\OrderService;
use Illuminate\Console\Command;

class CreateDemoOrder extends Command
{
    protected $signature = 'tala:demo-order {--store=cauayan-food-corner} {--count=1}';

    protected $description = 'Create a demo order through the order service to trigger the WebSocket broadcast.';

    public function handle(OrderService $orderService): int
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

        $count = max(1, (int) $this->option('count'));

        for ($i = 0; $i < $count; $i++) {
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
                'delivery_latitude' => $address?->latitude ?? 16.9472,
                'delivery_longitude' => $address?->longitude ?? 121.7663,
                'city' => $address?->city ?? 'Cauayan City',
                'province' => $address?->province ?? 'Isabela',
                'payment_method' => 'COD',
            ], $customer);

            $this->info("Created {$order->order_number} — broadcast to store.{$store->id} (status: {$order->status->value}).");
        }

        return self::SUCCESS;
    }
}
