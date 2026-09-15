<?php

namespace App\Jobs;

use App\Models\Delivery;
use App\Services\RiderMatchingService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;

class MatchRider implements ShouldQueue
{
    use Queueable;

    public function __construct(public Delivery $delivery) {}

    public function handle(RiderMatchingService $matchingService): void
    {
        try {
            $matchingService->match($this->delivery);
        } catch (\Throwable $e) {
            Log::error('Rider matching failed for delivery '.$this->delivery->id.': '.$e->getMessage());
        }
    }
}
