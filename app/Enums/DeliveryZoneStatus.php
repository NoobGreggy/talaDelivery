<?php

namespace App\Enums;

enum DeliveryZoneStatus: string
{
    case Draft = 'DRAFT';
    case Active = 'ACTIVE';
    case Suspended = 'SUSPENDED';
    case Archived = 'ARCHIVED';
}
