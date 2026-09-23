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
        Schema::create('platform_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique()->default('platform');
            $table->string('rider_commission_type')->default('PERCENTAGE');
            $table->decimal('rider_commission_value', 10, 2)->default(0);
            $table->string('earnings_week_type')->default('ROLLING_SEVEN_DAYS');
            $table->unsignedTinyInteger('week_starts_on')->default(1);
            $table->string('settlement_timezone')->default('Asia/Manila');
            $table->time('settlement_day_starts_at')->default('00:00:00');
            $table->string('distance_method')->default('STRAIGHT_LINE');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('platform_settings');
    }
};
