<?php

namespace App\Events;

use App\Models\Delivery;
use App\Models\Rider;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class RiderLocationUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Delivery $delivery,
        public Rider $rider,
        public ?float $accuracy = null,
        public ?float $heading = null,
        public ?float $speed = null,
    ) {}

    /**
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [new PrivateChannel('delivery.'.$this->delivery->id)];
    }

    public function broadcastAs(): string
    {
        return 'rider.location.updated';
    }

    /**
     * @return array<string, int|float|string|null>
     */
    public function broadcastWith(): array
    {
        $recordedAt = $this->rider->current_location_updated_at ?? now();

        return [
            'delivery_id' => $this->delivery->id,
            'rider_id' => $this->delivery->rider_id,
            'latitude' => (float) $this->rider->current_latitude,
            'longitude' => (float) $this->rider->current_longitude,
            'accuracy_m' => $this->accuracy,
            'heading_deg' => $this->heading,
            'speed_mps' => $this->speed,
            'recorded_at' => $recordedAt->toISOString(),
            'sequence' => $recordedAt->getTimestampMs(),
        ];
    }
}
