
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

```
Note this repository has not yet been tested on windows platforms yet, any feedback will be welcome!
```

### Requirements

First things first, requirements for running this development environment:

*   [install docker](https://docs.docker.com/engine/installation/)

For MacOS and Windows users docker installation already includes docker-compose
GNU/Linux users have to install docker-compose separately:

*   [install docker compose](https://github.com/docker/compose/releases)

### Running the planet4 development environment

Edit your [hosts](https://www.howtogeek.com/howto/27350/beginner-geek-how-to-edit-your-hosts-file/) file to include the line:

```
127.0.0.1  planet4.dev
```

As the test Wordpress install is configured to use `test.planet4.dev`, adding this line ensures media files and navigation between pages works as expected.

Clone the repository and then launch `docker-compose`:

```bash
# Clone the repository
git clone https://github.com/greenpeace/planet4-docker-compose

# Navigate to new directory
cd planet4-docker-compose

# Run the application
docker-compose up
```

The first time this is run on your local environment, the container bootstraps the installation via composer, and after around 30 seconds the nginx and php-fpm services will be ready. When you see the line `Starting nginx service` you can navigate to: [http://test.planet4.dev](http://test.planet4.dev) and edit repository files directly in `./persistence/app/wp-content/plugins` or `./persistence/app/wp-content/themes`

### Database access with phpmyadmin

Browsing to [http://localhost:8080](http://localhost:8080) shows a [phpmyadmin](https://hub.docker.com/r/phpmyadmin/phpmyadmin/) login interface.  Enter the user values from `db.env` to login and view or edit database contents as required.

## Environment variables

This docker environment relies on the mysql official image as well as on the
[planet4-docker](https://github.com/greenpeace/planet4-docker) application image.

Both images provide environment variables which adjust aspects of the runtime configuration.
For this environment to run just database parameters such as hostname, database name,
database users and passwords are required. Initial values for this environment variables
are dummy but are good to go for a development purpose and can be changed via the provided `app.env` and `db.env` files, or directly in the docker-compose.yml file via the  [environment](https://docs.docker.com/compose/compose-file/#environment) configuration
file provided.

### Development mode

*@todo:
Document some useful builtin configuration options available in upstream docker images for debugging, including:
-   XDebug
-   Smarthost email delivery and interception
-   exec function limits*

## Notes

### Updating

To ensure you're running the latest version of the application, both the infrastructure and the application:

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
docker pull gcr.io/planet4-151612/p4-app-gpi && \
docker-compose up
```

### Port 80 conflicts

If you are running any other services on your local device which respond on port 80, you may experience errors attempting to start the environment.  In this case you can opt to change the port number that the service responds by editing the `docker-compose.yml` file port number as below:

```yml
    ports:
      - "8000:80"
```

The first number is the port number on your host, the second number is mapped to port 80 on the nginx service container.  Now you can access the site at  [http://test.planet4.dev:8000](http://test.planet4.dev:8000) instead.

A more robust solution for hosting multiple services on port 80 is to install a reverse proxy such as [jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy) and set the variable `VIRTUAL_HOST=test.planet4.dev` in the environment file `app.env` and any other containers which use this port, and use [Docker named networking](https://docs.docker.com/compose/networking/) features to isolate virtual networks.

To be continued...
