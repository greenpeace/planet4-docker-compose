#!/usr/bin/env bash
set -eax

SCALE_OPENRESTY=${SCALE_OPENRESTY:-1}
SCALE_APP=${SCALE_APP:-1}

touch acme.json

# Ensure Elasticsearch has adequate resources
sudo sysctl -w vm.max_map_count=262144

[[ -f "acme.json" ]] && chmod 600 acme.json

docker-compose -f "${DOCKER_COMPOSE_FILE:-docker-compose.yml}" up -d \
  --scale openresty=$SCALE_OPENRESTY \
  --scale php-fpm=$SCALE_APP

[[ "$1" = "-f" ]] && docker-compose logs -f ${2:-php-fpm}

exit 0
