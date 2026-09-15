<?php

namespace Database\Seeders;

use App\Enums\Role;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DefaultUserSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the default platform admin user.
     */
    public function run(): void
    {
        $admin = User::query()->firstOrCreate(
            ['email' => 'admin@taladelivery.test'],
            [
                'name' => 'Platform Admin',
                'phone' => '09171234567',
                'password' => 'password',
                'role' => Role::PlatformAdmin->value,
                'status' => 'ACTIVE',
            ],
        );

        $admin->assignRole(Role::PlatformAdmin->value);
    }
}
