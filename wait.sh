#!/usr/bin/env bash
set -euo pipefail

PROJECT=${PROJECT:-$(basename "${PWD}" | sed 's/[\w.-]//g')}

network=${PROJECT}_proxy
endpoint=${APP_HOSTNAME:-http://www.planet4.test}

if [[ ! -z "${APP_HOSTPATH:-}" ]]
then
  endpoint="$endpoint/$APP_HOSTPATH/"
fi

string=greenpeace

# 2 seconds * 150 == 10+ minutes
interval=2
loop=300

# Number of consecutive successes to qualify as 'up'
threshold=3
success=0

echo "Waiting for services to start ..."
until [[ $success -ge $threshold ]]
do
  # Curl to container and expect 'greenpeace' in the response
  if docker run --network "$network" --rm appropriate/curl -s -k "$endpoint" | grep -s "$string" > /dev/null
  then
    success=$((success+1))
    echo -en "\\xE2\\x9C\\x94"
  else
    echo -n "."
    success=0
  fi

  loop=$((loop-1))
  if [[ $loop -lt 1 ]]
  then
    >&2 echo "[ERROR] Timeout waiting for docker-compose to start"
    >&2 docker-compose -p test logs
    exit 1
  fi

  [[ $success -ge $threshold ]] || sleep $interval

done
echo
