#!/usr/bin/env bash
set -e

NODE_USER=${NODE_USER:-node}

docker-compose exec "${options[@]}" -u "${NODE_USER}" node sh -c \
  "cd /app/source/public/wp-content/themes/planet4-master-theme \
  && npm start"
