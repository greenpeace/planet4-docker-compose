#!/usr/bin/env bash
set -eu

APP_USER=${APP_USER:-app}

echo "Updating main theme..."
docker-compose exec -u "${APP_USER}" php-fpm bash -c \
	"cd /app/source/public/wp-content/themes/planet4-master-theme && \
	git checkout master && \
	git pull && \
	git submodule update"

echo "Updating gutenberg blocks..."
docker-compose exec -u  "${APP_USER}" php-fpm bash -c \
	"cd /app/source/public/wp-content/plugins/planet4-plugin-gutenberg-blocks && \
	git checkout master && \
	git pull && \
	git submodule update"