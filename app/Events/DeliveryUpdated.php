<?php

namespace App\Events;

use App\Models\Delivery;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class DeliveryUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public Delivery $delivery) {}

    /**
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return $this->delivery->rider_id !== null
            ? [new PrivateChannel('user.'.$this->delivery->rider_id)]
            : [];
    }

    public function broadcastAs(): string
    {
        return 'delivery.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'id' => $this->delivery->id,
            'order_id' => $this->delivery->order_id,
            'rider_id' => $this->delivery->rider_id,
            'status' => $this->delivery->status->value,
            'updated_at' => $this->delivery->updated_at?->toISOString(),
        ];
    }
}
