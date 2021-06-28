#!/usr/bin/env bash
set -u

GSUTIL=$(command -v gsutil)
DUMP_URL=

while [ $# -gt 0 ]; do
  case "$1" in
    --nro ) NRO_NAME="$2"; shift ;;
    --project ) PROJECT_ID="$2"; shift ;;
    --bucket ) DB_BUCKET="$2"; shift ;;
    --version ) DB_VERSION="$2"; shift ;;
    --dest ) DEST_DIR="$2"; shift ;;
    --database ) DB_NAME="$2"; shift ;;
    --dump ) DUMP_PATH="$2"; shift ;;
    --mysql-user ) MYSQL_USER="$2"; shift ;;
    --mysql-root-pass ) MYSQL_ROOT_PASS="$2"; shift ;;
    --overwrite ) OVERWRITE="$2"; shift ;;
    (--) shift; break ;;
    (*) break ;;
  esac
  shift
done

NRO_NAME=${NRO_NAME:-}
PROJECT_ID=${PROJECT_ID:-"planet-4-151612"}
DEST_DIR=${DEST_DIR:-"./defaultcontent"}
DB_BUCKET=${DB_BUCKET:-"planet4-${NRO_NAME}-master-db-backup"}
DB_VERSION=${DB_VERSION:-"latest"}
DB_NAME=${DB_NAME:-"$(echo "planet4_${NRO_NAME}" | sed 's/-/_/g')"}
DUMP_PATH=${DUMP_PATH:-}
OVERWRITE=${OVERWRITE:-}

MYSQL_USER=${MYSQL_USER:-"planet4"}
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-"root"}

# MySQL shorthand functions
function mysql_root_exec() {
  docker-compose exec db mysql -uroot -p"${MYSQL_ROOT_PASS}" "$@"
}

function mysql_root_exec_notty() {
  docker-compose exec -T db mysql -uroot -p"${MYSQL_ROOT_PASS}" "$@"
}

# Create database and check for content
# Display a validation prompt if content would be overwritten
function check_existing_db() {
  mysql_root_exec -e \
    "create database if not exists ${DB_NAME}; \
    grant all privileges on ${DB_NAME}.* to '${MYSQL_USER}'@'%'; \
    use ${DB_NAME}; \
    reset master;"

  TABLE=$(mysql_root_exec -D "${DB_NAME}" -e "show tables like 'wp_posts'\G" | tail -1)
  if [[ "${TABLE}" == *"wp_posts"* ]] && [[ "${OVERWRITE}" != "true" ]]; then
    if [[ "${OVERWRITE}" == "false" ]]; then
      printf "Skipping DB import.\n"
      exit 0;
    fi
    read -p "Database ${DB_NAME} exists, overwrite ? [y/N]: " -n 1 -r owdb
    printf "\n"
    if [[ "${owdb}" != "y" ]] && [[ "${owdb}" != "Y" ]]; then
      printf "Skipping DB import.\n"
      exit 0;
    fi
  fi
}

# Check gcloud auth
function check_auth() {
  echo "Checking gcloud authentication ..."
  if [[ $(gcloud auth list --filter=status:ACTIVE --format="value(account)" | wc -l) -lt 1 ]]; then
    echo "No gcloud account is currently active, " \
      "please use <gcloud auth login> to enable automatic database import."
  fi
}

# Switch GCloud project
function switch_project() {
  echo "Setting gcloud project to ${PROJECT_ID} ..."
  gcloud config set project "${PROJECT_ID}"
}

# Look for a dump corresponding to given parameters:
# bucket, NRO, version, existing dump
function find_db() {
  if [[ -n "${DUMP_URL}" ]]; then
    echo "Dump given: ${DUMP_URL}"
    return 0
  fi

  if [[ -n "${DUMP_PATH}" ]]; then
    DUMP_NAME=$(basename "${DUMP_PATH}")
  else
    DUMP_NAME=
  fi

  # Sort results by date and extract last filename only
  if [[ -n "${DUMP_NAME}" ]]; then
    DUMP_URL=$(gsutil ls -r "gs://${DB_BUCKET}/**/${DUMP_NAME}")
  elif [[ "${DB_VERSION}" == "latest" ]]; then
    DUMP_URL=$(gsutil ls -rl "gs://${DB_BUCKET}/**" | sort -k2n | \
               tail -n1 | awk 'END {$1=$2=""; sub(/^[ \t]+/, ""); print }')
  else
    DUMP_PREFIX="planet4-${NRO_NAME}-master-v${DB_VERSION}"
    DUMP_URL=$(gsutil ls -r "gs://${DB_BUCKET}/v${DB_VERSION}/${DUMP_PREFIX}-*.sql.gz")
  fi

  echo "Dump found: ${DUMP_URL}"
}

# Download dump file
# If no URL but file already exists, return ok
# Display validation prompt if file already exists
function download_db() {
  if [[ -z "${DUMP_URL}" ]]; then
    if [[ -f "${DUMP_PATH}" ]]; then
      return 0
    fi

    echo "No dump found."
    exit 1
  fi

  DUMP_NAME=$(basename "${DUMP_URL}")
  DUMP_PATH="${DEST_DIR}/${DUMP_NAME}"

  if [[ -f "${DUMP_PATH}" ]] && [[ "${OVERWRITE}" != "true" ]]; then
    if [[ "${OVERWRITE}" == "false" ]]; then
      printf "Skipping database download.\n" && return 0;
    fi
    read -p "File ${DUMP_PATH} exists, overwrite ? [y/N]: " -n 1 -r owdump
    printf "\n"
    if [[ "${owdump}" != "y" ]] && [[ "${owdump}" != "Y" ]]; then
      printf "Skipping database download.\n" && return 0;
    fi
  fi

  echo "Downloading database from ${DUMP_URL} ..."
  gsutil cp "${DUMP_URL}" "${DEST_DIR}"
}

# Import dump to database
function import_db() {
  if [[ ! -f "${DUMP_PATH}" ]]; then
    echo "Dump file <${DUMP_PATH}> does not exist or is not specified."
    exit 1
  fi

  echo "Importing database content from ${DUMP_PATH} ..."
  mysql_root_exec -e 'SET GLOBAL max_allowed_packet=16777216'
  zcat < "${DUMP_PATH}" | mysql_root_exec_notty "${DB_NAME}"
  # Fix GTID_PURGED value issue
  mysql_root_exec -D "${DB_NAME}" -e 'RESET MASTER'
}

#
# Main
# Import will work without gsutil, if --dump is a valid dump file
#

check_existing_db
if [[ ${GSUTIL} ]]; then
  check_auth
  switch_project
  find_db
  download_db
fi
import_db
