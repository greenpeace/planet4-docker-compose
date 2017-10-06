
# Greenpeace Planet4 docker development environment

![Planet4](https://cdn-images-1.medium.com/letterbox/300/36/50/50/1*XcutrEHk0HYv-spjnOej2w.png?source=logoAvatar-ec5f4e3b2e43---fded7925f62)

## What is Planet4?

Planet4 is the NEW Greenpeace web platform

## What is this repository?

This repository contains needed files to set up a docker development environment that consists of:

*   [MySQL](https://hub.docker.com/_/mysql/) container as database engine
*   Combined nginx + php-fpm container serving [planet4-base](https://github.com/greenpeace/planet4-base)
*   [PHPmyadmin](https://hub.docker.com/r/phpmyadmin/phpmyadmin/) container for database administration

## Quickstart

*Note this repository has not yet been tested on Windows, any feedback will be welcome!*

```
# Clone the repository
git clone https://github.com/greenpeace/planet4-docker-compose

# Navigate to new directory
cd planet4-docker-compose

# Mac and Linux only
sudo echo "127.0.0.1  test.planet4.dev planet.dev" >> /etc/hosts

# Windows add the following to: \Windows\System32\drivers\etc\hosts
# 127.0.0.1   test.planet4.dev planet4.dev

# Start the application
docker-compose up
```

On first launch, the container bootstraps the installation with composer then after a short time (30 seconds to 1 minute) the nginx and php-fpm services will be ready.

When you see the line `Starting service: nginx` you can navigate to: [http://test.planet4.dev](http://test.planet4.dev)

### Requirements

Firstly, requirements for running this development environment:

*   [install docker](https://docs.docker.com/engine/installation/)

For MacOS and Windows users docker installation already includes docker-compose
GNU/Linux users have to install docker-compose separately:

*   [install docker compose](https://github.com/docker/compose/releases)

---

## Editing source code

Wordpress plugins and themes directories are bind-mounted at:
-   `./persistence/app/wp-content/plugins`
-   `./persistence/app/wp-content/themes`

### Database access with phpMyAdmin

[phpmyadmin](https://hub.docker.com/r/phpmyadmin/phpmyadmin/) login: [http://localhost:8080](http://localhost:8080)

Enter the user values from `db.env` to login

## Environment variables

This docker environment relies on the mysql official image as well as on the
[planet4-base](https://github.com/greenpeace/planet4-base) application image.

Both images provide environment variables which adjust aspects of the runtime configuration. For this environment to run only the database parameters such as hostname, database name, database users and passwords are required.

Initial values for this environment variables are dummy but are good to go for development porpoises. They can be changed in the provided `app.env` and `db.env` files, or directly in the [docker-compose.yml](https://docs.docker.com/compose/compose-file/#environment) file itself.

### Some useful variables
See [nginx-php-exim](https://github.com/greenpeace/planet4-docker/tree/develop/source/planet-4-151612/nginx-php-exim)

-   `NEWRELIC_LICENSE` set to the license key in your NewRelic dashboard to automatically receive server and application metrics
-   `PHP_MEMORY_LIMIT` maximum memory each PHP process can consume before being termminated and restarted by the scheduler
-   `PHP_XDEBUG_REMOTE_HOST` in development mode enables remote [XDebug](https://xdebug.org/) debugging, tracing and profiling

### Development mode

*@todo:
Document some of the useful builtin configuration options available in upstream docker images for debugging, including:*
-   XDebug remote debugging
-   Smarthost email delivery and interception
-   exec function limits
-   Memory and performance tweaks

---

## Notes

### Updating

To ensure you're running the latest version of both the infrastructure and the application:

*   stop the services
*   update the repository
*   delete the `persistence` directory
*   pull a new application image
*   restart docker compose

*Make sure you've pushed any changes you wish to keep first!*

Also, be aware that if you've only recently pushed new code to the repository there may be a delay of up to 30 minutes before the composer registry is updated.  You can always enter the relevant code directory and perform a `git pull` within the appropriate branch to speed things up.

Copypasta instructions for upgrading the local environment:
```
docker-compose stop
git pull && \
rm -fr ./persistence && \
docker pull gcr.io/planet4-151612/p4-app-gpi:develop && \
docker-compose up
```

### Port 80 conflicts

If you are running any other services on your local device which respond on port 80, you may experience errors attempting to start the environment.  In this case you can opt to change the port number that the service responds by editing the `docker-compose.yml` file port number as below:

```yaml
    ports:
      - "8000:80"
```

The first number is the port number on your host, the second number is mapped to port 80 on the nginx service container.  Now you can access the site at  [http://test.planet4.dev:8000](http://test.planet4.dev:8000) instead.

A more robust solution for hosting multiple services on port 80 is to install a reverse proxy such as [jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy) and set the variable `VIRTUAL_HOST=test.planet4.dev` in the environment file `app.env` and any other containers which use this port, and use [Docker named networking](https://docs.docker.com/compose/networking/) features to isolate virtual networks.

To be continued...
