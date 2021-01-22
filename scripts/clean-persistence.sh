#!/usr/bin/env bash
set -ea

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
