#!/usr/bin/env bash
set -e

NODE_USER=${NODE_USER:-node}

if [ "${1}" = "" ]
  then plugin=true && theme=true && options=(-d)
elif [ "${1}" = "--theme-only" ]
  then theme=true && plugin=false && options=()
elif [ "${1}" = "--plugin-only" ]
  then theme=false && plugin=true && options=()
fi

if [ "${theme}" = true ]; then
  docker-compose exec "${options[@]}" -u "${NODE_USER}" node sh -c \
    "cd /app/source/public/wp-content/themes/planet4-master-theme \
    && npm start"
fi

if [ "${plugin}" = true ]; then
  docker-compose exec "${options[@]}" -u "${NODE_USER}" node sh -c \
    "cd /app/source/public/wp-content/plugins/planet4-plugin-gutenberg-blocks \
    && npm start"
fi
