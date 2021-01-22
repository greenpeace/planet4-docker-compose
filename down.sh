#!/usr/bin/env bash
set -e

if [[ $1 = "delete"  ]]
then
  docker-compose down -v
  set -x
  sudo rm -fr persistence
  set +x
  echo 0
fi

docker-compose down --time 60
