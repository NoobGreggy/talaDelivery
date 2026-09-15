<?php

namespace App\Enums;

enum RiderStatus: string
{
    case Pending = 'PENDING';
    case Rejected = 'REJECTED';
    case Offline = 'OFFLINE';
    case Online = 'ONLINE';
    case Busy = 'BUSY';
    case Suspended = 'SUSPENDED';
}
