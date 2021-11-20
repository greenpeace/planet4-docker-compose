#!/usr/bin/env bash
set -u

while [ $# -gt 0 ]; do
  case "$1" in
    --env ) ENV="$2"; shift ;;
    (--) shift; break ;;
    (*) break ;;
  esac
  shift
done

ENV=${ENV:-"local"}
OS=$(uname)
port_taken=false

if [[ "${OS}" == "Darwin" ]]; then
  web=$(lsof -n -i -P | awk '$10 ~ "LISTEN" && $9 ~ ":80$"')
  webcache=$(lsof -n -i -P | awk '$10 ~ "LISTEN" && $9 ~ ":8080$"')
  https=$(lsof -n -i -P | awk '$10 ~ "LISTEN" && $9 ~ ":443$"')
else
  web=$(netstat -aln | awk '$6 == "LISTEN" && $4 ~ ":80$"')
  webcache=$(netstat -aln | awk '$6 == "LISTEN" && $4 ~ ":8080$"')
  https=$(netstat -aln | awk '$6 == "LISTEN" && $4 ~ ":443$"')
fi

if [[ -n "${web}" ]]; then
  port_taken=true
  echo "Local web port 80 is already in use."
fi
if [[ -n "${webcache}" ]]; then
  port_taken=true
  echo "Local web port 8080 is already in use."
fi
if [[ -n "${https}" ]]; then
  port_taken=true
  echo "Local HTTPS port 443 is already in use."
fi
if [[ "${ENV}" == "develop" ]] && [[ "${port_taken}" == true ]]; then
    printf "\n"
    echo "At least one of the ports used for the application is currently busy."
    echo "You should stop the applications using those ports (usually an Apache or Nginx instance) before continuing."
    read -p "Do you still want to continue ? [y/N]: " -n 1 -r continue
    printf "\n"
    if [[ "${continue}" != "y" ]] && [[ "${continue}" != "Y" ]]; then
      printf "Aborting. \n"
        exit 1
    fi
fi
