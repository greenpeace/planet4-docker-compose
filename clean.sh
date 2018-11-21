#!/usr/bin/env bash

set -eax

PROJECT=${PROJECT:-$(basename "${PWD}" | sed 's/[.-]//g')}
DOCKER_COMPOSE_FILE=${DOCKER_COMPOSE_FILE:-docker-compose.yml}
if [ -d "persistence" ]
then
  read -p "Are you sure? [y/N] " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
  	docker-compose -p "${PROJECT}" -f "${DOCKER_COMPOSE_FILE}" down -v
  	sudo rm -fr persistence
  fi
fi
