<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            RolePermissionSeeder::class,
            DefaultUserSeeder::class,
        ]);

        if (app()->environment(['local', 'testing'])) {
            $this->call(CustomerDemoSeeder::class);
            $this->call(RiderDemoSeeder::class);
            $this->call(MerchantDemoSeeder::class);
        }
    }
}
