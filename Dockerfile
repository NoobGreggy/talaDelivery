# syntax=docker/dockerfile:1

# ============================================================
# TalaDelivery API
#
# Laravel API
# PHP 8.4
# Laravel Octane + Swoole
# Laravel Reverb
# PostgreSQL
# Redis Queue
#
# NO Node / NPM / Vite
# ============================================================


# ============================================================
# Composer
# ============================================================

FROM composer:2 AS composer


# ============================================================
# PHP Base
# ============================================================

FROM php:8.4-cli-alpine AS base

WORKDIR /app


# ------------------------------------------------------------
# System dependencies + PHP extensions
# ------------------------------------------------------------

RUN apk add --no-cache \
        $PHPIZE_DEPS \
        linux-headers \
        libzip-dev \
        icu-dev \
        postgresql-dev \
        openssl-dev \
        curl-dev \
    && docker-php-ext-install \
        pdo_pgsql \
        intl \
        bcmath \
        pcntl \
        zip \
        opcache \
    && pecl install swoole \
    && docker-php-ext-enable swoole


# Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer


# ============================================================
# Composer Dependencies
# ============================================================

FROM base AS dependencies

WORKDIR /app

COPY composer.json composer.lock ./


# Install production Laravel dependencies
RUN composer install \
        --no-interaction \
        --prefer-dist \
        --no-dev \
        --no-scripts \
        --no-autoloader


# ============================================================
# Application Build
# ============================================================

FROM base AS build

WORKDIR /app


# Application source
COPY . .


# Copy vendor directory from dependency stage
COPY --from=dependencies /app/vendor ./vendor


# ------------------------------------------------------------
# Laravel directories
# ------------------------------------------------------------

RUN mkdir -p \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/testing \
        storage/framework/views \
        storage/logs \
        bootstrap/cache


# ------------------------------------------------------------
# Composer optimized autoload
# ------------------------------------------------------------

RUN composer dump-autoload \
        --optimize \
        --no-dev


# ------------------------------------------------------------
# Verify required Laravel packages
#
# This intentionally FAILS the Docker build if Octane,
# Reverb, or Predis are missing from composer.json.
# ------------------------------------------------------------

RUN composer show laravel/octane \
    && composer show laravel/reverb \
    && composer show predis/predis


# ============================================================
# Runtime
# ============================================================

FROM base AS runtime

WORKDIR /app


# Copy completed application
COPY --from=build /app /app


# ============================================================
# PHP Production Configuration
# ============================================================

RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && { \
        echo "memory_limit=512M"; \
        echo "max_execution_time=60"; \
        echo "opcache.enable=1"; \
        echo "opcache.enable_cli=1"; \
        echo "opcache.validate_timestamps=0"; \
    } > "$PHP_INI_DIR/conf.d/taladelivery.ini"


# ============================================================
# Laravel Permissions
# ============================================================

RUN set -eux; \
    mkdir -p \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/testing \
        storage/framework/views \
        storage/logs \
        bootstrap/cache; \
    addgroup -g 1000 -S www; \
    adduser -u 1000 -S www -G www; \
    chown -R www:www /app; \
    chmod -R ug+rwX storage bootstrap/cache


# ============================================================
# Runtime User
# ============================================================

USER www


# ============================================================
# Ports
# ============================================================

# Laravel Octane / Swoole API
EXPOSE 8002

# Laravel Reverb
EXPOSE 6001


# ============================================================
# Default API Process
# ============================================================

CMD ["php", "artisan", "octane:start", "--server=swoole", "--host=0.0.0.0", "--port=8002"]