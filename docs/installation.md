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
- [make](https://www.gnu.org/software/make/) - Instructions for installing make vary, for MacOS users `xcode-select --install` might work
- [docker](https://docs.docker.com/engine/installation/)
- [docker-compose](https://github.com/docker/compose/releases) - This should be installed along with docker on OSX and Windows
- [envsubst](https://stackoverflow.com/questions/23620827/envsubst-command-not-found-on-mac-os-x-10-8/23622446#23622446) - This should be pre-installed on most Linux distributions
  - On MacOS, `envsubst` is installed as part of `gettex`. Install like this:

  ```bash
  brew install gettext
  brew link --force gettext
  ```

- [unzip](https://linuxhint.com/unzip_command_-linux/)

The following dependencies are required in order to commit a change:

- [shellcheck](https://github.com/koalaman/shellcheck)
- [yamllint](https://github.com/adrienverge/yamllint)
- [circleci](https://circleci.com/docs/2.0/local-cli/#installation)

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

See [Fixing `make dev` errors](#fixing-make-dev-errors) if you have any issues with this command.

If you want the application repositories to be cloned using ssh protocol, instead of https, you can use a variable:

```bash
GIT_PROTO="ssh" make dev
```

or for a more permanent solution, add to a file `Makefile.include`:

```bash
GIT_PROTO := 'ssh'
```

If you want to run docker-compose commands directly:

```bash
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

### Full environment

In order to keep the environment light, the default setup skips some containers that are useful for debugging and testing.
Namely: PhpMyAdmin, ElasticHQ and Selenium. If you need them, you can use the full environment config by setting an environment variable:

```bash
COMPOSE_FILE="docker-compose.full.yml" make run
```

For a more permanent solution, edit a file `.env` and change the variable there:

```bash
COMPOSE_FILE="docker-compose.full.yml"
```

## Troubleshooting

To view the output of running containers:

```bash
docker-compose logs
```

If at any point the install process fails, with Composer showing a message such as `file could not be downloaded (HTTP/1.1 404 Not Found)`, this is a transient network error and re-running the install should fix the issue.

### Fixing `make dev` errors

Then, when running `make dev`, if you get the following error:

```bash
ERROR: for traefik  Cannot start service traefik: driver failed programming external connectivity on endpoint planet4dockercompose_traefik_1 (f7c7a3eded69b5451a6e2e45d13ab312c2a2e809ce5cd69994119368294ec478): Bind for 0.0.0.0:8080 failed: port is already allocated
ERROR: Encountered errors while bringing up the project.
make[1]: *** [up] Error 1
make: *** [run] Error 2
```

This error means that there is a process that is already registered to use port `8080`. It is most likely a running docker container that is using this port, but to check, run this command:

```bash
lsof -nP -iTCP -sTCP:LISTEN | grep 8080
```

If result will be something like this:

```bash
com.docke  5086 <USERNAME>   84u  IPv6 0xdc100c215fbb6b93      0t0  TCP *:8080 (LISTEN)
```

That's a docker container. (If it is a different process owning the port, you could run `kill -9 <PID>`).

To check which container is using this port you can run:

```bash
$ docker container ls | grep 8080
<CONTAINER_ID>   containers.xxx.com/my-container:1.1          "/entrypoint.sh /usr…"   2 months ago    Up 10 minutes             0.0.0.0:8080->8080/tcp                           my-container_1
```

To stop the container, run:

```bash
docker kill <CONTAINER_ID>
```

Then re-run `make dev` and it should be fine. If it still doesn't work, then [raise an issue](https://github.com/greenpeace/planet4-docker-compose/issues).

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

Other commands are listed under:

```bash
make help
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
