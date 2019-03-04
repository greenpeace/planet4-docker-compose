#!/usr/bin/env bash
set -euo pipefail

PROJECT=${PROJECT:-$(basename "${PWD}" | sed 's/[\w.-]//g')}

network=${PROJECT}_proxy
endpoint=${APP_HOSTNAME:-http://www.planet4.test}

if [[ -n "${APP_HOSTPATH:-}" ]]
then
  endpoint="$endpoint/$APP_HOSTPATH/"
fi

string=greenpeace

# 6 seconds * 100 == 10+ minutes
interval=1
connect_timeout=5
loop=50

# Number of consecutive successes to qualify as 'up'
threshold=3
success=0

services=(
  "openresty"
  "php-fpm"
  "db"
  "redis"
)

echo "Waiting for services to start ..."
until [[ $success -ge $threshold ]]
do
  # Curl to container and expect 'greenpeace' in the response
  if docker run --network "$network" --rm appropriate/curl --connect-timeout $connect_timeout -s -k "$endpoint" | grep -s "$string" > /dev/null
  then
    success=$((success+1))
    echo -en "\\xE2\\x9C\\x94"
  else
    echo -n "."
    success=0
  fi

  for s in "${services[@]}"
  do
    if ! grep -q "$(docker-compose -p "${PROJECT}" ps -q "$s")" <<< "$(docker ps -q --no-trunc)"
    then
      echo
      docker ps -a | >&2 grep -E "Exited.+seconds?"
      echo
      docker-compose -p "${PROJECT}" logs "$s" | >&2 tail -20
      echo
      >&2 echo "ERROR: $s is not running"
      echo
      exit 1
    fi
  done

  loop=$((loop-1))
  if [[ $loop -lt 1 ]]
  then
    >&2 echo "[ERROR] Timeout waiting for docker-compose to start"
    >&2 docker-compose -p "${PROJECT}" logs
    exit 1
  fi

  [[ $success -ge $threshold ]] || sleep $interval

done
echo
