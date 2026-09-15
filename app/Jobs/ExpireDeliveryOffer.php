<?php

namespace App\Jobs;

use App\Enums\DeliveryOfferStatus;
use App\Models\DeliveryOffer;
use App\Services\RiderMatchingService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class ExpireDeliveryOffer implements ShouldQueue
{
    use Queueable;

    public function __construct(public DeliveryOffer $offer) {}

    public function handle(RiderMatchingService $matchingService): void
    {
        if ($this->offer->status !== DeliveryOfferStatus::Pending) {
            return;
        }

        $this->offer->update([
            'status' => DeliveryOfferStatus::Expired,
            'responded_at' => now(),
        ]);

        $delivery = $this->offer->delivery;

        if ($delivery->rider_id === null) {
            $matchingService->match($delivery);
        }
    }
}
