# Greenpeace Planet4 docker development environment

![Planet4](https://cdn-images-1.medium.com/letterbox/300/36/50/50/1*XcutrEHk0HYv-spjnOej2w.png?source=logoAvatar-ec5f4e3b2e43---fded7925f62)

## What is Planet4?

Planet4 is the NEW Greenpeace web platform

## What is this repository?

This repository contains needed files to set up a docker development environment that consists on:

 * Planet4 nginx+php-fpm container serving [planet4-base](https://github.com/greenpeace/planet4-base)
 * MySQL container as a database engine

## How to set up the docker environment

### Requirements

First things first, requirements for running this development environment:

  * [install docker](https://docs.docker.com/engine/installation/)

For MacOS and Windows users docker installation already includes docker-compose
GNU/Linux users have to install docker-compose separately:

  * [install docker compose](https://docs.docker.com/compose/install/)

### Running planet4 development environment

Recommended setup is to link your code workspace to:

```bash
 $ ln -s your_code_directory planet4-docker-compose/persistence/code
```
Launce docker-compose

```bash
  $ cd planet4-docker-compose
  $ docker-compose up
```

It should work right away. Point your browser to: http://172.18.0.2 and you are all set.

## Environment variables

This docker environment relies on the mysql official image as well as on the
[planet4-docker](https://github.com/greenpeace/planet4-docker) app image (currently under testing)

Both images provide some environment variables to adjust different parameters.
For this environment to run just database parameters such as hostname, database name,
database users and passwords are required. Initial values for this environment variables
are dummy but are good to go for a development purpose and can be changed in the docker-compose.yml
file provided.

MySQL container variables:

  * MYSQL_ROOT_PASSWORD=test
  * MYSQL_DATABASE=planet4
  * MYSQL_USER=develop
  * MYSQL_PASSWORD=test_develop

Planet4 container variables:

  * DBUSER=develop
  * DBPASS=test_develop
  * DBNAME=planet4
  * DBHOST=172.18.0.3

## Notes

For the sake of the easy of use containers are bounded to fixed ip addresses. From the host machine
you can access containers on the following ips and ports

  * mysql container ip: 172.18.0.3 port 3306
  * planet4 container ip: 172.18.0.2 port 80
