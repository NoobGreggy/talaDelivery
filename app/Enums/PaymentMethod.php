<?php

namespace App\Enums;

enum PaymentMethod: string
{
    case Cod = 'COD';
    case Gcash = 'GCASH';
    case Maya = 'MAYA';
    case Card = 'CARD';
}
