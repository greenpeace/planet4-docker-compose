#!/usr/bin/env bash
set -e

docker-compose -f "${DOCKER_COMPOSE_FILE:-docker-compose.yml}" pull

./go.sh

./wait.sh

docker-compose -f "${DOCKER_COMPOSE_FILE:-docker-compose.yml}" exec php-fpm composer site-update

docker-compose -f "${DOCKER_COMPOSE_FILE:-docker-compose.yml}" exec redis redis-cli flushdb
