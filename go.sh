#!/usr/bin/env bash
set -ea

SCALE_OPENRESTY=${SCALE_OPENRESTY:-1}
SCALE_APP=${SCALE_APP:-1}
PROJECT=${PROJECT:-$(basename "${PWD}" | sed 's/[\w.-]//g')}

touch acme.json
chmod 600 acme.json

echo "Building services ..."
docker-compose -p "${PROJECT}" -f "${DOCKER_COMPOSE_FILE:-docker-compose.yml}" build

echo "Starting services ..."
docker-compose -p "${PROJECT}" -f "${DOCKER_COMPOSE_FILE:-docker-compose.yml}" up -d \
  --remove-orphans \
  --scale openresty="$SCALE_OPENRESTY" \
  --scale php-fpm="$SCALE_APP"

if [[ "${1:-}" = "-f" ]]
then
  docker-compose logs -f "${2:-php-fpm}"
fi
