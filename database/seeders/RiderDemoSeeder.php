<?php

namespace Database\Seeders;

use App\Enums\RiderStatus;
use App\Enums\Role;
use App\Enums\UserStatus;
use App\Models\Rider;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Spatie\Permission\Models\Role as SpatieRole;

class RiderDemoSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed an approved, online rider so delivery offers flow end-to-end.
     */
    public function run(): void
    {
        if (! app()->environment(['local', 'testing'])) {
            return;
        }

        if (! SpatieRole::query()->where('name', Role::Rider->value)->exists()) {
            $this->call(RolePermissionSeeder::class);
        }

        DB::transaction(function (): void {
            $rider = User::query()->updateOrCreate(
                ['email' => 'rider@taladelivery.test'],
                [
                    'name' => 'Tala Demo Rider',
                    'phone' => '09172345678',
                    'password' => 'password',
                    'role' => Role::Rider->value,
                    'status' => UserStatus::Active->value,
                ],
            );

            $rider->syncRoles([Role::Rider->value]);

            Rider::query()->updateOrCreate(
                ['user_id' => $rider->id],
                [
                    'vehicle_type' => 'MOTORCYCLE',
                    'vehicle_plate' => 'ABC-1234',
                    'license_number' => 'R-123456',
                    'is_online' => true,
                    'status' => RiderStatus::Online->value,
                    'current_latitude' => 15.4867,
                    'current_longitude' => 120.9670,
                ],
            );
        });
    }
}