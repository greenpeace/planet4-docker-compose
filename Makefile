.DEFAULT_GOAL := all

all : test clean pull run
.PHONY : all

.PHONY : test
test:

.PHONY : clean
clean:
		docker-compose stop && docker-compose rm -f && rm -fr persistence

.PHONY : pull
pull:
		docker-compose pull

.PHONY : run
run:
		docker-compose up -d --scale nginx=2 --scale app=3
