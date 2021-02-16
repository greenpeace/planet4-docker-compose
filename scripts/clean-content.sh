#!/usr/bin/env bash
set -ea

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

# Remove generated Dockerfile
rm -f db/Dockerfile
