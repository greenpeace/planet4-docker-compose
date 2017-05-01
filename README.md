# Greenpeace Planet4 docker development environment

![Planet4](https://cdn-images-1.medium.com/letterbox/300/36/50/50/1*XcutrEHk0HYv-spjnOej2w.png?source=logoAvatar-ec5f4e3b2e43---fded7925f62)

## What is Planet4?

Planet4 is the NEW Greenpeace web platform

## What is this repository?

This repository contains needed files to set up a docker development environment that consists on:

 * Planet4 php-fpm container serving [planet4-base](https://github.com/greenpeace/planet4-base)
 * MySQL container as a database engine
 * nginx container to proxy requests to php-fpm

## How to set up the docker environment

###WARNING WINDOWS USERS

Note this repository has not yet been tested on windows platforms yet, any feedback will be welcome!

### Requirements

First things first, requirements for running this development environment:

  * [install docker](https://docs.docker.com/engine/installation/)

For MacOS and Windows users docker installation already includes docker-compose
GNU/Linux users have to install docker-compose separately:

  * [install docker compose](https://docs.docker.com/compose/install/)

### Running planet4 development environment

Recommended setup is to clone [planet4-base](https://github.com/greenpeace/planet4-base) and link it to the persistence/code directory of this repo

```bash
 $ ln -s your_path_to_planet4-base planet4-docker-compose/persistence/code

Edit docker-compose.yml to set your host userid and usergid to avoid permissions problems between host and container. On MacOS and GNU/Linux you can obtain this data executing the command `id`.

```bash
  $ id
uid=501(username) gid=20(groupname) groups=20(staff), [...]
```

On this example line 21 of docker-compose.yml should look like:

```
  user: "501:20"
```

Launch docker-compose

```bash
  $ cd planet4-docker-compose
  $ docker-compose up
```

It should work right away. Point your browser to: http://172.18.0.4 (only GNU/Linux platforms) or http://localhost and you are all set.

###Troubleshooting

CSS is not loading!
This is because wordpress needs hostnames to load the proper files. In GNU/Linux and MacOS platforms fix is to edit /etc/hosts and add the following line at the end of the file:

```
127.0.0.1 test.planet4.dev
```

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
  * DBHOST=db

## Notes

For the sake of the easy of use containers are bounded to fixed ip addresses and a custom docker network is created to avoid conflicts with other containers users might be running.

  * mysql container ip: 172.18.0.2 port 3306
  * planet4 container ip: 172.18.0.3 port 9000
  * nginx container ip: 172.18.0.4 port 80
