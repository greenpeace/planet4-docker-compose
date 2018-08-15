SHELL := /bin/bash

SCALE_OPENRESTY ?=1
SCALE_APP ?=1

DOCKER_COMPOSE_FILE ?= docker-compose.yml

MYSQL_USER := $(shell grep MYSQL_USER db.env | cut -d'=' -f2)
MYSQL_PASS := $(shell grep MYSQL_PASSWORD db.env | cut -d'=' -f2)
ROOT_PASS := $(shell grep MYSQL_ROOT_PASSWORD db.env | cut -d'=' -f2)

PROJECT ?= $(shell basename $(PWD) | sed s/[\w.-]//g)

.DEFAULT_GOAL := all

NGINX_HELPER_JSON := $(shell cat options/rt_wp_nginx_helper_options.json)

all : clean test run config
.PHONY : all

.PHONY : test
test:

.PHONY : clean
clean:
		docker-compose -p $(PROJECT) -f $(DOCKER_COMPOSE_FILE) down -v
		sudo rm -fr persistence

.PHONY : update
update:
		./update

.PHONY : pull
pull:
		docker-compose -p $(PROJECT) -f $(DOCKER_COMPOSE_FILE) pull

.PHONY : run
run:
		SCALE_APP=$(SCALE_APP) \
		SCALE_OPENRESTY=$(SCALE_OPENRESTY) \
		PROJECT=$(PROJECT) \
		./go
		@echo "Installing Wordpress, please wait..."
		@echo "This may take up to 5 minutes on the first run."

		PROJECT=$(PROJECT) \
		./wait

.PHONY : stateless
stateless: clean test start-stateless config

.PHONY: start-stateless
start-stateless:
		DOCKER_COMPOSE_FILE=docker-compose.stateless.yml \
		SCALE_APP=$(SCALE_APP) \
		SCALE_OPENRESTY=$(SCALE_OPENRESTY) \
		PROJECT=$(PROJECT) \
		./go
		PROJECT=$(PROJECT) \
		./wait

.PHONY: config
config:
		docker-compose -p $(PROJECT) exec -T php-fpm wp option set rt_wp_nginx_helper_options '$(NGINX_HELPER_JSON)' --format=json

.PHONY : pass
pass:
		@make pmapass
		@make wppass

.PHONY : wppass
wppass:
		@printf "Wordpress credentials:\n"
		@printf "User:  admin\n"
		@printf "Pass:  "
		@docker-compose -p $(PROJECT) logs php-fpm | grep Admin | cut -d':' -f2 | xargs
		@printf "\n"

.PHONY : pmapass
pmapass:
		@printf "Database credentials:\n"
		@printf "User:  %s\n" $(MYSQL_USER)
		@printf "Pass:  %s\n----\n" $(MYSQL_PASS)
		@printf "User:  root\n"
		@printf "Pass:  %s\n----\n" $(ROOT_PASS)

.PHONY: flush
flush:
	  docker-compose -p $(PROJECT) exec redis redis-cli flushdb
