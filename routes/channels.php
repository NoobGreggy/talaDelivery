<?php

use App\Enums\DeliveryStatus;
use App\Enums\Role;
use App\Models\Delivery;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('user.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});

Broadcast::channel('store.{id}', function ($user, $storeId) {
    if ($user->hasRole('platform_admin')) {
        return true;
    }

    return $user->stores()->where('stores.id', (int) $storeId)->exists();
});

Broadcast::channel('delivery.{id}', function ($user, $deliveryId) {
    $delivery = Delivery::query()->with('order:id,customer_id')->find($deliveryId);

    if ($delivery === null) {
        return false;
    }

    if (! in_array($delivery->status, [
        DeliveryStatus::Assigned,
        DeliveryStatus::Accepted,
        DeliveryStatus::PickedUp,
        DeliveryStatus::InTransit,
    ], true)) {
        return false;
    }

    return $user->role === Role::PlatformAdmin
        || $delivery->rider_id === $user->id
        || $delivery->order?->customer_id === $user->id;
});
