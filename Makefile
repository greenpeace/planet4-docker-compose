.DEFAULT_GOAL := all

all : test clean run
.PHONY : all

.PHONY : test
test:

.PHONY : clean
clean:
		docker-compose stop && docker-compose rm -f && rm -fr persistence

.PHONY : run
run:
		docker-compose up -d --scale nginx=2 --scale app=3 && docker-compose logs -f
