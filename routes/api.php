<?php

use App\Http\Controllers\Admin\AdminCustomerController;
use App\Http\Controllers\Admin\AdminDeliveryController;
use App\Http\Controllers\Admin\AdminDeliveryZoneController;
use App\Http\Controllers\Admin\AdminOrderController;
use App\Http\Controllers\Admin\AdminRiderController;
use App\Http\Controllers\Admin\AdminStoreController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\Customer\AddressController;
use App\Http\Controllers\Customer\OrderController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\Public\ProductController;
use App\Http\Controllers\Public\StoreController;
use App\Http\Controllers\Rider\RiderController;
use App\Http\Controllers\Rider\RiderDeliveryController;
use App\Http\Controllers\Rider\RiderOfferController;
use App\Http\Controllers\StoreAdmin\StoreCategoryController;
use App\Http\Controllers\StoreAdmin\StoreOrderController;
use App\Http\Controllers\StoreAdmin\StoreProductController;
use App\Http\Controllers\StoreAdmin\StoreProfileController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    /* ------------------------------------------------------------------ *
     *  Public — Authentication (Phase 2)
     * ------------------------------------------------------------------ */
    Route::prefix('auth')->group(function (): void {
        Route::post('register', [AuthController::class, 'register']);
        Route::post('login', [AuthController::class, 'login']);
    });

    /* ------------------------------------------------------------------ *
     *  Public — Store & Product browsing (Phase 4)
     * ------------------------------------------------------------------ */
    Route::get('stores', [StoreController::class, 'index']);
    Route::get('stores/{store}', [StoreController::class, 'show']);
    Route::get('stores/{store}/categories', [StoreController::class, 'categories']);
    Route::get('stores/{store}/products', [StoreController::class, 'products']);
    Route::get('products', [ProductController::class, 'index']);
    Route::get('products/{product}', [ProductController::class, 'show']);

    /* ------------------------------------------------------------------ *
     *  Public — Rider registration (Phase 8)
     * ------------------------------------------------------------------ */
    Route::post('rider/register', [RiderController::class, 'register']);

    /* ------------------------------------------------------------------ *
     *  Authenticated — Common (Phase 2)
     * ------------------------------------------------------------------ */
    Route::middleware('auth:sanctum')->group(function (): void {
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::get('auth/me', [AuthController::class, 'me']);
        Route::put('auth/profile', [AuthController::class, 'updateProfile']);
    });

    /* ------------------------------------------------------------------ *
     *  Customer — addresses (Phase 4)
     * ------------------------------------------------------------------ */
    Route::middleware('auth:sanctum')->prefix('addresses')->group(function (): void {
        Route::get('/', [AddressController::class, 'index']);
        Route::post('/', [AddressController::class, 'store']);
        Route::get('{address}', [AddressController::class, 'show']);
        Route::put('{address}', [AddressController::class, 'update']);
        Route::delete('{address}', [AddressController::class, 'destroy']);
    });

    /* ------------------------------------------------------------------ *
     *  Customer — orders (Phase 5)
     * ------------------------------------------------------------------ */
    Route::middleware('auth:sanctum')->prefix('orders')->group(function (): void {
        Route::get('/', [OrderController::class, 'index']);
        Route::post('/', [OrderController::class, 'store']);
        Route::get('{order}', [OrderController::class, 'show']);
        Route::post('{order}/cancel', [OrderController::class, 'cancel']);
    });

    /* ------------------------------------------------------------------ *
     *  Notifications (Phase 15)
     * ------------------------------------------------------------------ */
    Route::middleware('auth:sanctum')->prefix('notifications')->group(function (): void {
        Route::get('/', [NotificationController::class, 'index']);
        Route::get('{notification}', [NotificationController::class, 'show']);
        Route::post('{notification}/read', [NotificationController::class, 'markAsRead']);
    });

    /* ------------------------------------------------------------------ *
     *  Rider — profile, availability, offers, deliveries (Phase 8-10)
     * ------------------------------------------------------------------ */
    Route::middleware('auth:sanctum')->prefix('rider')->group(function (): void {
        Route::get('profile', [RiderController::class, 'profile']);
        Route::post('online', [RiderController::class, 'online']);
        Route::post('offline', [RiderController::class, 'offline']);
        Route::post('location', [RiderController::class, 'location']);
        Route::get('deliveries', [RiderController::class, 'deliveries']);
        Route::get('offers', [RiderOfferController::class, 'index']);
        Route::post('offers/{offer}/accept', [RiderOfferController::class, 'accept']);
        Route::post('offers/{offer}/reject', [RiderOfferController::class, 'reject']);
        Route::post('deliveries/{delivery}/arrived', [RiderDeliveryController::class, 'arrived']);
        Route::post('deliveries/{delivery}/pickup', [RiderDeliveryController::class, 'pickup']);
        Route::post('deliveries/{delivery}/start', [RiderDeliveryController::class, 'start']);
        Route::post('deliveries/{delivery}/complete', [RiderDeliveryController::class, 'complete']);
    });

    /* ------------------------------------------------------------------ *
     *  Store admin — profile, categories, products, orders (Phase 4-5)
     * ------------------------------------------------------------------ */
    Route::middleware(['auth:sanctum', 'role:store_admin,sanctum', 'store.tenant'])->prefix('store')->group(function (): void {
        Route::get('profile', [StoreProfileController::class, 'show']);
        Route::put('profile', [StoreProfileController::class, 'update']);

        Route::get('categories', [StoreCategoryController::class, 'index']);
        Route::post('categories', [StoreCategoryController::class, 'store']);
        Route::get('categories/{category}', [StoreCategoryController::class, 'show']);
        Route::put('categories/{category}', [StoreCategoryController::class, 'update']);
        Route::delete('categories/{category}', [StoreCategoryController::class, 'destroy']);

        Route::get('products', [StoreProductController::class, 'index']);
        Route::post('products', [StoreProductController::class, 'store']);
        Route::get('products/{product}', [StoreProductController::class, 'show']);
        Route::put('products/{product}', [StoreProductController::class, 'update']);
        Route::delete('products/{product}', [StoreProductController::class, 'destroy']);

        Route::get('orders', [StoreOrderController::class, 'index']);
        Route::get('orders/{order}', [StoreOrderController::class, 'show']);
        Route::post('orders/{order}/confirm', [StoreOrderController::class, 'confirm']);
        Route::post('orders/{order}/preparing', [StoreOrderController::class, 'preparing']);
        Route::post('orders/{order}/ready', [StoreOrderController::class, 'ready']);
        Route::post('orders/{order}/cancel', [StoreOrderController::class, 'cancel']);
    });

    /* ------------------------------------------------------------------ *
     *  Admin — platform_admin (Phase 16)
     * ------------------------------------------------------------------ */
    Route::middleware(['auth:sanctum', 'role:platform_admin,sanctum'])->prefix('admin')->group(function (): void {
        Route::get('dashboard', [DashboardController::class, 'index']);

        Route::get('orders', [AdminOrderController::class, 'index']);
        Route::get('orders/{order}', [AdminOrderController::class, 'show']);

        Route::get('stores', [AdminStoreController::class, 'index']);
        Route::post('stores', [AdminStoreController::class, 'store']);
        Route::get('stores/{store}', [AdminStoreController::class, 'show']);
        Route::put('stores/{store}', [AdminStoreController::class, 'update']);

        Route::get('customers', [AdminCustomerController::class, 'index']);

        Route::get('delivery-zones', [AdminDeliveryZoneController::class, 'index']);
        Route::post('delivery-zones', [AdminDeliveryZoneController::class, 'store']);
        Route::get('delivery-zones/{deliveryZone}', [AdminDeliveryZoneController::class, 'show']);
        Route::put('delivery-zones/{deliveryZone}', [AdminDeliveryZoneController::class, 'update']);
        Route::delete('delivery-zones/{deliveryZone}', [AdminDeliveryZoneController::class, 'destroy']);

        Route::get('deliveries', [AdminDeliveryController::class, 'index']);
        Route::get('deliveries/{delivery}', [AdminDeliveryController::class, 'show']);
        Route::post('deliveries/{delivery}/assign', [AdminDeliveryController::class, 'assign']);
        Route::post('deliveries/{delivery}/cancel', [AdminDeliveryController::class, 'cancel']);

        Route::get('riders', [AdminRiderController::class, 'index']);
        Route::get('riders/{rider}', [AdminRiderController::class, 'show']);
        Route::post('riders/{rider}/approve', [AdminRiderController::class, 'approve']);
        Route::post('riders/{rider}/reject', [AdminRiderController::class, 'reject']);
        Route::post('riders/{rider}/suspend', [AdminRiderController::class, 'suspend']);
    });
});
