<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('delivery_zones', function (Blueprint $table) {
            $table->json('boundary_geojson')->nullable()->after('province');
            $table->decimal('maximum_delivery_km', 8, 2)->nullable()->after('included_km');
            $table->decimal('maximum_delivery_fee', 10, 2)->nullable()->after('extra_fee_per_km');
            $table->decimal('distance_rounding_km', 5, 2)->default(0.10)->after('maximum_delivery_fee');
            $table->timestamp('effective_from')->nullable()->after('distance_rounding_km');
            $table->foreignId('created_by')->nullable()->after('status')->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->after('created_by')->constrained('users')->nullOnDelete();
            $table->index(['status', 'effective_from']);
            $table->index(['city', 'province']);
        });

        DB::table('delivery_zones')
            ->where('status', 'INACTIVE')
            ->update(['status' => 'ARCHIVED']);

        Schema::table('delivery_zones', function (Blueprint $table) {
            $table->string('status')->default('DRAFT')->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::table('delivery_zones')
            ->whereIn('status', ['DRAFT', 'ARCHIVED'])
            ->update(['status' => 'INACTIVE']);

        Schema::table('delivery_zones', function (Blueprint $table) {
            $table->string('status')->default('ACTIVE')->change();
            $table->dropIndex(['status', 'effective_from']);
            $table->dropIndex(['city', 'province']);
            $table->dropConstrainedForeignId('created_by');
            $table->dropConstrainedForeignId('updated_by');
            $table->dropColumn([
                'boundary_geojson',
                'maximum_delivery_km',
                'maximum_delivery_fee',
                'distance_rounding_km',
                'effective_from',
            ]);
        });
    }
};
