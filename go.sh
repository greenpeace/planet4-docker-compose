#!/usr/bin/env bash
set -ea

SCALE_OPENRESTY=${SCALE_OPENRESTY:-1}
SCALE_APP=${SCALE_APP:-1}

touch acme.json
chmod 600 acme.json

echo "Building services ..."
docker-compose build

echo "Starting services ..."
docker-compose up -d \
  --remove-orphans \
  --scale openresty="$SCALE_OPENRESTY" \
  --scale php-fpm="$SCALE_APP"

if [[ "${1:-}" = "-f" ]]
then
  docker-compose logs -f "${2:-php-fpm}"
fi
