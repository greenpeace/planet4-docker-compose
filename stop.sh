#!/usr/bin/env bash
set -e

PROJECT=${PROJECT:-planet4}

if [[ $1 = "delete"  ]]
then
  docker-compose -p "${PROJECT}" -f "${DOCKER_COMPOSE_FILE:-docker-compose.yml}" down -v
  set -x
  sudo rm -fr persistence
  set +x
  echo 0
fi

docker-compose -p "${PROJECT}" -f "${DOCKER_COMPOSE_FILE:-docker-compose.yml}" down
