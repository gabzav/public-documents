cat > .devcontainer/Dockerfile <<'DOCKER'
FROM php:8.3-apache-bullseye

# System deps for PHP extensions + utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    git unzip curl \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libzip-dev libicu-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j"$(nproc)" gd zip intl pdo_sqlite \
  && a2enmod rewrite headers \
  && rm -rf /var/lib/apt/lists/*

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/local/bin --filename=composer

WORKDIR /workspaces/public-documents
DOCKER
