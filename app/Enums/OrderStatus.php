<?php

namespace App\Enums;

enum OrderStatus: string
{
    case Pending = 'PENDING';
    case Confirmed = 'CONFIRMED';
    case Preparing = 'PREPARING';
    case ReadyForPickup = 'READY_FOR_PICKUP';
    case RiderAssigned = 'RIDER_ASSIGNED';
    case PickedUp = 'PICKED_UP';
    case OutForDelivery = 'OUT_FOR_DELIVERY';
    case Delivered = 'DELIVERED';
    case Cancelled = 'CANCELLED';

    public function label(): string
    {
        return match ($this) {
            self::Pending => 'Pending',
            self::Confirmed => 'Confirmed',
            self::Preparing => 'Preparing',
            self::ReadyForPickup => 'Ready for pickup',
            self::RiderAssigned => 'Rider assigned',
            self::PickedUp => 'Picked up',
            self::OutForDelivery => 'Out for delivery',
            self::Delivered => 'Delivered',
            self::Cancelled => 'Cancelled',
        };
    }
}
