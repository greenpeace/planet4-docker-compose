#!/usr/bin/env bash
set -ea

PROJECT=${PROJECT:-$(basename "${PWD}" | sed 's/[.-]//g')}

COMPOSE_FILES=(
  "docker-compose.yml"
  "docker-compose.ci.yml"
  "docker-compose.stateless.yml"
)
for f in "${COMPOSE_FILES[@]}"
do
  # Remove containers, local images (db) and the shared volumes
  docker-compose -p "${PROJECT}" -f "$f" down --rmi local -v || true
done

if [ -d "persistence" ]
then
  echo
  echo "Deleting persistence directory (requires sudo to remove DB files)..."
  echo " \$ sudo rm -fr $(pwd)/persistence"
  echo

  read -p "Are you sure? [y/N] " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    echo
  	sudo rm -fr persistence
  fi
fi

CONTENT_PATH=${CONTENT_PATH:-defaultcontent}

if [ -d "${CONTENT_PATH}" ]
then
  echo
  echo "Deleting ${CONTENT_PATH} directory ..."
  read -p "Are you sure? [y/N] " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    echo
    set -x >/dev/null
    rm -fr "${CONTENT_PATH}"
    set +x >/dev/null
  fi
fi

# Remoove generated Dockerfile
rm -f db/Dockerfile
