#!/usr/bin/env bash
set -ex

NODE_USER=${NODE_USER:-node}

docker-compose exec -u "${NODE_USER}" node sh -c \
	"cd /app/source/public/wp-content/themes/planet4-master-theme \
  && npm run build"
