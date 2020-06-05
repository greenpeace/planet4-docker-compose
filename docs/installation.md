---
description: Get a full Planet 4 development environment to your local machine
---

# Installation

{% hint style="warning" %}
✏️ If you want to improve this document, make a Pull Request to the [docker-compose](https://github.com/greenpeace/planet4-docker-compose) repository and edit the [relevant file](https://github.com/greenpeace/planet4-docker-compose/blob/master/docs/installation.md).
{% endhint %}

We are using `docker` and `docker-compose` to provide as consistent a local development environment as possible, in accordance with [12factor](https://12factor.net/) development principles.

## System Requirements

{% hint style="info" %}
💻 This repository has been tested and is working well on Linux and OSX. It should work on Windows WSL (Windows Subsystem for Linux), but not thoroughly tested.
{% endhint %}

Firstly, check you have all the requirements on your system.\
For Linux users, these are either preinstalled or available through your distribution's package manager.

- [git](https://www.git-scm.com/downloads)
- [make](https://www.gnu.org/software/make/) - Instructions for installing make vary, for OSX users `xcode-select --install` might work
- [docker](https://docs.docker.com/engine/installation/)
- [docker-compose](https://github.com/docker/compose/releases) - This should be installed along with docker on OSX and Windows
- [envsubst](https://stackoverflow.com/questions/23620827/envsubst-command-not-found-on-mac-os-x-10-8/23622446#23622446) - This should be pre-installed on most Linux distributions

## First run

The first time you'll need to follow the steps below, in order to clone this repo and build the containers.

```bash
# Clone the repository
git clone https://github.com/greenpeace/planet4-docker-compose

# Navigate to new directory
cd planet4-docker-compose

# Build containers, start and configure the application
make dev
```

If you want the application repositories to be cloned using ssh protocol, instead of https, you can use a variable:

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

When the terminal is finished, and you see the line 'ready', navigate to [www.planet4.test](http://www.planet4.test).

It's not necessary to re-run `make dev` each time you wish to start the local development environment. To start containers on subsequent runs, use:

```bash
make run
```

### Lightweight configuration

If the current setup is too heavy for your machine, there is a lighter version that skips creating some of the containers. Keep in mind though that this leaves out PhpMyAdmin, ElasticHQ and Selenium containers, so it would be harder to debug things.

To use it, you need to set the relevant environmental variable. For instance:

```bash
DOCKER_COMPOSE_FILE="docker-compose.light.yml" make run
```

## Troubleshooting

To view the output of running containers:

```bash
eval $(make env)
docker-compose logs
```

If at any point the install process fails, with Composer showing a message such as `file could not be downloaded (HTTP/1.1 404 Not Found)`, this is a transient network error and re-running the install should fix the issue.

## Stop

To stop all the containers just run:

```bash
make stop
```

## Updating

To update all containers, run:

```bash
make run
```

## Editing source code

By default, the Wordpress application is bind-mounted at:

`./persistence/app/`

All planet4 code will be under the Wordpress' content folder:

`./persistence/app/public/wp-content/`

## Logging in

### Administrator login

Backend administrator login is available at [www.planet4.test/wp-admin/](http://www.planet4.test/wp-admin/).

Login username is `admin` and the password is `admin`.

### Database access via phpMyAdmin

[phpmyadmin](https://hub.docker.com/r/phpmyadmin/phpmyadmin/) login: [pma.www.planet4.test](http://pma.www.planet4.test)

### Elasticsearch access via ElasticHQ

[elastichq](https://hub.docker.com/r/elastichq/elasticsearch-hq/) Access at [localhost:5000/](http://localhost:5000/)
