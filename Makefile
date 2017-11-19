SCALE_OPENRESTY?=2
SCALE_APP?=3

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
		@docker-compose logs app | grep Admin | cut -d':' -f2 | xargs

.PHONY : pmapass
pmapass:
		@grep MYSQL_PASSWORD db.env | cut -d'=' -f2
