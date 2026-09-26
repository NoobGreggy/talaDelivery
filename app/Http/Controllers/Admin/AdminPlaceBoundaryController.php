<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\SearchPlaceBoundaryRequest;
use App\Services\PlaceBoundarySearchService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;

class AdminPlaceBoundaryController extends Controller
{
    public function __construct(private PlaceBoundarySearchService $boundaries) {}

    public function __invoke(SearchPlaceBoundaryRequest $request): JsonResponse
    {
        try {
            $results = $this->boundaries->search(
                $request->string('query')->squish()->toString(),
                $request->string('type')->toString(),
            );
        } catch (\DomainException $exception) {
            return ApiResponse::error($exception->getMessage(), status: 503);
        }

        return ApiResponse::success('Place boundaries retrieved.', $results);
    }
}
