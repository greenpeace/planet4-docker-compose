#!/usr/bin/env bash
set -u

while [ $# -gt 0 ]; do
  case "$1" in
    --env ) ENV="$2"; shift ;;
    --project ) PROJECT="$2"; shift ;;
    (--) shift; break ;;
    (*) break ;;
  esac
  shift
done

ENV=${ENV:-"local"}
PROJECT=${PROJECT:-"planet4-docker-compose"}
content_exists=false

echo "Checking content for project ${PROJECT} ..."
if [[ -n "$(ls -A persistence 2>/dev/null)" ]]; then
    content_exists=true
    echo "- Some content is already in the ./persistence folder."
fi
if [[ $(docker container ls -a --format '{{.Names}}' | grep -c "^${PROJECT}_") -gt 0 ]]; then
    content_exists=true
    echo "- Some containers already exist for this project:"
    docker container ls -a --filter name="${PROJECT}_" \
                                            --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.CreatedAt}}'
fi
if [[ $(docker volume ls --format '{{.Name}}' | grep -c "^${PROJECT}_") -gt 0 ]]; then
    content_exists=true
    echo "- Some volumes already exist for this project:"
    docker volume ls --filter name="${PROJECT}_"
fi
if [[ $(docker network ls --format '{{.Name}}' | grep -c "^${PROJECT}_") -gt 0 ]]; then
    content_exists=true
    echo "- Some networks already exist for this project:"
    docker network ls --filter name="${PROJECT}_"
fi
if [[ "${ENV}" == "develop" ]] && [[ "${content_exists}" == true ]]; then
    printf "\n"
    echo "You should run <make clean> before continuing, as this situation could lead to unexpected results."
    read -p "Do you still want to continue ? [y/N]: " -n 1 -r continue
    printf "\n"
    if [[ "${continue}" != "y" ]] && [[ "${continue}" != "Y" ]]; then
      printf "Aborting. \n"
        exit 1
    fi
fi
printf "OK.\n"
