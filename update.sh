#!/usr/bin/env bash
set -e

docker-compose pull

./go.sh

./wait.sh

docker-compose exec php-fpm composer site-update

docker-compose exec redis redis-cli flushdb
