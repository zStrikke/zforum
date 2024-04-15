FROM php:8.2-fpm as laravel

WORKDIR /usr/src

ARG user
ARG uid
ARG env

RUN apt update && apt install -y \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libc6 \
    zip \
    unzip \
    supervisor \
    default-mysql-client

RUN apt clean && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip

RUN pecl install redis

COPY --from=composer:2.6.5 /usr/bin/composer /usr/bin/composer

RUN useradd -G www-data,root -u $uid -d /home/$user $user

RUN mkdir -p /home/$user/.composer && \
    chown -R $user:$user /home/$user

COPY ./composer.* /usr/src/
COPY ./docker/php-fpm/php-prod.ini /usr/local/etc/php/conf.d/php.ini
COPY ./docker/php-fpm/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./docker/bin/update.sh /usr/src/update.sh

RUN if [ "$env" = "dev" ]; then \
        composer install --no-scripts; \
    else \
        composer install --prefer-dist --no-scripts --no-dev --no-autoloader && rm -rf /root/.composer; \
        composer dump-autoload --no-scripts --no-dev --optimize; \
    fi

COPY . .

RUN php artisan storage:link && \
    chmod +x ./update.sh && \
    chown -R $user:$user /usr/src && \
    chmod -R 775 ./storage ./bootstrap/cache

RUN rm ./README.md Dockerfile php.tar.xz php.tar.xz.asc .editorconfig .env.example .gitignore .gitattributes 

RUN rm -rf ./laravel

USER $user

FROM laravel AS worker
COPY ./docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisor.conf
CMD ["/bin/sh", "-c", "supervisord -c /etc/supervisor/conf.d/supervisor.conf"]

FROM laravel AS scheduler
CMD ["/bin/sh", "-c", "nice -n 10 sleep 60 && php /usr/src/artisan schedule:run --verbose --no-interaction"]
