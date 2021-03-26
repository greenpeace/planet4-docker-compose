#!/usr/bin/env bash
set -ex

NODE_USER=${NODE_USER:-node}
NPM_BIN=${NPM_BIN:-npm}

docker-compose exec -u "${NODE_USER}" node sh -c \
	"cd /app/source/public/wp-content/themes/planet4-master-theme \
  && ${NPM_BIN} run build"

docker-compose exec -u "${NODE_USER}" node sh -c \
	"cd /app/source/public/wp-content/plugins/planet4-plugin-gutenberg-blocks \
  && ${NPM_BIN} run build"
