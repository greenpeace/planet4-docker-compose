#!/usr/bin/env bash
set -eu

APP_USER=${APP_USER:-app}

echo "Updating main theme..."
docker-compose exec -u "${APP_USER}" php-fpm bash -c \
	"cd /app/source/public/wp-content/themes/planet4-master-theme && \
	git checkout main && \
	git pull && \
	git submodule update"
