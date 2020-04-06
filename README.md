# Greenpeace Planet 4 docker development environment

![Planet4](./planet4.png)

<!-- Run this command to update TOC: doctoc --title '# Table of Contents' README.md -->
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
# Table of Contents

- [Introduction](#introduction)
- [Contents](#contents)
- [Quickstart](#quickstart)
  - [Requirements](#requirements)
  - [Contributor requirements](#contributor-requirements)
  - [First run](#first-run)
  - [Troubleshooting](#troubleshooting)
  - [Stop](#stop)
  - [Updating](#updating)
- [Editing source code](#editing-source-code)
- [Logging in](#logging-in)
  - [Administrator login](#administrator-login)
  - [Database access via phpMyAdmin](#database-access-via-phpmyadmin)
  - [Elasticsearch access via ElasticHQ](#elasticsearch-access-via-elastichq)
- [Production Containers](#production-containers)
- [Default Content](#default-content)
  - [Import default content](#import-default-content)
  - [Clear caches](#clear-caches)
- [Testing](#testing)
- [NRO sites](#nro-sites)
- [Configuration](#configuration)
  - [Configuring WP-Stateless GCS bucket storage](#configuring-wp-stateless-gcs-bucket-storage)
  - [Configuring FastCGI cache purges](#configuring-fastcgi-cache-purges)
  - [Configuring ElasticSearch indexing](#configuring-elasticsearch-indexing)
- [Environment variables](#environment-variables)
  - [Some useful variables](#some-useful-variables)
  - [Development mode](#development-mode)
- [Notes](#notes)
  - [Updating](#updating-1)
  - [Port conflicts](#port-conflicts)
  - [Traefik administration interface](#traefik-administration-interface)
  - [Performance](#performance)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Introduction

Planet 4 is the new Greenpeace web platform. This repository attempts to provide as consistent a local development environment as possible, in accordance with [12factor](https://12factor.net) development principles.

## Contents

This repository contains needed files to set up a docker development environment that consists of:

- [MySQL](https://hub.docker.com/_/mysql/) container as database engine
- [Traefik](https://traefik.io) load balancing ingress controller
- [OpenResty](https://openresty.org) dynamic web platform based on NGINX and Lua
- [php-fpm](https://php-fpm.org/) high performance PHP FastCGI implementation
- [Redis](https://redis.io/) key-value store caching FastCGI, object and session data
- [PHPmyadmin](https://hub.docker.com/r/phpmyadmin/phpmyadmin/) for database administration
- [ElasticHQ](https://hub.docker.com/r/elastichq/elasticsearch-hq/) for monitoring and managing Elasticsearch cluster

By default, the quickstart command `make build` is all you'll need to pull all required images and spin up a load balanced nginx/php/redis/mysql web application with automatic SSL generation in the comfort of your own office.

- Traefik listens on Port 80, load balancing requests to:
- OpenResty reverse proxy server, caching FastCGI requests from
- a PHP-FPM application, all backed by
- Redis key-value store and
- MySQL database server.
- Self-signed SSL certificates, with optional HTTP > HTTPS redirection

## Quickstart

*This repository has been tested and is working on OSX, Linux and Windows WSL (Windows Subsystem for Linux).*

### Requirements

Firstly, check you have all the requirements on your system. For Linux users, these are either preinstalled or available through your distribution's package manager.

- [git](https://www.git-scm.com/downloads)
- [make](https://www.gnu.org/software/make/) - Instructions for installing make vary, for OSX users `xcode-select --install` might work.
- [docker](https://docs.docker.com/engine/installation/)
- [npm](https://www.npmjs.com/)
- [envsubst](https://stackoverflow.com/questions/23620827/envsubst-command-not-found-on-mac-os-x-10-8/23622446#23622446)

For OsX and Windows users docker installation already includes docker-compose.
Linux users have to install docker-compose separately and also check the Post-installation steps:

- [docker-compose](https://github.com/docker/compose/releases)
- [post-installation](https://docs.docker.com/install/linux/linux-postinstall/)

### Contributor requirements

The following tools are required to contribute to this repository

- [shellcheck](https://www.shellcheck.net/)
- [yamllint](http://www.yamllint.com/)

### First run

The first time you'll need to follow the steps below, in order to clone this repo and build the containers.

```bash
# Clone the repository
git clone https://github.com/greenpeace/planet4-docker-compose

# Navigate to new directory
cd planet4-docker-compose

# Build containers, start and configure the application
make dev
```

If you want the aplication repositories to be cloned using ssh protocol, instead of https, you can use a variable:

```bash
GIT_PROTO="ssh" make dev
```

If you want to run docker-compose commands directly:

```bash
# Set your shell environment variables correctly
eval $(make env)

# View status of containers
docker-compose ps

# View log output
docker-compose logs -f
```

On first launch, the container bootstraps the installation with composer then after a few minutes all services will be ready and responding to requests.

When the terminal is finished, and you see the line 'ready', navigate to [https://www.planet4.test](https://www.planet4.test).

It's not necessary to re-run `make dev` each time you wish to start the local development environment. To start containers on subsequent runs, use:

```bash
make run
```

### Troubleshooting

To view the output of running containers:

```bash
eval $(make env)
docker-compose logs
```

If at any point the install process fails, with Composer showing a message such as `file could not be downloaded (HTTP/1.1 404 Not Found)`, this is a transient network error and re-running the install should fix the issue.

### Stop

To stop all the containers just run:

```bash
make stop
```

### Updating

To update all containers, run:

```bash
make run
```

---

## Editing source code

By default, the Wordpress application is bind-mounted at:

`./persistence/app/`

All planet4 code will be under the Wordpress' content folder:

`./persistence/app/public/wp-content/`

---

## Logging in

### Administrator login

Backend administrator login is available at [https://www.planet4.test/wp-admin/](https://www.planet4.test/wp-admin/).

Login username is `admin` and the password is `admin`.

### Database access via phpMyAdmin

[phpmyadmin](https://hub.docker.com/r/phpmyadmin/phpmyadmin/) login: [https://pma.www.planet4.test](https://pma.www.planet4.test)

### Elasticsearch access via ElasticHQ

[elastichq](https://hub.docker.com/r/elastichq/elasticsearch-hq/) Access at [http://localhost:5000/](http://localhost:5000/)

---

## Production Containers

To run production containers locally, it's necessary to define two environment variables and then run `make appdata`. This tells docker-compose which containers to use, and then copies the contents of the `/app/source` directory to the local `persistence` folder.

Example:

```bash
# Change these variables to the container images you wish to run
export APP_IMAGE=gcr.io/planet-4-151612/planet4-flibble-app:develop
export OPENRESTY_IMAGE=gcr.io/planet-4-151612/planet4-flibble-openresty:develop
# Copy contents of container /app/source into local persistence folder
make appdata
# Bring up container suite
make run
```

From here, you can download a database export from GCS (for example: https://console.cloud.google.com/storage/browser/planet4-flibble-db-backup?project=planet-4-151612) and visit [phpMyAdmin](http://pma.www.planet4.test) to perform the import.

## Default Content

### Import default content

The default content is imported automatically for you.

**Troubleshooting**

If you want to revert back to the default content database you can delete the remove the database container and volume and recreate:

```php
make revertdb
# ... wait for a bit ...
make config flush
```

### Clear caches

To completely clear redis of the full page cache, as well as object and transient caches:

`make flush`

Alternatively, to only clear the object cache: Login to Wordpress admin and click on *Flush Object Cache* on the Dashboard page. To only clear the full page cache: click *Purge Cache* from the top menu.

---

## Testing

See [TESTING](TESTING.md) for more info.

---

## NRO sites

You can also use this setup to work on an NRO site.

**First, create/edit `Makefile.include`** to contain:

```
NRO_REPO := https://github.com/greenpeace/planet4-netherlands.git
NRO_THEME := planet4-child-theme-netherlands

# optionally specify a branch, will default to "develop" otherwise
#NRO_BRANCH := my-other-branch

# by default it will test against your local docker-compose setup version
# but you can optionally specify these variables to run the tests against
# a deployed environment
#NRO_APP_HOSTNAME := k8s.p4.greenpeace.org
#NRO_APP_HOSTPATH := nl
```

**Then enable the NRO:**

```
make nro-enable
```

**And, run the tests:**

```
make nro-test-codeception
```

The tests work a bit differently to the main ones, see [TESTING#NRO](TESTING.md#NRO) for more info.

---

## Configuration

### Configuring WP-Stateless GCS bucket storage

If you want to use the Google Cloud Storage you'll have to configure [WP-Stateless](https://github.com/wpCloud/wp-stateless/). The plugin is installed and activated, however images will be stored locally until remote GCS storage is enabled in the administrator backend. [Log in](https://www.planet4.test/wp-login.php) with details gathered [from here](#login) and navigate to [Media > Stateless Setup](https://www.planet4.test/wp-admin/upload.php?page=stateless-setup).

You will need a Google account with access to GCS buckets to continue.

Once logged in:

- Click 'Get Started Now'
- Authenticate
- Choose 'Planet-4' project (or a custom project from your private account)
- Choose or create a Google Cloud Bucket - it's recommended to use a bucket name unique to your own circumstances, eg 'mynamehere-test-planet4-wordpress'
- Choose a region close to your work environment
- Skip creating a billing account (if using Greenpeace Planet 4 project)
- Click continue, and wait a little while for all necessary permissions and object to be created.

Congratulations, you're now serving media files directly from GCS buckets!

### Configuring FastCGI cache purges

The Wordpress plugin [nginx-helper](https://wordpress.org/plugins/nginx-helper/) is installed to enable FastCGI cache purges. Log in to the backend as above, navigate to [Settings > Nginx Helper](https://www.planet4.test/wp-admin/options-general.php?page=nginx) and click:

*   Enable Purge
*   Redis Cache
*   Enter `redis` in the Hostname field
*   Tick all checkboxes under 'Purging Conditions'

### Configuring ElasticSearch indexing

The Elasticsearch host is configured during initial build. But if you want to confirm that the setting is right, navigate to [Settings > ElasticPress > Settings](https://www.planet4.test/wp-admin/admin.php?page=elasticpress-settings). The Host should be: `http://elasticsearch:9200`.

Anytime you want to re-index Elasticsearch you can just run: `make elastic`.

## Environment variables

This docker environment relies on the mysql official image as well as on the [planet4-base-fork](https://github.com/greenpeace/planet4-base-fork) application image.

Both images provide environment variables which adjust aspects of the runtime configuration. For this environment to run only the database parameters such as hostname, database name, database users and passwords are required.

Initial values for this environment variables are dummy but are good to go for development porpoises. They can be changed in the provided `app.env` and `db.env` files, or directly in the [docker-compose.yml](https://docs.docker.com/compose/compose-file/#environment) file itself.

### Some useful variables

See [openresty-php-exim](https://github.com/greenpeace/planet4-docker/tree/develop/source/planet-4-151612/openresty-php-exim)

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

## Notes

### Updating

To ensure you're running the latest version of both the infrastructure and the application you can just build all containers again. **Keep in mind that this deletes the persistence folder and therefor all you local code changes to the application.**

```bash
make build
```

This one simple command will ensure you're always running the latest version of the application and will perform the following:

*   stop the services
*   update the repository
*   delete the `persistence` directory
*   pull a new application image
*   restart docker compose

*Make sure you've pushed any changes you wish to keep first!*

Also, be aware that if you've only recently pushed new code to the repository there may be a delay of up to 30 minutes before the composer registry is updated.  You can always enter the relevant code directory and perform a `git pull` within the appropriate branch to speed things up.

```bash
make clean
make pull
make run
```

### Port conflicts

If you are running any other services on your local device which respond on port 80, you may experience errors attempting to start the environment. Traefik is configured to respond on port 80 in this application, but you can change it by editing the docker-compose.yml file as below:

```yaml
  traefik:
    ports:
      - "8000:80"
```

The first number is the port number on your host, the second number is mapped to port 80 on the openresty service container.  Now you can access the site at  [https://www.planet4.test:8000](https://www.planet4.test:8000) instead.

A more robust solution for hosting multiple services on port 80 is to use a reverse proxy  such as Traefik or [jwilder/openresty-proxy](https://github.com/jwilder/openresty-proxy) in a separate project, and use [Docker named networking](https://docs.docker.com/compose/networking/) features to isolate virtual networks.

### Traefik administration interface

Traefik comes with a simple admin interface accessible at [http://www.planet4.test:8080](http://www.planet4.test:8080).

### Performance

On a 2015 Macbook Pro, with a primed cache, this stack delivers 50 concurrent connections under siege with an average response time of 0.28 seconds and near-zero load on the php-fpm backend.

```bash
$ siege -c 50 -t 20s -b www.planet4.test

Lifting the server siege...
Transactions:		          3374 hits
Availability:		          100.00 %
Elapsed time:		          19.39 secs
Data transferred:	        51.58 MB
Response time:		        0.28 secs
Transaction rate:	        174.01 trans/sec
Throughput:		            2.66 MB/sec
Concurrency:		          49.13
Successful transactions:  3374
Failed transactions:	    0
Longest transaction:	    2.31
Shortest transaction:	    0.00
```

To be continued...


## License

[GPL-3.0](LICENSE)
