SHELL := /bin/bash

DEFAULTCONTENT_DB_VERSION ?= 0.1.28
DEFAULTCONTENT_IMAGE_VERSION ?= 1-25

SCALE_OPENRESTY ?=1
SCALE_APP ?=1

DOCKER_COMPOSE_FILE ?= docker-compose.yml

MYSQL_USER := $(shell grep MYSQL_USER db.env | cut -d'=' -f2)
MYSQL_PASS := $(shell grep MYSQL_PASSWORD db.env | cut -d'=' -f2)
ROOT_PASS := $(shell grep MYSQL_ROOT_PASSWORD db.env | cut -d'=' -f2)

WP_USER ?= $(shell whoami)
WP_USER_EMAIL ?= $(shell git config --get user.email)

PROJECT ?= $(shell basename "$(PWD)" | sed 's/[.-]//g')

# These vars are read by docker-compose
# See https://docs.docker.com/compose/reference/envvars/
export COMPOSE_FILE = $(DOCKER_COMPOSE_FILE)
export COMPOSE_PROJECT_NAME=$(PROJECT)
COMPOSE_ENV := COMPOSE_FILE=$(COMPOSE_FILE) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME)

.DEFAULT_GOAL := run

NGINX_HELPER_JSON := $(shell cat options/rt_wp_nginx_helper_options.json)
REWRITE := /%category%/%post_id%/%postname%/

DEFAULTCONTENT_BASE ?= https://storage.googleapis.com/planet4-default-content
DEFAULTCONTENT_DB ?= $(DEFAULTCONTENT_BASE)/planet4-defaultcontent_wordpress-v$(DEFAULTCONTENT_DB_VERSION).sql.gz
DEFAULTCONTENT_IMAGES ?= $(DEFAULTCONTENT_BASE)/planet4-default-content-$(DEFAULTCONTENT_IMAGE_VERSION)-images.zip

.PHONY: env
env:
	@echo export $(COMPOSE_ENV)

defaultcontent:
	@mkdir -p defaultcontent

defaultcontent/db.sql.gz: defaultcontent
	@echo "Downloading default content database from $(DEFAULTCONTENT_DB)"
	@curl --fail $(DEFAULTCONTENT_DB) > $@

defaultcontent/images.zip: defaultcontent
	@echo "Downloading default content images from $(DEFAULTCONTENT_IMAGES)"
	@curl --fail $(DEFAULTCONTENT_IMAGES) > $@

.PHONY: getdefaultcontent
getdefaultcontent: defaultcontent/db.sql.gz defaultcontent/images.zip

.PHONY: cleandefaultcontent
cleandefaultcontent:
	@rm -rf defaultcontent

.PHONY: updatedefaultcontent
updatedefaultcontent: cleandefaultcontent getdefaultcontent

.PHONY: unzipimages
unzipimages:
	@unzip defaultcontent/images.zip -d persistence/app/public/wp-content/uploads

.PHONY: build
build : clean test getdefaultcontent run unzipimages config flush

.PHONY: ci
ci: export DOCKER_COMPOSE_FILE = docker-compose.ci.yml
ci: test getdefaultcontent run config ci-copyimages flush test-codeception

.PHONY: ci-%
ci-%: export DOCKER_COMPOSE_FILE = docker-compose.ci.yml

.PHONY: ci-extract-artifacts
ci-extract-artifacts:
	@mkdir -p /tmp/artifacts
	@docker cp $(shell $(COMPOSE_ENV) docker-compose ps -q php-fpm):/app/source/tests/_output/. /tmp/artifacts
	@echo Extracted artifacts into /tmp/artifacts

.PHONY: ci-copyimages
ci-copyimages: defaultcontent/images.zip
	@rm -rf /tmp/images
	@unzip defaultcontent/images.zip -d /tmp/images
	@docker cp /tmp/images/. $(shell $(COMPOSE_ENV) docker-compose ps -q php-fpm):/app/source/public/wp-content/uploads
	@docker cp /tmp/images/. $(shell $(COMPOSE_ENV) docker-compose ps -q openresty):/app/source/public/wp-content/uploads
	@echo Copied images into php-fpm+openresty:/app/source/public/wp-content/uploads

.PHONY : test
test: test-sh test-yaml test-json

test-sh:
	find . -type f -name '*.sh' -not -path "./persistence/*" | xargs shellcheck

test-yaml:
	find . -type f -name '*.yml' -not -path "./persistence/*" | xargs yamllint

test-json:
	find . -type f -name '*.json' -not -path "./persistence/*" | xargs jq type

.PHONY : clean
clean: cleandefaultcontent
	./clean.sh

.PHONY : update
update:
	./update.sh

.PHONY : pull
pull:
	docker-compose pull

.PHONY : run
run:
	SCALE_APP=$(SCALE_APP) \
	SCALE_OPENRESTY=$(SCALE_OPENRESTY) \
	PROJECT=$(PROJECT) \
	./go.sh
	@echo "Installing Wordpress, please wait..."
	@echo "This may take up to 10 minutes on the first run!"

	PROJECT=$(PROJECT) \
	./wait.sh

.PHONY : watch
watch:
	@echo "Running Planet 4 application script..."
	./watch.sh

.PHONY : stop
stop:
	./stop.sh

.PHONY : stateless
stateless: clean test getdefaultcontent start-stateless config config-stateless

.PHONY: start-stateless
start-stateless:
	DOCKER_COMPOSE_FILE=docker-compose.stateless.yml \
	SCALE_APP=$(SCALE_APP) \
	SCALE_OPENRESTY=$(SCALE_OPENRESTY) \
	PROJECT=$(PROJECT) \
	./go.sh
	PROJECT=$(PROJECT) \
	./wait.sh

.PHONY: config
config:
	docker-compose exec -T php-fpm wp rewrite structure $(REWRITE)
	docker-compose exec -T php-fpm wp option set rt_wp_nginx_helper_options '$(NGINX_HELPER_JSON)' --format=json
	docker-compose exec php-fpm wp option patch insert planet4_options cookies_field "Planet4 Cookie Text"
	docker-compose exec php-fpm wp user update admin --user_pass=admin --role=administrator
	docker-compose exec php-fpm wp plugin deactivate wp-stateless

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
	@printf "User:  admin\n"
	@printf "Pass:  "
	@docker-compose logs php-fpm | grep Admin | cut -d':' -f2 | xargs
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

.PHONY: flush
flush:
	@docker-compose exec redis redis-cli flushdb

.PHONY: php-shell
php-shell:
	@docker-compose run --rm --no-deps php-fpm bash

.PHONY: test-codeception
test-codeception:
	@docker-compose exec php-fpm sh -c 'cd tests && composer install --prefer-dist --no-progress'
	@docker-compose exec php-fpm tests/vendor/bin/codecept run --xml=junit.xml --html

.PHONY: test-codeception-failed
test-codeception-failed:
	@docker-compose exec php-fpm tests/vendor/bin/codecept run -g failed --xml=junit.xml --html


.PHONY: revertdb
revertdb:
	@docker stop $(shell $(COMPOSE_ENV) docker-compose ps -q db)
	@docker rm $(shell $(COMPOSE_ENV) docker-compose ps -q db)
	@docker volume rm $(COMPOSE_PROJECT_NAME)_db
	@docker-compose up -d