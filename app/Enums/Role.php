<?php

namespace App\Enums;

enum Role: string
{
    case PlatformAdmin = 'platform_admin';
    case StoreAdmin = 'store_admin';
    case Rider = 'rider';
    case Customer = 'customer';
}
