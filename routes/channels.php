<?php

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
