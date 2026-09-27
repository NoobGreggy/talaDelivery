<?php

use App\Support\ApiResponse;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => ApiResponse::success('Welcome to Tala Delivery API.'));
