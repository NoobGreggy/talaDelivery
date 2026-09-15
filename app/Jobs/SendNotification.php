<?php

namespace App\Jobs;

use App\Models\Notification;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class SendNotification implements ShouldQueue
{
    use Queueable;

    public function __construct(public Notification $notification) {}

    public function handle(): void
    {
        // MVP stores notifications in the database. Push (FCM) integration is added later.
    }
}
