#!/usr/bin/env bash
set -eaux

APP_USER=${APP_USER:-app}
NODE_USER=${NODE_USER:-node}

docker-compose exec -u "${APP_USER}" php-fpm bash -c \
  "cd /app/source/public/wp-content/themes/planet4-master-theme \
  && composer install --prefer-dist"

docker-compose exec -u "${NODE_USER}" node sh -c \
	"cd /app/source/public/wp-content/themes/planet4-master-theme \
  && npm install --no-audit --progress=false"
