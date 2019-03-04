SHELL := /bin/bash

CONTENT_DB_VERSION ?= 0.1.36
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

MYSQL_USER := $(shell grep MYSQL_USER db.env | cut -d'=' -f2)
MYSQL_PASS := $(shell grep MYSQL_PASSWORD db.env | cut -d'=' -f2)
ROOT_PASS := $(shell grep MYSQL_ROOT_PASSWORD db.env | cut -d'=' -f2)

WP_USER ?= $(shell whoami)
WP_USER_EMAIL ?= $(shell git config --get user.email)

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

REMOTE_DB				:= $(CONTENT_BASE)/$(CONTENT_DB)
REMOTE_IMAGES		:= $(CONTENT_BASE)/$(CONTENT_IMAGES)

LOCAL_DB				:= $(CONTENT_PATH)/$(CONTENT_DB)
LOCAL_IMAGES		:= $(CONTENT_PATH)/$(CONTENT_IMAGES)


.PHONY: env
env:
	@echo export $(COMPOSE_ENV)

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

.PHONY: build
build : run unzipimages config flush

.PHONY: dev
dev : clean-dev dev-master-theme dev-plugin-blocks dev-plugin-engagingnetworks dev-plugin-medialibrary

dev-master-theme:
	git clone https://github.com/greenpeace/planet4-master-theme.git persistence/app/public/wp-content/themes/planet4-master-theme

dev-plugin-blocks:
	git clone https://github.com/greenpeace/planet4-plugin-blocks.git persistence/app/public/wp-content/plugins/planet4-plugin-blocks

dev-plugin-engagingnetworks:
	git clone https://github.com/greenpeace/planet4-plugin-engagingnetworks.git persistence/app/public/wp-content/plugins/planet4-plugin-engagingnetworks

dev-plugin-medialibrary:
	git clone https://github.com/greenpeace/planet4-plugin-medialibrary.git persistence/app/public/wp-content/plugins/planet4-plugin-medialibrary

.PHONY: ci
ci: lint run config ci-copyimages flush test-codeception

.PHONY: ci-%
ci-%: export DOCKER_COMPOSE_FILE = docker-compose.ci.yml

.PHONY: ci-extract-artifacts
ci-extract-artifacts:
	@mkdir -p /tmp/artifacts
	@docker cp $(shell $(COMPOSE_ENV) docker-compose ps -q php-fpm):/app/source/tests/_output/. /tmp/artifacts
	@echo Extracted artifacts into /tmp/artifacts

.PHONY: ci-copyimages
ci-copyimages: $(LOCAL_IMAGES)
	@rm -rf /tmp/images
	@unzip $(LOCAL_IMAGES) -d /tmp/images
	@docker cp /tmp/images/. $(shell $(COMPOSE_ENV) docker-compose ps -q php-fpm):/app/source/public/wp-content/uploads
	@docker cp /tmp/images/. $(shell $(COMPOSE_ENV) docker-compose ps -q openresty):/app/source/public/wp-content/uploads
	@echo Copied images into php-fpm+openresty:/app/source/public/wp-content/uploads

.PHONY : lint
lint: lint-sh lint-yaml lint-json

lint-sh:
	find . -type f -name '*.sh' -not -path "./persistence/*" | xargs shellcheck

lint-yaml:
	find . -type f -name '*.yml' -not -path "./persistence/*" | xargs yamllint

lint-json:
	find . -type f -name '*.json' -not -path "./persistence/*" | xargs jq type

.PHONY : clean
clean:
	./clean.sh

.PHONY : clean-dev
clean-dev:
	rm -fr persistence/app/public/wp-content/themes/planet4-master-theme
	rm -fr persistence/app/public/wp-content/plugins/planet4-plugin-blocks
	rm -fr persistence/app/public/wp-content/plugins/planet4-plugin-engagingnetworks
	rm -fr persistence/app/public/wp-content/plugins/planet4-plugin-medialibrary

.PHONY : update
update:
	./update.sh

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

.PHONY : run
run:
	./go.sh
	@echo "Installing Wordpress, please wait..."
	@echo "This may take up to 10 minutes on the first run!"
	./wait.sh

.PHONY : watch
watch:
	@echo "Running Planet 4 application script..."
	./watch.sh

.PHONY : stop
stop:
	./stop.sh

.PHONY : stateless
stateless: clean lint getdefaultcontent start-stateless config config-stateless

.PHONY: start-stateless
start-stateless:
	DOCKER_COMPOSE_FILE=docker-compose.stateless.yml \
	./go.sh
	./wait.sh

.PHONY: config
config:
	docker-compose exec -T php-fpm wp option set rt_wp_nginx_helper_options '$(NGINX_HELPER_JSON)' --format=json
	$(MAKE) flush
	docker-compose exec -T php-fpm wp rewrite structure $(REWRITE)
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

test: test-codeception

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
