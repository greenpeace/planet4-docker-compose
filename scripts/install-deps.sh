#!/usr/bin/env bash
set -eaux

APP_USER=${APP_USER:-app}
NODE_USER=${NODE_USER:-node}
NPM_BIN=${NPM_BIN:-npm}
NPM_OPTS=$([ "${NPM_BIN}" == "npm" ] && echo "--no-audit --progress=false" || echo "")

docker-compose exec -u "${APP_USER}" php-fpm bash -c \
  "cd /app/source/public/wp-content/themes/planet4-master-theme \
  && composer install --prefer-dist"
docker-compose exec -u "${APP_USER}" php-fpm bash -c \
  "cd /app/source/public/wp-content/plugins/planet4-plugin-gutenberg-blocks \
  && composer install --prefer-dist"

docker-compose exec -u "${NODE_USER}" node sh -c \
	"cd /app/source/public/wp-content/themes/planet4-master-theme \
  && ${NPM_BIN} install ${NPM_OPTS}"
docker-compose exec -u "${NODE_USER}" node sh -c \
	"cd /app/source/public/wp-content/plugins/planet4-plugin-gutenberg-blocks \
  && ${NPM_BIN} install ${NPM_OPTS}"
