# include optional configuration (used for NRO configuration)
-include Makefile.include

ifdef CUSTOM_SHELL
	SHELL := $(CUSTOM_SHELL)
else
	SHELL := /bin/bash
endif

ifdef CUSTOM_MAKE
	MAKE := $(CUSTOM_MAKE)
else
	MAKE := make
endif

# Remove entering/leaving directory messages
ifndef VERBOSE
MAKEFLAGS += --no-print-directory
endif

SCALE_OPENRESTY ?=1
SCALE_APP ?=1

export SCALE_APP
export SCALE_OPENRESTY

APP_USER ?= app
export APP_USER
APP_HOSTPATH ?= test
# YAML interprets 'empty' values as 'nil'
ifeq ($(APP_HOSTPATH),<nil>)
# So if APP_HOSTPATH is set, but blank, clean this value
APP_HOSTPATH :=
endif

MYSQL_USER := $(shell grep MYSQL_USER db.env | cut -d'=' -f2)
MYSQL_PASS := $(shell grep MYSQL_PASSWORD db.env | cut -d'=' -f2)
ROOT_PASS := $(shell grep MYSQL_ROOT_PASSWORD db.env | cut -d'=' -f2)

WP_ADMIN_USER := admin
WP_ADMIN_PASS := admin

## Wordpress username
WP_USER ?= $(shell whoami)
## Wordpress user email address
WP_USER_EMAIL ?= $(shell git config --get user.email)
## Elastic Search host
ELASTICSEARCH_HOST ?= http://elasticsearch:9200/

DEFAULT_COMPOSE_FILE := docker-compose.yml
DEFAULT_COMPOSE_PROJECT_NAME := $(shell basename "$(PWD)" | sed 's/[.-]//g')
## Docker file added for nro tests
DOCKER_COMPOSE_TOOLS_FILE ?= docker-compose.tools.yml

NGINX_HELPER_JSON := $(shell cat options/rt_wp_nginx_helper_options.json)
REWRITE := /%category%/%post_id%/%postname%/
## Protocol used for cloning repos
export GIT_PROTO ?= https

XDEBUG_MODE ?= debug
XDEBUG_START_WITH_REQUEST ?= yes

# ============================================================================

# Downloaded content

## Database fixtures version
CONTENT_DB_VERSION ?= 0.2.22
## Images fixtures version
CONTENT_IMAGE_VERSION ?= 1-25
## Dev version used for quick install
DEVRELEASE_VERSION ?= latest

CONTENT_PATH := defaultcontent
export CONTENT_PATH
UPLOADS_PATH := persistence/app/public/wp-content/uploads

## Remote content repository
CONTENT_BASE 	    ?= https://storage.googleapis.com/planet4-default-content
CONTENT_DB 		    ?= planet4-defaultcontent_wordpress-v$(CONTENT_DB_VERSION).sql.gz
CONTENT_IMAGES    ?= planet4-default-content-$(CONTENT_IMAGE_VERSION)-images.zip
SOURCE_DEVRELEASE ?= planet4-persistence-$(DEVRELEASE_VERSION).gz

export CONTENT_DB

REMOTE_DB		      := $(CONTENT_BASE)/$(CONTENT_DB)
REMOTE_IMAGES     := $(CONTENT_BASE)/$(CONTENT_IMAGES)

LOCAL_DB				 := $(CONTENT_PATH)/$(CONTENT_DB)
LOCAL_IMAGES		 := $(CONTENT_PATH)/$(CONTENT_IMAGES)
LOCAL_DEVRELEASE ?= $(CONTENT_PATH)/$(SOURCE_DEVRELEASE)

# ============================================================================

# Check necessary commands exist

CIRCLECI := $(shell command -v circleci 2> /dev/null)
DOCKER := $(shell command -v docker 2> /dev/null)
ENVSUBST := $(shell command -v envsubst 2> /dev/null)
COMPOSER := $(shell command -v composer 2> /dev/null)
SHELLCHECK := $(shell command -v shellcheck 2> /dev/null)
YAMLLINT := $(shell command -v yamllint 2> /dev/null)
GSUTIL := $(shell command -v gsutil 2> /dev/null)

# ============================================================================

.DEFAULT_GOAL := all

.PHONY: all
all: build config status
	@echo "Ready"

.PHONY: init
init: .git/hooks/pre-commit .git/hooks/post-commit

.git/hooks/%:
	@chmod 755 .githooks/*
	@find .git/hooks -type l -exec rm {} \;
	@find .githooks -type f -exec ln -sf ../../{} .git/hooks/ \;

# ============================================================================

# SELF TESTS

.PHONY : lint
lint: init
	@$(MAKE) -j lint-docker lint-sh lint-yaml

lint-in-ci: init
	@$(MAKE) -j lint-docker lint-sh lint-yaml

lint-docker: db/Dockerfile
ifndef DOCKER
	$(error "docker is not installed: https://docs.docker.com/install/")
endif
	@docker run --rm -i hadolint/hadolint < db/Dockerfile

lint-sh:
ifndef SHELLCHECK
	$(error "shellcheck is not installed: https://github.com/koalaman/shellcheck")
endif
	@find . ! -path './persistence/*' -type f -name '*.sh' | xargs shellcheck

lint-yaml:
ifndef YAMLLINT
	$(error "yamllint is not installed: https://github.com/adrienverge/yamllint")
endif
	@find . ! -path './persistence/*' -type f -name '*.yml' | xargs yamllint

lint-commit:
	@npx commitlint -V --from main

# ============================================================================

## Configure local environment
.PHONY: env
env:
	@echo "Creating .env file"
	echo "# docker-compose env variables" > .env
	echo "COMPOSE_FILE=$${COMPOSE_FILE:-${DEFAULT_COMPOSE_FILE}}" >> .env
	echo "COMPOSE_PROJECT_NAME=$${COMPOSE_PROJECT_NAME:-${DEFAULT_COMPOSE_PROJECT_NAME}}" >> .env

.PHONY: envcheck
envcheck:
	@if [ -f .env ]; then \
		echo  ".env file exists"; \
	else \
		$(MAKE) env; fi

# ============================================================================

# CLEAN GENERATED ASSETS
## Remove containers, images, volumes, repos, default content
.PHONY: clean
clean: clean-containers clean-persistence clean-content

# Remove current containers and orphans
clean-containers:
	docker-compose down --remove-orphans --rmi local -v || true

# Remove persistence directory
clean-persistence:
	./scripts/clean-persistence.sh

# Remove default content
clean-content:
	./scripts/clean-content.sh

# ============================================================================

# DEFAULT CONTENT TASKS

$(CONTENT_PATH) $(UPLOADS_PATH):
	@mkdir -p $@

$(LOCAL_DB):
	@echo "Downloading default database to $(LOCAL_DB) ..."
	curl --fail $(REMOTE_DB) > $@

$(LOCAL_IMAGES):
	@echo "Downloading default content images to $(LOCAL_IMAGES) ..."
	curl --fail $(REMOTE_IMAGES) > $@

.PHONY: getdefaultcontent
getdefaultcontent: $(LOCAL_DB) $(LOCAL_IMAGES)

.PHONY: cleandefaultcontent
cleandefaultcontent:
	@rm -rf $(CONTENT_PATH)/*

.PHONY: updatedefaultcontent
updatedefaultcontent: cleandefaultcontent getdefaultcontent

.PHONY: unzipimages
unzipimages: $(LOCAL_IMAGES) $(UPLOADS_PATH)
	@unzip -qo $(LOCAL_IMAGES) -d $(UPLOADS_PATH)

# ============================================================================

# BUILD AND RUN: THE MEAT AND POTATOS

.PHONY: hosts
hosts:
	@if ! grep -q "127.0.0.1[[:space:]]\+www.planet4.test" /etc/hosts; then \
	cp /etc/hosts hosts.backup; \
	echo "Your hosts file has been backed up to $(PWD)/'hosts.backup'"; \
	echo ""; \
	echo "May require sudo password to configure the /etc/hosts file ..."; \
	echo -e "\n# Planet4 local development environment\n127.0.0.1\twww.planet4.test pma.www.planet4.test traefik.www.planet4.test" | sudo tee -a /etc/hosts; \
	else echo "Hosts file already configured"; fi

.PHONY: build
build: hosts secrets run unzipimages config elastic flush

## Run containers. Will either start or build them first if they don't exist
.PHONY: run
run: envcheck
	@services=$$(docker-compose ps --services); \
	stopped=$$(docker-compose ps --services  --filter status=stopped); \
	running=$$(docker-compose ps --services --filter status=running); \
	if [[ "$${services}" == "$${running}" ]]; then \
		$(MAKE) status; \
		exit 0; \
	elif [[ "$${services}" == "$${stopped}" ]]; then \
		$(MAKE) start; \
	else \
		$(MAKE) up; \
	fi

## Start containers
.PHONY: start
start:
	@docker-compose start \
	&& ./wait.sh

## Stop containers. Keeps containers modifications intact
.PHONY: stop
stop:
	@docker-compose stop --time 10

## Build and starts containers
.PHONY: up
up:
	@$(MAKE) -j init getdefaultcontent db/Dockerfile
	cp ci/scripts/duplicate-db.sh defaultcontent/duplicate-db.sh
	./go.sh
	@./wait.sh

.PHONY: down
## Stop and remove containers. Drops all containers modifications
down:
	@./down.sh

# ============================================================================

# DEVELOPER ENVIRONMENT

## Create containers, install developer tools, build assets
.PHONY: dev
dev: check-before-install hosts secrets repos run unzipimages config deps elastic flush status
	@if command -v xattr &> /dev/null; then \
		$(MAKE) fix-public-permissions; \
	fi
	@echo "Ready"


## Delete and rebuild planet4 main theme and plugin
.PHONY: repos
repos: clean-repos clone-repos

.PHONY: deps
deps: install-deps assets

## Update base, master-theme and gutenberg-blocks, rebuild assets
.PHONY: update
.ONESHELL:
update: update-this update-base update-deps
	@echo "Update done."

# Delete planet4 main theme and plugin
.PHONY: clean-repos
clean-repos:
	@rm -fr persistence/app/public/wp-content/themes/planet4-master-theme
	rm -fr persistence/app/public/wp-content/plugins/planet4-plugin-gutenberg-blocks

.PHONY: clone-repos
clone-repos:
	@./repos.sh

.PHONY: update-repos
update-repos:
	./scripts/update-repos.sh

.PHONY: install-deps
install-deps:
	./scripts/install-deps.sh

.PHONY: update-deps
update-deps:
	./scripts/update-repos.sh
	./scripts/install-deps.sh
	./scripts/build-assets.sh

.PHONY: update-base
update-base:
	docker-compose exec -u "${APP_USER}" php-fpm sh -c \
		"cd /app/source && git checkout main && git pull"

.PHONY: update-this
update-this:
	git pull

.PHONY: dev-install-xdebug xdebug-mode
dev-install-xdebug:
	docker-compose exec php-fpm sh -c 'apt-get update && apt-get install -yq php$${PHP_MAJOR_VERSION}-xdebug'
	$(MAKE) xdebug-mode --no-print-directory

xdebug-mode: check-envsubst
ifeq (Darwin, $(shell uname -s))
	$(eval export XDEBUG_REMOTE_HOST=$(shell ipconfig getifaddr en0))
else
	$(eval include .env)
	$(eval export XDEBUG_REMOTE_HOST=$(shell docker network inspect "${COMPOSE_PROJECT_NAME}_local" --format '{{(index .IPAM.Config 0).Gateway }}'))
endif
	$(eval export XDEBUG_MODE=${XDEBUG_MODE})
	$(eval export XDEBUG_START_WITH_REQUEST=${XDEBUG_START_WITH_REQUEST})
	envsubst < dev-templates/xdebug.tmpl > dev-templates/xdebug.out
	docker cp dev-templates/xdebug.out $(shell docker-compose ps -q php-fpm):/tmp/20-xdebug.ini
	docker-compose exec php-fpm sh -c 'mv /tmp/20-xdebug.ini /etc/php/$${PHP_MAJOR_VERSION}/fpm/conf.d/20-xdebug.ini'
	docker-compose exec php-fpm sh -c 'service php$${PHP_MAJOR_VERSION}-fpm reload'

.PHONY: check-before-install check-envsubst check-compose-version check-existing-content check-ports-availability
check-before-install: check-envsubst check-compose-version check-existing-content check-ports-availability

check-envsubst:
ifndef ENVSUBST
	$(error Command: 'envsubst' not found, please install using your package manager)
endif

# Filter out docker compose V2 until full compatibility
check-compose-version:
	@version=$$(docker-compose --version | grep -Eo '2\.[[:digit:]]{1,3}');
	if [[ ! -z $${version} ]]; then\
		echo "You are using docker compose version $${version}, please use version 1.* instead.";\
		exit 1;\
	fi

check-existing-content: envcheck
	@export $$(sed -e '/^\#/d' .env | xargs)
	@export $$(sed -e '/^\#/d' app.env | xargs)
	./scripts/check-existing-content.sh --project "$${COMPOSE_PROJECT_NAME}" --env "$${APP_ENV}"

check-ports-availability: envcheck
	@export $$(sed -e '/^\#/d' .env | xargs)
	@export $$(sed -e '/^\#/d' app.env | xargs)
	./scripts/check-ports-availability.sh --env "$${APP_ENV}"

# MacOS handles mixed ownership of files poorly and can freeze on some operations
# This command restores proper ownership
# Using find+chown is up to 10 times faster than chown on macos
fix-public-permissions:
	@echo "Fixing permissions of /app/source/public ..."
	docker-compose exec php-fpm bash -c \
		"[[ -e public ]] && find public ! -user ${APP_USER} -exec chown -f ${APP_USER} {} \;"

fix-node-permissions:
	@docker-compose exec -u root node sh -c 'chown -R node /app/source/public/wp-content/themes/planet4-master-theme/node_modules'
	docker-compose exec -u root node sh -c 'chown -R node /app/source/public/wp-content/plugins/planet4-plugin-gutenberg-blocks/node_modules'

fix-app-permissions:
	@echo "Fixing permissions of /app ..."
	docker-compose exec php-fpm sh -c \
		'find /app ! -user ${APP_USER} -exec chown -f ${APP_USER} {} \;'

fix-wflogs-permissions:
	@chmod -R 777 persistence/app/public/wp-content/wflogs

secrets:
	@mkdir $@
	touch $@/wp-stateless-media-key.json

admin-user:
	if docker-compose exec php-fpm wp user get $(WP_ADMIN_USER); then \
		docker-compose exec php-fpm wp user update $(WP_ADMIN_USER) --user_email=admin@planet4.test --user_pass=$(WP_ADMIN_PASS) --role=administrator
	else \
		docker-compose exec php-fpm wp user create $(WP_ADMIN_USER) admin@planet4.test --user_pass=$(WP_ADMIN_PASS) --role=administrator
	fi
# ============================================================================

# ELASTICSEARCH

.PHONY: elastic
elastic: elastic-run

elastic-index: check-services
	@if [[ "${ELASTIC_ENABLED}" != "" ]]; then \
		docker-compose exec php-fpm wp elasticpress index --setup --yes --url=www.planet4.test;\
	fi

elastic-run:
	@echo "Starting ElasticSearch"
	docker-compose -f docker-compose.full.yml up -d elasticsearch
	sleep 5
	docker-compose exec php-fpm wp option update ep_host $(ELASTICSEARCH_HOST)
	@echo "Indexing"
	docker-compose exec php-fpm wp elasticpress index --setup --yes --url=www.planet4.test
	$(MAKE) flush

elastic-stop:
	echo "Stopping ElasticSearch"
	docker-compose -f docker-compose.full.yml stop elasticsearch
	docker-compose exec php-fpm wp option update ep_host ''
# ============================================================================

# CONTINUOUS INTEGRATION TASKS

.PHONY: ci
ci: export COMPOSE_FILE := docker-compose.ci.yml
ci:
ifndef APP_IMAGE
	$(error APP_IMAGE is not set)
endif
ifndef OPENRESTY_IMAGE
	$(error OPENRESTY_IMAGE is not set)
endif
	@$(MAKE) lint-in-ci run config ci-copyimages elastic flush test-install

db/Dockerfile: check-envsubst
	envsubst < $@.in > $@

.PHONY: ci-%
ci-%: export COMPOSE_FILE := docker-compose.ci.yml

artifacts/codeception:
	@mkdir -p $@

artifacts/pa11y:
	@mkdir -p $@

.PHONY: ci-extract-artifacts
ci-extract-artifacts: artifacts/codeception
	docker cp $(shell docker-compose ps -q php-fpm):/app/source/tests/_output/. artifacts/codeception;
	@echo Extracted artifacts into $^

.PHONY: ci-extract-a11y-artifacts
ci-extract-a11y-artifacts: artifacts/pa11y
	docker cp $(shell docker-compose ps -q php-fpm):/app/source/pa11y/. artifacts/pa11y;
	@echo Extracted artifacts into $^

.PHONY: ci-copyimages
ci-copyimages: $(LOCAL_IMAGES)
	$(eval TMPDIR := $(shell mktemp -d))
	mkdir -p "$(TMPDIR)/images"
	@unzip -q $(LOCAL_IMAGES) -d "$(TMPDIR)/images"
	@docker cp "$(TMPDIR)/images/." $(shell docker-compose ps -q php-fpm):/app/source/public/wp-content/uploads
	@docker cp "$(TMPDIR)/images/." $(shell docker-compose ps -q openresty):/app/source/public/wp-content/uploads
	@echo "Copied images into php-fpm+openresty:/app/source/public/wp-content/uploads"
	@rm -fr "$TMPDIR"

# ============================================================================

# CODECEPTION TASKS

selenium-run:
	echo "Starting Selenium"
	@docker-compose -f docker-compose.full.yml up -d selenium

## Run tests with Codeception
test: test-env-info test-codeception

## Install Codeception dependencies
test-install: install-codeception install-pcov

# php-pcov allows for zero overhead analysis. Codeception will automatically use it as coverage driver if it's present.
.PHONY: install-pcov
install-pcov:
	docker-compose exec php-fpm sh -c 'apt-get update && apt-get install -yq php$${PHP_MAJOR_VERSION}-pcov'
	docker cp dev-templates/pcov.ini $(shell docker-compose ps -q php-fpm):/tmp/20-pcov.ini
	docker-compose exec php-fpm sh -c 'cp /tmp/20-pcov.ini /etc/php/$${PHP_MAJOR_VERSION}/fpm/conf.d/20-pcov.ini'
	docker-compose exec php-fpm sh -c 'mv /tmp/20-pcov.ini /etc/php/$${PHP_MAJOR_VERSION}/cli/conf.d/20-pcov.ini'
	docker-compose exec php-fpm sh -c 'service php$${PHP_MAJOR_VERSION}-fpm reload'

.PHONY: install-codeception
install-codeception:
	@docker-compose exec php-fpm bash -c 'cd tests && composer install --prefer-dist --no-progress'
	@$(MAKE) probe-wp-index

# Replace WP's index.php file with a version that includes c3.php at the start, which codeception uses to collect coverage.
.PHONY: probe-wp-index
probe-wp-index:
	docker cp dev-templates/probed_index.php $(shell docker-compose ps -q php-fpm):/app/source/public/index.php

.PHONY: test-codeception-unit
test-codeception-unit:
	@docker-compose exec php-fpm tests/vendor/bin/codecept run wpunit --no-redirect --xml=junit.xml --html --debug --coverage --coverage-html coverage_unit

# Run the acceptance test suite with coverage.
# The confusingly named `--no-redirect` option is because of https://github.com/Codeception/Codeception/pull/5498 .
.PHONY: test-codeception-acceptance
test-codeception-acceptance:
	@docker-compose exec php-fpm rsync -a --delete public/wp-content/themes/planet4-master-theme/tests/acceptance/ public/wp-content/plugins/planet4-plugin-gutenberg-blocks/tests/acceptance/ tests/acceptance/
	@docker-compose exec php-fpm rsync -a --delete public/wp-content/themes/planet4-master-theme/tests/data/ tests/_data/
	@docker-compose exec php-fpm tests/vendor/bin/codecept run acceptance --no-redirect --xml=junit.xml --html --coverage --coverage-html coverage_acceptance

.PHONY: test-codeception
test-codeception: test-codeception-acceptance

.PHONY: test-codeception-failed
test-codeception-failed:
	@docker-compose exec php-fpm tests/vendor/bin/codecept run -g failed --xml=junit.xml --html

.PHONY: test-env-info
test-env-info:
	@docker-compose exec php-fpm sh -c 'echo "Wp core information" && wp core version --extra'
	@docker-compose exec php-fpm sh -c 'echo "Themes" && wp theme list'
	@docker-compose exec php-fpm sh -c 'echo "Plugins" && wp plugin list'
	@docker-compose exec php-fpm sh -c 'echo "Greenpeace Packages" && wp option get greenpeace_packages --format=yaml'

# ============================================================================

# PA11Y TASKS

PA11Y_DIR = /app/source/pa11y
PA11Y_CONF = $(PA11Y_DIR)/.pa11yci
PA11Y_LOCAL_CONF ?= $(PA11Y_DIR)/.pa11yci.local
PA11Y_REPORT_JSON = $(PA11Y_DIR)/pa11y-ci-results.json
CHROME_BIN=/usr/bin/chromium-browser

## Run accessibility tests
.PHONY: test-pa11y
test-pa11y:
	docker-compose exec -e CHROME_BIN="${CHROME_BIN}" node sh -c \
		"cd /app/source && ./node_modules/pa11y-ci/bin/pa11y-ci.js -c $(PA11Y_LOCAL_CONF)"

.PHONY: test-pa11y-ci
test-pa11y-ci: install-pa11y
	docker-compose exec node sh -c \
		"./node_modules/pa11y-ci/bin/pa11y-ci.js -c $(PA11Y_CONF) -j -T 1000 > $(PA11Y_REPORT_JSON)"
	docker-compose exec node sh -c \
		"./node_modules/pa11y-ci-reporter-html/bin/pa11y-ci-reporter-html.js -s $(PA11Y_REPORT_JSON) -d $(PA11Y_DIR)"

## Install accessibility tests
.PHONY: install-pa11y
install-pa11y: install-puppeteer-deps
	docker-compose exec -e CHROME_BIN="${CHROME_BIN}" node sh -c \
		"cd /app/source && npm install pa11y-ci pa11y-ci-reporter-html"

# Install local chromium bin
install-puppeteer-deps:
	docker-compose exec node apk add udev ttf-freefont chromium

# ============================================================================

# KITCHEN SINK

.PHONY : pull
pull: envcheck $(CONTENT_PATH)
	docker-compose pull

persistence/app:
	mkdir -p persistence/app

.PHONY: appdata
appdata: persistence/app
	docker cp $(shell docker create $(APP_IMAGE) | tee .tmp-id):/app/source persistence
	docker rm -v $(shell cat .tmp-id)
	rm -fr persistence/app
	mv persistence/source persistence/app


.PHONY : stateless
stateless: clean getdefaultcontent start-stateless config config-stateless status

.PHONY: start-stateless
start-stateless:
	COMPOSE_FILE=docker-compose.stateless.yml \
	./go.sh
	./wait.sh

# ============================================================================

# LOCAL DEV RELEASE

.PHONY: create-dev-export dev-from-release update-from-release main-repos-editable

$(LOCAL_DEVRELEASE):
	@echo "Downloading dev release to $(LOCAL_DEVRELEASE) ..."
	curl --fail $(CONTENT_BASE)/$$(basename $(LOCAL_DEVRELEASE)) > $@

## Creates an exportable tar from local source
create-dev-export:
	@tar --exclude='$(UPLOADS_PATH)' \
		--exclude='node_modules' \
		--exclude='persistence/app/public/wp-config.php' \
		-zcf $(SOURCE_DEVRELEASE) persistence
	echo $(SOURCE_DEVRELEASE)

## Creates a local instance from a pre-built source
dev-from-release: $(LOCAL_DEVRELEASE) hosts
	@tar -xf $(LOCAL_DEVRELEASE)
	$(MAKE) fix-wflogs-permissions
	$(MAKE) unzipimages
	$(MAKE) secrets
	$(MAKE) run
	$(MAKE) fix-node-permissions
	$(MAKE) fix-app-permissions
	$(MAKE) config
	$(MAKE) status

update-from-release: $(LOCAL_DEVRELEASE)
	@tar -xf $(LOCAL_DEVRELEASE)
	$(MAKE) fix-wflogs-permissions

# ============================================================================

# POST INSTALL AND CONFIGURATION TASKS

.PHONY: config
config: check-services
	@echo "Configuring instance ..."
	docker-compose exec -T php-fpm wp option update rt_wp_nginx_helper_options '$(NGINX_HELPER_JSON)' --format=json
	docker-compose exec -T php-fpm wp rewrite structure $(REWRITE)
	docker-compose exec php-fpm wp option patch insert planet4_options cookies_field "Planet4 Cookie Text"
	$(MAKE) admin-user
	docker-compose exec php-fpm wp plugin deactivate wp-stateless
	if [[ -z "${ELASTIC_ENABLED}" ]]; then \
		docker-compose exec php-fpm wp option update ep_host ''
	else \
		docker-compose exec php-fpm wp option update ep_host $(ELASTICSEARCH_HOST)
	fi
	$(MAKE) flush

.PHONY: config-stateless
config-stateless:
	@docker-compose exec php-fpm wp plugin activate wp-stateless

.PHONY : wpadmin
wpadmin:
	@docker-compose exec -T php-fpm wp user create ${WP_USER} ${WP_USER_EMAIL} --role=administrator

.PHONY : check-services
check-services:
	@$(eval SERVICES := $(shell docker-compose ps --services))
	@$(eval TRAEFIK_ENABLED := $(shell echo ${SERVICES} | grep traefik))
	@$(eval ELASTIC_ENABLED := $(shell echo ${SERVICES} | grep elasticsearch))
	@$(eval ELASTICHQ_ENABLED := $(shell echo ${SERVICES} | grep elastichq))
	@$(eval PHPMYADMIN_ENABLED := $(shell echo ${SERVICES} | grep phpmyadmin))

.PHONY: credentials
credentials:
	@printf "\n"
	@printf " %-11s | %-9s | %-17s \n" "" User Password
	@printf "%0.s-" {1..47} && printf "\n"
	@printf " %-11s | %-9s | %-17s \n" Wordpress $(WP_ADMIN_USER) $(WP_ADMIN_PASS)
	@printf "%0.s-" {1..47} && printf "\n"
	@printf " %-11s | %-9s | %-17s \n" Database $(MYSQL_USER) $(MYSQL_PASS)
	@printf " %-11s | %-9s | %-17s \n" "" root $(ROOT_PASS)
	@printf "\n"

.PHONY: links
links: check-services
	@printf " %-10s - %-21s\n" Frontend http://www.planet4.test
	@printf " %-10s - %-21s\n" Backend http://www.planet4.test/admin
	@if [[ "${ELASTICHQ_ENABLED}" != "" ]]; then \
		printf " %-10s - %-21s\n" ElasticHQ http://localhost:5000; \
	fi
	@if [ "${PHPMYADMIN_ENABLED}" != "" ]; then \
		printf " %-10s - %-21s\n" phpMyAdmin http://pma.www.planet4.test/; \
	fi
	@if [ "${TRAEFIK_ENABLED}" != "" ]; then \
		printf " %-10s - %-21s\n" Traefik http://localhost:8080/; \
	fi

## Display containers statuses and docker-compose env
.PHONY: status
status:
	@printf "\n*** .env file ***\n\n"
	@cat .env
	@printf "\n*** Docker compose status ***\n\n"
	@docker-compose ps
	@printf "\n*** Credentials ***\n"
	@$(MAKE) credentials
	@printf "*** Links ***\n\n"
	@$(MAKE) links
	@echo

.PHONY: flush
flush:
	@echo "Clearing all cache ..."
	docker-compose exec redis redis-cli flushdb
	docker-compose exec php-fpm wp timber clear_cache &>/dev/null
	docker-compose exec php-fpm wp cache flush

## Enter a shell in the php-fpm container
.PHONY: php-shell mysql-console
php-shell:
	@docker-compose exec php-fpm bash

## Enter mysql console on the current database
mysql-console:
	docker-compose exec db mysql -u${MYSQL_USER} -p${MYSQL_PASS} -D $(shell docker-compose exec php-fpm wp config get DB_NAME)
## Build master-theme and gutenberg-blocks assets
.PHONY: assets
assets:
	./scripts/build-assets.sh

## Watch and rebuild plugin and theme assets on modification
.PHONY: watch
watch:
	./scripts/watch.sh

# Watch and rebuild theme assets on modification
.PHONY: watch-theme
watch-theme:
	./scripts/watch.sh --theme-only

# Watch and rebuild plugin assets on modification
.PHONY: watch-plugin
watch-plugin:
	./scripts/watch.sh --plugin-only

.PHONY: revertdb
revertdb:
	$(eval include .env)
	@docker stop $(shell docker-compose ps -q db)
	@docker rm $(shell docker-compose ps -q db)
	@docker volume rm $(COMPOSE_PROJECT_NAME)_db
	@docker-compose up -d

.PHONY: use-db-default
use-db-default:
	@$(eval include db.env)
	$(MAKE) use-db-$(MYSQL_DATABASE)

.ONESHELL:
.PHONY: use-db-%
use-db-%: DB_NAME=$*
use-db-%:
	echo "Switching database to $(DB_NAME)"
	docker-compose exec php-fpm wp config set DB_NAME $(DB_NAME)
	$(MAKE) flush


# ============================================================================

# NRO DEVELOPMENT

.PHONY: check-nro-config nro-from-release nro-import-db nro-drop-db nro-enable nro-disable nro-list-variables
.PHONY: nro-enable-img-proxy nro-disable-img-proxy

## NRO name
NRO_NAME ?=
## NRO theme git repository
NRO_REPO ?= https://github.com/greenpeace/planet4-$(NRO_NAME).git
## NRO theme branch
NRO_BRANCH ?= main
## NRO theme name
NRO_THEME ?= planet4-child-theme-$(NRO_NAME)

NRO_DIRNAME := planet4-$(NRO_NAME)
NRO_APP_HOSTNAME ?= www.planet4.test
NRO_APP_HOSTPATH ?=
NRO_IMG_BUCKET ?= planet4-$(NRO_NAME)-stateless

NRO_DATABASE ?= $(shell echo "planet4_${NRO_NAME}" | sed 's/-/_/g')
NRO_DB_PROJECT ?= planet-4-151612
NRO_DB_BUCKET ?= planet4-$(NRO_NAME)-master-db-backup
NRO_DB_VERSION ?=
NRO_DB_DUMP ?=
NRO_DB_IMPORT := $(shell if [[ ! -z "$(NRO_DB_VERSION)" ]] || [[ ! -z "$(NRO_DB_DUMP)" ]]; then echo "true"; else echo ""; fi)

# Install a dev instance from a tar file and activates an NRO on it
# Fix permissions on /app folder for wp commands and macos glitches
## Install NRO instance (uses NRO_NAME)
nro-from-release: dev-from-release
	@$(MAKE) nro-enable

## Enable NRO theme (uses NRO_NAME)
nro-enable: check-nro-config
	@echo "Activating NRO $(NRO_NAME) ..."
	$(if $(NRO_DB_IMPORT), $(MAKE) nro-import-db && $(MAKE) use-db-$(NRO_DATABASE))
	docker-compose exec -u "${APP_USER}" php-fpm sh -c " \
		mkdir -p sites && \
		(cd sites && (test -d $(NRO_DIRNAME) || git clone $(NRO_REPO) $(NRO_DIRNAME))) && \
		(cd "sites/$(NRO_DIRNAME)" && git checkout $(NRO_BRANCH)) && \
		composer config extra.merge-plugin.require "sites/$(NRO_DIRNAME)/composer-local.json" && \
		composer update && \
		composer run-script copy:themes && \
		composer run-script copy:plugins && \
		composer run-script plugin:activate  && \
		composer run-script theme:activate $(NRO_THEME) &&
		composer run-script site:custom \
	"
	$(MAKE) config
	$(if $(NRO_IMG_BUCKET), $(MAKE) nro-enable-img-proxy)
	$(MAKE) flush
	$(MAKE) status

## Disable NRO theme
nro-disable:
	@$(MAKE) nro-disable-img-proxy
	$(MAKE) use-db-default
	docker-compose exec php-fpm sh -c " \
	wp plugin deactivate --all && wp plugin delete --all"
	docker-compose exec -u "${APP_USER}" php-fpm sh -c " \
		composer config extra.merge-plugin.require "composer-local.json" && \
		composer update && \
		composer run-script copy:themes && \
		composer run-script copy:plugins && \
		composer run-script plugin:activate  && \
		composer run-script theme:activate planet4-master-theme"
	$(MAKE) repos && $(MAKE) deps
	$(MAKE) flush

# NRO database operations

MYSQL_AS_ROOT := mysql -uroot -p$(ROOT_PASS)

## Import a backup database
nro-import-db:
	@echo "Importing database to $(NRO_DATABASE)"
	./scripts/import-db.sh \
		--nro "${NRO_NAME}" \
		--project "${NRO_DB_PROJECT}" \
		--bucket "${NRO_DB_BUCKET}" \
		--database "${NRO_DATABASE}" \
		--version "${NRO_DB_VERSION}" \
		--dump "${NRO_DB_DUMP}" \
		--mysql-user "${MYSQL_USER}" \
		--mysql-root-pass "${ROOT_PASS}" \
		--dest "$(CONTENT_PATH)"

nro-drop-db:
	@echo "Dropping database $(NRO_DATABASE)"
	docker-compose exec db $(MYSQL_AS_ROOT) -e 'drop database $(NRO_DATABASE)'

# Nginx image proxy

nro-enable-img-proxy:
	@echo "Enabling image proxy to $(NRO_IMG_BUCKET) bucket ..."
	$(eval export NRO_IMG_BUCKET=$(NRO_IMG_BUCKET))
	envsubst '$$NRO_IMG_BUCKET' < dev-templates/nginx_imgproxy.tmpl > dev-templates/nginx_imgproxy.out
	docker cp dev-templates/nginx_imgproxy.out \
		$(shell docker-compose ps -q openresty):/etc/nginx/server.d/20_img-proxy.conf
	docker-compose exec openresty nginx -s reload

nro-disable-img-proxy:
	@docker-compose exec openresty sh -c 'rm -f /etc/nginx/server.d/20_img-proxy.conf && nginx -s reload'
	echo "Image proxy disabled."

check-nro-config:
ifeq ($(strip $(NRO_NAME)),)
	@echo "You need to specify some variables before you can use this!"
	echo
	echo "Create/edit a file called Makefile.include, then add:"
	echo
	echo "NRO_NAME := <put the name of your NRO here, ie: netherlands>"
	echo
	echo "Other values will be generated from this one. Optionally, you can specify:"
	echo "NRO_DB_DUMP := <a gzipped dump of a database to import>"
	echo "NRO_REPO := <put the Git URL for the NRO repo here>"
	echo "NRO_THEME := <put the theme name for the NRO here>"
	echo "NRO_BRANCH := <the branch you want, default is main>"
	echo
	exit 1
else
	@$(MAKE) nro-list-variables
endif

nro-list-variables:
	$(info NRO variables:)
	$(foreach v,                     \
		$(filter NRO_%,$(sort $(.VARIABLES))), \
		$(info * $(v) = $($(v))))

.PHONY: nro-test-codeception
nro-test-codeception:
	@docker-compose run \
		-e APP_HOSTNAME=$(NRO_APP_HOSTNAME) \
		-e APP_HOSTPATH=$(NRO_APP_HOSTPATH) \
		--user $(id -u):$(id -g) --rm --no-deps \
		codeception sh -c '\
			cd sites/$(NRO_DIRNAME) && \
			codeceptionify.sh . && \
			codecept run --xml=junit.xml --html \
		'

.PHONY: check-gsutil
check-gsutil:
ifndef GSUTIL
	$(error Command: 'gsutil' not found, please check <https://cloud.google.com/storage/docs/gsutil_install>)
endif

# ============================================================================

# HELP SECTION

## Display this help message
.PHONY: help
help:
	@printf "    ____  __                 __     __ __     \n"
	@printf "   / __ \\/ /___ _____  ___  / /_   / // /    Contribute on Github!\n"
	@printf "  / /_/ / / __ \`/ __ \\/ _ \\/ __/  / // /_      https://github.com/greenpeace/planet4\n"
	@printf " / ____/ / /_/ / / / /  __/ /_   /__  __/    Read about what we do in the Handbook!\n"
	@printf "/_/   /_/\\__,_/_/ /_/\\___/\\__/     /_/         https://planet4.greenpeace.org/create/contribute/\n"

	@printf "\nUsage:\n"
	@printf "  [variables] make <target>\n"

	@printf "\nAvailable variables:\n"
	@awk '/^(export )?([A-Z\-_0-9]+) ?\?= ?(.*)/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			isExport = substr($$1, 0, 6) == "export"; \
			helpVar = isExport ? $$2 : $$1; \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			$$1=$$2=""; \
			if (isExport) { $$3 = ""; } \
			sub(/^[\\t ]+/, "", $$0); \
			printf "  %-26s %-32s [%s]\n", helpVar, helpMessage, $$0; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST) | sort

	@printf "\nAvailable targets:\n"
	@awk '/^(.PHONY: ?.*)|^([a-zA-Z\-_0-9]+:)/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")) == ".PHONY:" ? $$2 : substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  %-19s %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST) | sort

	@printf "\n"
	@if [ ! -f "Makefile.include" ]; then \
		printf ">> Overwrite variables and add targets by editing file \`Makefile.include\` <<\n";\
	fi
	@if [ ! -d "./persistence/app" ]; then \
		printf ">> Is it your first start? Build everything with \`make dev\` <<\n";\
	fi
	@printf ">> Documentation: https://support.greenpeace.org/planet4/ <<\n"
	@printf "\n"
