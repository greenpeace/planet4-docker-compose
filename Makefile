SHELL := /bin/bash

SCALE_OPENRESTY?=2
SCALE_APP?=2

APP_ENV?=development

DOCKER_COMPOSE_FILE?=docker-compose.yml

EXIM_ADMIN_EMAIL?=raymond.walker@greenpeace.org
EXIM_SMARTHOST?=smtp.gmail.com::587
EXIM_SMARTHOST_AUTH_USERNAME?=
EXIM_SMARTHOST_AUTH_PASSWORD?=

MYSQL_USER := $(shell grep MYSQL_USER db.env | cut -d'=' -f2)
MYSQL_PASS := $(shell grep MYSQL_PASSWORD db.env | cut -d'=' -f2)
ROOT_PASS := $(shell grep MYSQL_ROOT_PASSWORD db.env | cut -d'=' -f2)

.DEFAULT_GOAL := all

all : test clean run
.PHONY : all

.PHONY : test
test:

.PHONY : clean
clean:
		docker-compose -f $(DOCKER_COMPOSE_FILE) down
		rm -fr persistence

.PHONY : update
update:
		./update

.PHONY : pull
pull:
		docker-compose -f $(DOCKER_COMPOSE_FILE) pull --parallel

.PHONY : run
run:
		EXIM_ADMIN_EMAIL=$(EXIM_ADMIN_EMAIL) \
		EXIM_SMARTHOST_AUTH_PASSWORD=$(EXIM_SMARTHOST_AUTH_PASSWORD) \
		EXIM_SMARTHOST_AUTH_USERNAME=$(EXIM_SMARTHOST_AUTH_USERNAME) \
		EXIM_SMARTHOST=$(EXIM_SMARTHOST) \
		SCALE_APP=$(SCALE_APP) \
		SCALE_OPENRESTY=$(SCALE_OPENRESTY) \
		./go

.PHONY : stateless
stateless:
		DOCKER_COMPOSE_FILE=docker-compose.stateless.yml \
		SCALE_APP=$(SCALE_APP) \
		SCALE_OPENRESTY=$(SCALE_OPENRESTY) \
		./go

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
