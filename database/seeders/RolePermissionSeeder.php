<?php

namespace Database\Seeders;

use App\Enums\Role;
use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role as SpatieRole;

class RolePermissionSeeder extends Seeder
{
    /**
     * Seed the roles and permissions.
     */
    public function run(): void
    {
        $permissionsByRole = [
            Role::PlatformAdmin->value => [
                'manage-platform',
                'manage-stores',
                'manage-riders',
                'manage-customers',
                'manage-deliveries',
                'manage-delivery-zones',
                'manage-orders',
            ],
            Role::StoreAdmin->value => [
                'manage-store',
                'manage-products',
                'manage-categories',
                'manage-orders',
                'manage-deliveries',
            ],
            Role::Rider->value => [
                'manage-deliveries',
                'view-orders',
            ],
            Role::Customer->value => [
                'create-orders',
                'view-orders',
                'manage-addresses',
            ],
        ];

        foreach ($permissionsByRole as $role => $permissions) {
            $spatieRole = SpatieRole::query()->firstOrCreate(['name' => $role]);

            foreach ($permissions as $permission) {
                Permission::query()->firstOrCreate(['name' => $permission]);
            }

            $spatieRole->syncPermissions($permissions);
        }
    }
}
