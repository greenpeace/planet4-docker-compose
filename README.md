# Greenpeace Planet 4 docker development environment

![Planet4](./planet4.png)

Planet 4 is the new Greenpeace web platform. This repository attempts to provide as consistent a local development environment as possible, in accordance with [12factor](https://12factor.net/) development principles.

## Contents

This repository contains needed files to set up a docker development environment that consists of:

- [MySQL](https://hub.docker.com/_/mysql/) container as database engine
- [Traefik](https://traefik.io) load balancing ingress controller
- [OpenResty](https://openresty.org) dynamic web platform based on NGINX and Lua
- [php-fpm](https://php-fpm.org/) high performance PHP FastCGI implementation
- [Redis](https://redis.io/) key-value store caching FastCGI, object and session data
- [PHPmyadmin](https://hub.docker.com/r/phpmyadmin/phpmyadmin/) for database administration
- [Elasticsearch](https://github.com/elastic/elasticsearch) full-text search engine
- [ElasticHQ](https://hub.docker.com/r/elastichq/elasticsearch-hq/) for monitoring and managing Elasticsearch cluster

By default, the quickstart command `make dev` is all you'll need to pull all required images and spin up a load balanced nginx/php/redis/mysql web application with automatic SSL generation in the comfort of your own office.

- Traefik listens on Port 80, load balancing requests to:
- OpenResty reverse proxy server, caching FastCGI requests from
- a PHP-FPM application, all backed by
- Redis key-value store and
- MySQL database server.

This guide is split into the section below:

### 👷 [Installation](docs/installation.md)

Step-by-step guide on how to get the development environment up and running to your local machine.

### 🔧 [Testing](docs/testing.md)

Detailed information on how to run the test suite locally.

### 💪 [Advanced Topics](docs/advanced.md)

Dive into more advanced topics (eg. how to run production containers, configure wp-stateless and elasticsearch, update containers, etc).
