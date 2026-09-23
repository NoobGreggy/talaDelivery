<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('deliveries', function (Blueprint $table) {
            $table->decimal('rider_commission', 10, 2)->nullable()->after('delivery_fee');
            $table->string('commission_type')->nullable()->after('rider_commission');
            $table->decimal('commission_value', 10, 2)->nullable()->after('commission_type');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('deliveries', function (Blueprint $table) {
            $table->dropColumn(['rider_commission', 'commission_type', 'commission_value']);
        });
    }
};
