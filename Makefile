# include optional configuration (used for NRO configuration)
-include Makefile.include

SHELL := /bin/bash

CONTENT_DB_VERSION ?= 0.1.53
CONTENT_IMAGE_VERSION ?= 1-25

SCALE_OPENRESTY ?=1
SCALE_APP ?=1

export SCALE_APP
export SCALE_OPENRESTY

APP_HOSTPATH        ?= test
# YAML interprets 'empty' values as 'nil'
ifeq ($(APP_HOSTPATH),<nil>)
# So if APP_HOSTPATH is set, but blank, clean this value
APP_HOSTPATH :=
endif
DOCKER_COMPOSE_FILE ?= docker-compose.yml
DOCKER_COMPOSE_TOOLS_FILE ?= docker-compose.tools.yml

MYSQL_USER := $(shell grep MYSQL_USER db.env | cut -d'=' -f2)
MYSQL_PASS := $(shell grep MYSQL_PASSWORD db.env | cut -d'=' -f2)
ROOT_PASS := $(shell grep MYSQL_ROOT_PASSWORD db.env | cut -d'=' -f2)

WP_ADMIN_USER := admin
WP_ADMIN_PASS := admin

WP_USER ?= $(shell whoami)
WP_USER_EMAIL ?= $(shell git config --get user.email)

ELASTICSEARCH_HOST ?= http://elasticsearch:9200/

PROJECT ?= $(shell basename "$(PWD)" | sed 's/[.-]//g')
export PROJECT

# These vars are read by docker-compose
# See https://docs.docker.com/compose/reference/envvars/
export COMPOSE_FILE = $(DOCKER_COMPOSE_FILE)
export COMPOSE_PROJECT_NAME=$(PROJECT)
COMPOSE_ENV := COMPOSE_FILE=$(COMPOSE_FILE) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME)

NGINX_HELPER_JSON := $(shell cat options/rt_wp_nginx_helper_options.json)
REWRITE := /%category%/%post_id%/%postname%/

# ============================================================================

CONTENT_PATH 		:= defaultcontent
export CONTENT_PATH

CONTENT_BASE 		?= https://storage.googleapis.com/planet4-default-content
CONTENT_DB 			?= planet4-defaultcontent_wordpress-v$(CONTENT_DB_VERSION).sql.gz
CONTENT_IMAGES 	?= planet4-default-content-$(CONTENT_IMAGE_VERSION)-images.zip

export CONTENT_DB

REMOTE_DB				:= $(CONTENT_BASE)/$(CONTENT_DB)
REMOTE_IMAGES		:= $(CONTENT_BASE)/$(CONTENT_IMAGES)

LOCAL_DB				:= $(CONTENT_PATH)/$(CONTENT_DB)
LOCAL_IMAGES		:= $(CONTENT_PATH)/$(CONTENT_IMAGES)

# ============================================================================

# Check necessary commands exist

CIRCLECI := $(shell command -v circleci 2> /dev/null)
DOCKER := $(shell command -v docker 2> /dev/null)
COMPOSER := $(shell command -v composer 2> /dev/null)
JQ := $(shell command -v jq 2> /dev/null)
SHELLCHECK := $(shell command -v shellcheck 2> /dev/null)
YAMLLINT := $(shell command -v yamllint 2> /dev/null)

# ============================================================================

.DEFAULT_GOAL := all

.PHONY: all
all: build run config status

.PHONY: init
init: .git/hooks/pre-commit

.git/hooks/%:
	@chmod 755 .githooks/*
	@find .git/hooks -type l -exec rm {} \;
	@find .githooks -type f -exec ln -sf ../../{} .git/hooks/ \;

# ============================================================================

# SELF TESTS

.PHONY : lint
lint: init
	@$(MAKE) -j lint-docker lint-sh lint-yaml lint-json lint-ci

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

lint-json:
ifndef JQ
	$(error "jq is not installed: https://stedolan.github.io/jq/download/")
endif
	@find . ! -path './persistence/*' -type f -name '*.json' | xargs jq type | grep -q '"object"'

lint-ci:
ifndef CIRCLECI
	$(error "circleci is not installed: https://circleci.com/docs/2.0/local-cli/#installation")
endif
	@circleci config validate >/dev/null

# ============================================================================

ifdef NRO_REPO
# gives us the basename of the repo e.g. "planet4-netherlands"
NRO_DIRNAME := $(shell echo $(NRO_REPO) | sed 's/^.*\///g; s/\.git$$//g')
NRO_BRANCH ?= develop
NRO_APP_HOSTNAME ?= www.planet4.test
NRO_APP_HOSTPATH ?=
endif

.PHONY: env
env:
	@echo export $(COMPOSE_ENV)

# ============================================================================

# CLEAN GENERATED ASSETS

.PHONY : clean
clean:
	./clean.sh

.PHONY : clean-dev
clean-dev:
	rm -fr persistence/app/public/wp-content/themes/planet4-master-theme
	rm -fr persistence/app/public/wp-content/plugins/planet4-plugin-blocks
	rm -fr persistence/app/public/wp-content/plugins/planet4-plugin-engagingnetworks
	rm -fr persistence/app/public/wp-content/plugins/planet4-plugin-medialibrary

# ============================================================================

# DEFAULT CONTENT TASKS

$(CONTENT_PATH):
	mkdir -p $@

$(LOCAL_DB): $(CONTENT_PATH)
	curl --fail $(REMOTE_DB) > $@

$(LOCAL_IMAGES): $(CONTENT_PATH)
	curl --fail $(REMOTE_IMAGES) > $@

.PHONY: getdefaultcontent
getdefaultcontent: $(LOCAL_DB) $(LOCAL_IMAGES)

.PHONY: cleandefaultcontent
cleandefaultcontent:
	@rm -rf $(CONTENT_PATH)


.PHONY: updatedefaultcontent
updatedefaultcontent: cleandefaultcontent getdefaultcontent

.PHONY: unzipimages
unzipimages:
	@unzip $(LOCAL_IMAGES) -d persistence/app/public/wp-content/uploads

# ============================================================================

# BUILD AND RUN: THE MEAT AND POTATOS

.PHONY: build
build : run unzipimages config elastic flush

.PHONY : run
run:
	@$(MAKE) -j init getdefaultcontent db/Dockerfile
	cp ci/scripts/duplicate-db.sh defaultcontent/duplicate-db.sh
	@./go.sh
	@echo "Installing Wordpress, please wait..."
	@echo "This may take up to 10 minutes on the first run!"
	@./wait.sh

# ============================================================================

# DEVELOPER ENVIRONMENT

.PHONY: dev
dev : clean-dev
	@./dev.sh

# ============================================================================

# ELASTICSEARCH

.PHONY: elastic
elastic: elastic-index flush

elastic-index:
	docker-compose exec php-fpm wp elasticpress index --setup --quiet --url=www.planet4.test

# ============================================================================

# CONTINUOUS INTEGRATION TASKS

.PHONY: ci
ci: export DOCKER_COMPOSE_FILE := docker-compose.ci.yml
ci:
ifndef APP_IMAGE
	$(error APP_IMAGE is not set)
endif
ifndef OPENRESTY_IMAGE
	$(error OPENRESTY_IMAGE is not set)
endif
	@$(MAKE) lint run config ci-copyimages elastic flush

db/Dockerfile:
	envsubst < $@.in > $@

.PHONY: ci-%
ci-%: export DOCKER_COMPOSE_FILE := docker-compose.ci.yml

artifacts/codeception:
	@mkdir -p $@

.PHONY: ci-extract-artifacts
ci-extract-artifacts: artifacts/codeception
	@docker cp $(shell $(COMPOSE_ENV) docker-compose ps -q php-fpm):/app/source/tests/_output/. $^
	@echo Extracted artifacts into $^

.PHONY: ci-copyimages
ci-copyimages: $(LOCAL_IMAGES)
	$(eval TMPDIR := $(shell mktemp -d))
	mkdir -p "$(TMPDIR)/images"
	@unzip $(LOCAL_IMAGES) -d "$(TMPDIR)/images"
	@docker cp "$(TMPDIR)/images/." $(shell $(COMPOSE_ENV) docker-compose ps -q php-fpm):/app/source/public/wp-content/uploads
	@docker cp "$(TMPDIR)/images/." $(shell $(COMPOSE_ENV) docker-compose ps -q openresty):/app/source/public/wp-content/uploads
	@echo "Copied images into php-fpm+openresty:/app/source/public/wp-content/uploads"
	@rm -fr "$TMPDIR"

# ============================================================================

# CODECEPTION TASKS

test: install-codeception test-env-info test-codeception

.PHONY: install-codeception
install-codeception:
	@docker-compose exec php-fpm bash -c 'cd tests && composer install --prefer-dist --no-progress'

.PHONY: test-codeception-unit
test-codeception-unit:
	@docker-compose exec php-fpm tests/vendor/bin/codecept run wpunit --xml=junit.xml --html --debug

.PHONY: test-codeception-acceptance
test-codeception-acceptance:
	@docker-compose exec php-fpm tests/vendor/bin/codecept run acceptance --xml=junit.xml --html

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

# ============================================================================

# KITCHEN SINK

.PHONY : pull
pull:
	docker-compose pull

persistence/app:
	mkdir -p persistence/app

.PHONY: appdata
appdata: persistence/app
	docker cp $(shell docker create $(APP_IMAGE) | tee .tmp-id):/app/source persistence
	docker rm -v $(shell cat .tmp-id)
	rm -fr persistence/app
	mv persistence/source persistence/app

.PHONY : watch
watch:
	@echo "Running Planet 4 application script..."
	./watch.sh

.PHONY : stop
stop:
	./stop.sh

.PHONY : stateless
stateless: clean getdefaultcontent start-stateless config config-stateless status

.PHONY: start-stateless
start-stateless:
	DOCKER_COMPOSE_FILE=docker-compose.stateless.yml \
	./go.sh
	./wait.sh

# ============================================================================

# POST INSTALL AND CONFIGURATION TASKS

.PHONY: config
config:
	docker-compose exec -T php-fpm wp option set rt_wp_nginx_helper_options '$(NGINX_HELPER_JSON)' --format=json
	docker-compose exec -T php-fpm wp rewrite structure $(REWRITE)
	docker-compose exec php-fpm wp option patch insert planet4_options cookies_field "Planet4 Cookie Text"
	docker-compose exec php-fpm wp user update $(WP_ADMIN_USER) --user_pass=$(WP_ADMIN_PASS) --role=administrator
	docker-compose exec php-fpm wp plugin deactivate wp-stateless
	docker-compose exec php-fpm wp option update ep_host $(ELASTICSEARCH_HOST)
	$(MAKE) flush

.PHONY: config-stateless
config-stateless:
	@docker-compose exec php-fpm wp plugin activate wp-stateless

.PHONY : pass
pass:
	@make pmapass
	@make wppass

.PHONY : wppass
wppass:
	@printf "Wordpress credentials:\n"
	@printf "User:  %s\n" $(WP_ADMIN_USER)
	@printf "Pass:  %s\n" $(WP_ADMIN_PASS)
	@printf "\n"

.PHONY : pmapass
pmapass:
	@printf "Database credentials:\n"
	@printf "User:  %s\n" $(MYSQL_USER)
	@printf "Pass:  %s\n----\n" $(MYSQL_PASS)
	@printf "User:  root\n"
	@printf "Pass:  %s\n----\n" $(ROOT_PASS)

.PHONY : wpadmin
wpadmin:
	@docker-compose exec -T php-fpm wp user create ${WP_USER} ${WP_USER_EMAIL} --role=administrator

.PHONY: status
status:
	@docker-compose ps
	@echo
	@$(MAKE) pass
	@echo
	@echo " Frontend - http://www.planet4.test"
	@echo " Backend  - http://www.planet4.test/admin"
	@echo
	@echo "Execute the following command to configure your local shell environment"
	@echo
	@$(MAKE) env
	@echo

.PHONY: flush
flush:
	@docker-compose exec redis redis-cli flushdb

.PHONY: php-shell
php-shell:
	@docker-compose exec php-fpm bash

.PHONY: revertdb
revertdb:
	@docker stop $(shell $(COMPOSE_ENV) docker-compose ps -q db)
	@docker rm $(shell $(COMPOSE_ENV) docker-compose ps -q db)
	@docker volume rm $(COMPOSE_PROJECT_NAME)_db
	@docker-compose up -d

.PHONY: nro-enable
nro-enable:
	@[[ ! -z "$(NRO_REPO)" ]] || (\
		echo "You need to specify some variables before you can use this!" && \
		echo && \
		echo "Create/edit a file called Makefile.include, then add:" && \
		echo && \
		echo "NRO_REPO := <put the Git URL for the NRO repo here>" && \
		echo "NRO_THEME := <put the theme name for the NRO here>" && \
		echo "NRO_BRANCH := <optionally, the branch you want, default is develop>" && \
		echo && \
		exit 1 \
	)
	@echo "NRO repo $(NRO_REPO)"
	@echo "NRO theme $(NRO_THEME)"
	@echo "NRO dirname $(NRO_DIRNAME)"
	@docker-compose exec php-fpm sh -c " \
		mkdir -p sites && \
		(cd sites && (test -d $(NRO_DIRNAME) || git clone $(NRO_REPO) $(NRO_DIRNAME))) && \
		(cd "sites/$(NRO_DIRNAME)" && git checkout $(NRO_BRANCH)) && \
		composer config extra.merge-plugin.require "sites/$(NRO_DIRNAME)/composer-local.json" && \
		composer update && \
		composer run-script copy:themes && \
		composer run-script copy:plugins && \
		composer run-script plugin:activate  && \
		composer run-script theme:activate $(NRO_THEME) \
	"
	@make flush

.PHONY: nro-disable
nro-disable:
	@docker-compose exec php-fpm sh -c " \
		composer config extra.merge-plugin.require "composer-local.json" && \
		composer update && \
		composer run-script copy:themes && \
		composer run-script copy:plugins && \
		composer run-script plugin:activate  && \
		composer run-script theme:activate planet4-master-theme \
	"
	@make flush

.PHONY: nro-test-codeception
nro-test-codeception:
	@docker-compose \
		-f $(DOCKER_COMPOSE_FILE) \
		-f $(DOCKER_COMPOSE_TOOLS_FILE) \
		run \
		-e APP_HOSTNAME=$(NRO_APP_HOSTNAME) \
		-e APP_HOSTPATH=$(NRO_APP_HOSTPATH) \
		--user $(id -u):$(id -g) --rm --no-deps \
		codeception sh -c '\
			cd sites/$(NRO_DIRNAME) && \
			codeceptionify.sh . && \
			codecept run --xml=junit.xml --html \
		'
