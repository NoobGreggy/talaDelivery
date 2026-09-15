<?php

namespace App\Http\Middleware;

use App\Support\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAppKey
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $providedKey = $request->header('X-App-Key');

        if (is_string($providedKey) && $providedKey === config('app.api_key')) {
            return $next($request);
        }

        return ApiResponse::error('Missing or invalid X-App-Key header.', null, 401);
    }
}
