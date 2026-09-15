<?php

namespace App\Support;

use App\Models\Store;

class StoreContext
{
    private static ?Store $store = null;

    private static ?int $userId = null;

    public static function setStore(?Store $store): void
    {
        self::$store = $store;
    }

    public static function setUserId(?int $userId): void
    {
        self::$userId = $userId;
    }

    public static function store(): ?Store
    {
        return self::$store;
    }

    public static function storeId(): ?int
    {
        return self::$store?->id;
    }

    public static function userId(): ?int
    {
        return self::$userId;
    }

    public static function hasStore(): bool
    {
        return self::$store !== null;
    }

    public static function reset(): void
    {
        self::$store = null;
        self::$userId = null;
    }
}
