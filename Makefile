SCALE_OPENRESTY?=2
SCALE_APP?=3

MYSQL_USER := $(shell grep MYSQL_USER db.env | cut -d'=' -f2)
MYSQL_PASS := $(shell grep MYSQL_PASSWORD db.env | cut -d'=' -f2)
ROOT_PASS := $(shell grep MYSQL_ROOT_PASSWORD db.env | cut -d'=' -f2)

.DEFAULT_GOAL := all

all : test clean pull run
.PHONY : all

.PHONY : test
test:

.PHONY : clean
clean:
		docker-compose stop; docker-compose rm -f; rm -fr persistence

.PHONY : pull
pull:
		docker-compose pull

.PHONY : run
run:
		docker-compose up -d --scale openresty=$(SCALE_OPENRESTY) --scale app=$(SCALE_APP)

.PHONY : stateless
stateless:
		docker-compose -f docker-compose.stateless.yml up -d  --scale openresty=$(SCALE_OPENRESTY) --scale app=$(SCALE_APP)

.PHONY : wppass
wppass:
		@echo "admin"
		@docker-compose logs app | grep Admin | cut -d':' -f2 | xargs

.PHONY : pmapass
pmapass:
		@printf "User:  %s\n" $(MYSQL_USER)
		@printf "Pass:  %s\n---\n" $(MYSQL_PASS)
		@printf "User:  root\n"
		@printf "Pass:  %s\n" $(ROOT_PASS)
