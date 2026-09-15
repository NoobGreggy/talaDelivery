<?php

namespace App\Services;

use App\Jobs\SendNotification;
use App\Models\Notification;
use App\Models\User;

class NotificationService
{
    /**
     * @param  array<string, mixed>  $data
     */
    public function notify(User|int $user, string $type, string $title, string $message, array $data = []): void
    {
        $notification = Notification::query()->create([
            'user_id' => is_int($user) ? $user : $user->id,
            'type' => $type,
            'title' => $title,
            'message' => $message,
            'data' => $data,
        ]);

        SendNotification::dispatch($notification);
    }
}
