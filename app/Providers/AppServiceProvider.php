<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Foundation\DevCommands;
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
        if ($this->app->environment('local')) {
            DevCommands::artisan('serve --host=0.0.0.0 --port=8000', 'server');
            DevCommands::artisan('reverb:start', 'reverb');
        }

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
