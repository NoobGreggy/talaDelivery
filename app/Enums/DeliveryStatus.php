<?php

namespace App\Enums;

enum DeliveryStatus: string
{
    case Unassigned = 'UNASSIGNED';
    case Assigned = 'ASSIGNED';
    case Accepted = 'ACCEPTED';
    case PickedUp = 'PICKED_UP';
    case InTransit = 'IN_TRANSIT';
    case Delivered = 'DELIVERED';
    case Failed = 'FAILED';
    case Cancelled = 'CANCELLED';
}
