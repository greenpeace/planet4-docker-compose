#!/usr/bin/env bash
#set -x

if [ -z "${COMPOSE_PROJECT_NAME:-}" ]; then
  # shellcheck disable=SC1091
  source .env
fi

# Report ID used to identify queries generated by this script,
# and avoid cache issues
report_id=$(date +%s)
# If an error is found, set to 1
# This will be used as script exit code
errors_found=0

# Compare expected `make status` output with current instance
function check_status() {
  local status
  local expected

  status=$(make status)
  expected="
*** .env file ***

# docker-compose env variables
COMPOSE_FILE=${COMPOSE_FILE}
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}

*** Docker compose status ***

              Name                            Command               State                                Ports
--------------------------------------------------------------------------------------------------------------------------------------------
${COMPOSE_PROJECT_NAME}_db_1          docker-entrypoint.sh mysqld      Up      3306/tcp, 33060/tcp
${COMPOSE_PROJECT_NAME}_node_1        docker-entrypoint.sh node        Up
${COMPOSE_PROJECT_NAME}_openresty_1   /app/bin/entrypoint.sh /sb ...   Up      443/tcp, 80/tcp
${COMPOSE_PROJECT_NAME}_php-fpm_1     /app/bin/entrypoint.sh /sb ...   Up      9000/tcp
${COMPOSE_PROJECT_NAME}_redis_1       docker-entrypoint.sh redis ...   Up      6379/tcp
${COMPOSE_PROJECT_NAME}_traefik_1     /traefik --web --docker -- ...   Up      0.0.0.0:443->443/tcp, 0.0.0.0:80->80/tcp, 0.0.0.0:8080->8080/tcp

*** Credentials ***

             | User      | Password
-----------------------------------------------
 Wordpress   | admin     | admin
-----------------------------------------------
 Database    | planet4   | Phoh4zaeshaiT9ee
             | root      | root

*** Links ***

 Frontend   - http://www.planet4.test
 Backend    - http://www.planet4.test/admin
 Traefik    - http://localhost:8080/
"

  # Ignore all spaces, empty lines and separator lines
  if ! diff_result=$(diff -wbB --color -I '^---.*' <(echo "${expected}") <(echo "${status}")); then
    errors_found=1
    echo "Status: $(nok 'Unexpected status, failing.')"
    echo "${diff_result}"
  else
    echo "Status: $(ok)"
  fi
}

function check_website() {
  check_homepage
  echo
  check_login
}

# Homepage should
# - respond properly (HTTP 200)
# - have a title html tag
# - not contain any PHP error, warning, notice or deprecation message
function check_homepage() {
  homepage="http://www.planet4.test?_diag=${report_id}"
  echo "Querying ${homepage}"
  homepage_content=$(local_curl "${homepage}" 2>&1)

  # Check homepage content
  hp_status_code=$(echo "${homepage_content}" | grep "< HTTP/1.1")
  hp_title=$(echo "${homepage_content}" | grep -Pzo "(?s)<title>.*</title>" | tr -d '\n\0')
  hp_php_errors=$(echo "${homepage_content}" | grep -Pzo "<b>(Warning|Error|Notice|Deprecated)</b>(.*)\n")
  if [[ "${hp_status_code}" == "" ]]; then
    errors_found=1
    echo "Status code: $(nok)"
    echo "${homepage_content}"
    return 1
  fi

  # Define booleans for report
  hp_status_code_ok=$(if [[ "${hp_status_code}" == *"200 OK"* ]]; then echo true; else echo false; fi)
  hp_title_exists=$(if [[ "${hp_title}" != "" ]]; then echo true; else echo false; fi)
  hp_no_php_errors=$(if [[ "${hp_php_errors}" == "" ]]; then echo true; else echo false; fi)

  # Report
  echo "Status code: $(if [[ $hp_status_code_ok == true ]]; then ok; else nok "${hp_status_code}"; fi)"
  echo "Title: $(if [[ $hp_title_exists == true ]]; then ok; else nok; fi)"
  echo "PHP errors: $(if [[ $hp_no_php_errors = true ]]; then ok; else nok "${hp_php_errors}"; fi)"

  if [[ $hp_title_exists = false || $hp_no_php_errors = false || $hp_status_code_ok = false ]]; then
    errors_found=1
  fi
}

# Login page should
# - respond properly (HTTP 200)
# - have a login form
# - not contain any PHP error, warning, notice or deprecation message
function check_login() {
  login="http://www.planet4.test/wp-login.php?_diag=${report_id}"
  echo "Querying ${login}"
  login_content=$(local_curl "${login}" 2>&1)

  # Check login content
  lg_status_code=$(echo "${login_content}" | grep "< HTTP/1.1")
  lg_form=$(echo "${login_content}" | grep "<form name=\"loginform\"")
  lg_php_errors=$(echo "${login_content}" | grep -Pzo "<b>(Warning|Error|Notice|Deprecated)</b>(.*)\n" | tr -d '\0')
  if [[ "${lg_status_code}" == "" ]]; then
    errors_found=1
    echo "Status code: $(nok)"
    echo "${login_content}"
    return 1
  fi

  # Define booleans for report
  lg_status_code_ok=$(if [[ "${lg_status_code}" == *"200 OK"* ]]; then echo true; else echo false; fi)
  lg_form_exists=$(if [[ "${lg_form}" != "" ]]; then echo true; else echo false; fi)
  lg_no_php_errors=$(if [[ "${lg_php_errors}" == "" ]]; then echo true; else echo false; fi)

  # Report
  echo "Status code: $(if [[ $lg_status_code_ok == true ]]; then ok; else nok "${lg_status_code}"; fi)"
  echo "Login form: $(if [[ $lg_form_exists == true ]]; then ok; else nok; fi)"
  echo "PHP errors: $(if [[ $lg_no_php_errors = true ]]; then ok; else nok "${lg_php_errors}"; fi)"

  if [[ $lg_form_exists = false || $lg_no_php_errors = false || $lg_status_code_ok = false ]]; then
    errors_found=1
  fi
}

# Logs are filtered against a known list,
# any unexpected log will trigger an error
function check_logs() {
  local unexpected_logs

  unexpected_logs=$(filter_logs)
  if [[ "${unexpected_logs}" != "" ]]; then
    errors_found=1
    echo "Logs: $(nok 'Unexpected logs found, failing.')"
    echo "${unexpected_logs}"
  else
    echo "Logs: $(ok)"
  fi
}

function filter_logs() {
  local logs
  local known_logs

  logs=$(docker-compose logs php-fpm 2>/dev/null)
  known_logs=(
    # Codebase errors (to fix)
    "PHP Notice:  Undefined index: youtube_id"
    # Warnings during install
    "NOTICE: PHP message: PHP Warning:  Redis::connect(): php_network_getaddresses: getaddrinfo failed"
    "NOTICE: PHP message: PHP Warning:  filectime(): stat failed"
    # Warning during NRO install
    "ssmtp: Cannot open smtp:25"
    # Xdebug running without client
    "NOTICE: PHP message: Xdebug: [Step Debug] Could not connect to debugging client."
    # APM installation
    "Sending events to APM Server failed."
    # FPM regular messages
    "NOTICE: using inherited socket fd"
    "NOTICE: fpm is running, pid"
    "NOTICE: ready to handle connections"
    "NOTICE: systemd monitor interval set to"
    "NOTICE: Reloading in progress"
    "NOTICE: reloading: execvp"
    "NOTICE: Terminating ..."
    "NOTICE: exiting, bye-bye!"
  )

  while IFS= read -r line; do
    # Retrieve only potential errors
    error=$(echo "$line" | grep -Po ".*(NOTICE:|WARNING:|ERROR:).*")
    if [[ "${error}" == "" ]]; then
      continue
    fi
    for known_err in "${known_logs[@]}"; do
      # Filter known logs, if found skip and read next line
      if [[ "${error}" == *"${known_err}"* ]]; then
        continue 2
      fi
    done
    echo "${error}"
  done <<<"$logs"
}

function ok() {
  echo -e "OK \e[32m✔\e[0m"
}

function nok() {
  echo -e "NOK \e[31m✖\e[0m"
  if [[ "${1}" != "" ]]; then
    while IFS= read -r line; do
      echo "  - ${line}"
    done <<<"${1}"
  fi
}

function local_curl() {
  # local network
  # network=${COMPOSE_PROJECT_NAME}_proxy
  # docker run --network "${COMPOSE_PROJECT_NAME}_proxy" appropriate/curl -v --silent -H 'Cache-Control: no-cache' "${1}"
  curl -v --silent -H 'Cache-Control: no-cache' "${1}"
}

# MAIN

echo "* Checking installation status..."
check_status
echo
echo "* Checking website..."
check_website
echo
echo "* Checking container logs..."
check_logs

exit $errors_found
