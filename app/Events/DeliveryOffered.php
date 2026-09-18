<?php

namespace App\Events;

use App\Models\DeliveryOffer;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class DeliveryOffered implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public DeliveryOffer $offer,
    ) {}

    /**
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.'.$this->offer->rider_id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'delivery.offered';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'offer_id' => $this->offer->id,
            'delivery_id' => $this->offer->delivery_id,
            'offered_at' => $this->offer->offered_at?->toISOString(),
            'expires_at' => $this->offer->expires_at?->toISOString(),
            'pickup_address' => $this->offer->delivery?->pickup_address,
            'delivery_address' => $this->offer->delivery?->delivery_address,
            'distance_km' => $this->offer->delivery?->distance_km,
            'delivery_fee' => $this->offer->delivery?->delivery_fee,
        ];
    }
}
