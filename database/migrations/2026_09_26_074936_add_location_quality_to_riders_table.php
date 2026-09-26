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
        Schema::table('riders', function (Blueprint $table) {
            $table->decimal('current_location_accuracy', 8, 2)->nullable()->after('current_longitude');
            $table->decimal('current_location_heading', 6, 2)->nullable()->after('current_location_accuracy');
            $table->decimal('current_location_speed', 8, 3)->nullable()->after('current_location_heading');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('riders', function (Blueprint $table) {
            $table->dropColumn([
                'current_location_accuracy',
                'current_location_heading',
                'current_location_speed',
            ]);
        });
    }
};
