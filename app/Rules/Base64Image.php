<?php

namespace App\Rules;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;

class Base64Image implements ValidationRule
{
    private int $maxBytes;

    private int $maxMB;

    public function __construct(int $maxMB = 5)
    {
        $this->maxMB = $maxMB;
        $this->maxBytes = $maxMB * 1024 * 1024;
    }

    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        if (! is_string($value)) {
            $fail('The :attribute must be a base64 image string.');

            return;
        }

        $parts = explode(',', $value, 2);

        if (count($parts) !== 2) {
            $fail('The :attribute must be a valid base64 data URI.');

            return;
        }

        [$header, $data] = $parts;

        if (! preg_match('#^data:image/(png|jpe?g|gif|webp|svg\+xml)(;base64)?$#i', $header)) {
            $fail('The :attribute must be a PNG, JPEG, GIF, WebP, or SVG image.');

            return;
        }

        $decoded = base64_decode($data, true);

        if ($decoded === false) {
            $fail('The :attribute contains invalid base64 data.');

            return;
        }

        if (strlen($decoded) > $this->maxBytes) {
            $fail("The :attribute must not exceed {$this->maxMB} MB.");
        }
    }
}
