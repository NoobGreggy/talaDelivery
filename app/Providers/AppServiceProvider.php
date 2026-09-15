<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('api', function (Request $request) {
            $user = $request->user();

            if ($user) {
                $limit = $user->hasRole('platform_admin')
                    ? 240
                    : 120;

                return Limit::perMinute($limit)->by($user->getKey());
            }

            return Limit::perMinute(60)->by($request->ip());
        });
    }
}
