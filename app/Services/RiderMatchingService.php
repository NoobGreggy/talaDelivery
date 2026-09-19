<?php

namespace App\Services;

use App\Enums\DeliveryOfferStatus;
use App\Enums\DeliveryStatus;
use App\Enums\OrderStatus;
use App\Enums\RiderStatus;
use App\Enums\Role;
use App\Enums\UserStatus;
use App\Events\DeliveryOffered;
use App\Events\DeliveryUpdated;
use App\Events\OrderUpdated;
use App\Jobs\ExpireDeliveryOffer;
use App\Models\Delivery;
use App\Models\DeliveryOffer;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class RiderMatchingService
{
    public function __construct(
        public PricingService $pricing,
        public NotificationService $notifications,
    ) {}

    public function match(Delivery $delivery): ?DeliveryOffer
    {
        if ($delivery->status !== DeliveryStatus::Unassigned || $delivery->rider_id !== null) {
            return null;
        }

        if ($delivery->has('offers')->where('status', DeliveryOfferStatus::Pending)->exists()) {
            return null;
        }

        $alreadyOffered = DeliveryOffer::where('delivery_id', $delivery->id)->pluck('rider_id');

        $candidates = User::query()
            ->role(Role::Rider->value)
            ->where('status', UserStatus::Active)
            ->whereHas('rider', function ($query): void {
                $query
                    ->where('status', RiderStatus::Online)
                    ->whereNotNull('current_latitude')
                    ->whereNotNull('current_longitude');
            })
            ->when($alreadyOffered->isNotEmpty(), fn ($query) => $query->whereNotIn('id', $alreadyOffered))
            ->with('rider')
            ->get();

        $nearest = $candidates
            ->sortBy(fn (User $rider) => $this->pricing->distanceKm(
                (float) $delivery->pickup_latitude,
                (float) $delivery->pickup_longitude,
                (float) $rider->rider->current_latitude,
                (float) $rider->rider->current_longitude,
            ))
            ->first();

        if (! $nearest) {
            return null;
        }

        $offeredAt = now();
        $expiresAt = $offeredAt->copy()->addMinutes(5);

        $offer = $delivery->offers()->create([
            'rider_id' => $nearest->id,
            'status' => DeliveryOfferStatus::Pending,
            'offered_at' => $offeredAt,
            'expires_at' => $expiresAt,
        ]);

        ExpireDeliveryOffer::dispatch($offer)->delay($expiresAt);

        DeliveryOffered::dispatch($offer);

        $this->notifications->notify(
            $nearest,
            'offer.new',
            'New delivery offer',
            'You have a new delivery offer. You have 5 minutes to respond.',
            ['delivery_id' => $delivery->id, 'offer_id' => $offer->id],
        );

        return $offer;
    }

    public function accept(DeliveryOffer $offer, User $rider): Delivery
    {
        return DB::transaction(function () use ($offer, $rider) {
            $lockedOffer = DeliveryOffer::whereKey($offer->id)->lockForUpdate()->firstOrFail();

            if ($lockedOffer->rider_id !== $rider->id) {
                throw new \DomainException('This offer does not belong to you.');
            }

            if ($lockedOffer->status !== DeliveryOfferStatus::Pending) {
                throw new \DomainException('This offer is no longer available.');
            }

            if ($lockedOffer->expires_at && now()->greaterThanOrEqualTo($lockedOffer->expires_at)) {
                $lockedOffer->update([
                    'status' => DeliveryOfferStatus::Expired,
                    'responded_at' => now(),
                ]);

                $this->matchNext($lockedOffer->delivery);

                throw new \DomainException('This offer has expired.');
            }

            $delivery = Delivery::whereKey($lockedOffer->delivery_id)->lockForUpdate()->firstOrFail();

            if ($delivery->rider_id !== null || $delivery->status !== DeliveryStatus::Unassigned) {
                throw new \DomainException('This delivery has already been assigned to another rider.');
            }

            $riderProfile = $rider->rider;

            if (! $riderProfile || $riderProfile->status === RiderStatus::Busy || $riderProfile->status === RiderStatus::Suspended) {
                throw new \DomainException('You cannot accept a delivery while busy or suspended.');
            }

            $lockedOffer->update([
                'status' => DeliveryOfferStatus::Accepted,
                'responded_at' => now(),
            ]);

            $delivery->update([
                'rider_id' => $rider->id,
                'status' => DeliveryStatus::Assigned,
                'assigned_at' => now(),
            ]);

            $riderProfile->updateQuietly(['status' => RiderStatus::Busy]);

            $order = $delivery->order;

            if ($order) {
                $order->update(['status' => OrderStatus::RiderAssigned]);

                $this->notifications->notify(
                    $order->customer_id,
                    'order.rider_assigned',
                    'Rider assigned',
                    'A rider has been assigned to your order.',
                    ['order_id' => $order->id, 'delivery_id' => $delivery->id],
                );

                OrderUpdated::dispatch($order);
            }

            DeliveryUpdated::dispatch($delivery->fresh());

            return $delivery->fresh('order');
        });
    }

    public function reject(DeliveryOffer $offer, User $rider): DeliveryOffer
    {
        return DB::transaction(function () use ($offer, $rider) {
            $lockedOffer = DeliveryOffer::whereKey($offer->id)->lockForUpdate()->firstOrFail();

            if ($lockedOffer->rider_id !== $rider->id) {
                throw new \DomainException('This offer does not belong to you.');
            }

            if ($lockedOffer->status !== DeliveryOfferStatus::Pending) {
                throw new \DomainException('This offer is no longer available.');
            }

            $lockedOffer->update([
                'status' => DeliveryOfferStatus::Rejected,
                'responded_at' => now(),
            ]);

            $this->matchNext($lockedOffer->delivery);

            return $lockedOffer;
        });
    }

    public function matchNext(Delivery $delivery): ?DeliveryOffer
    {
        if ($delivery->rider_id !== null) {
            return null;
        }

        return $this->match($delivery);
    }
}
