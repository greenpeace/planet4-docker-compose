# Advanced Topics

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

```bash
make revertdb
# ... wait for a bit ...
make config flush
```

### Clear caches

To completely clear redis of the full page cache, as well as object and transient caches:

`make flush`

Alternatively, to only clear the object cache: Login to Wordpress admin and click on *Flush Object Cache* on the Dashboard page. To only clear the full page cache: click *Purge Cache* from the top menu.

## NRO sites

You can also use this setup to work on an NRO site.

**First, create/edit `Makefile.include`** to contain:

```bash
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

## Configuration

### Configuring WP-Stateless GCS bucket storage

If you want to use the Google Cloud Storage you'll have to configure [WP-Stateless](https://github.com/wpCloud/wp-stateless/). The plugin is installed and activated, however images will be stored locally until remote GCS storage is enabled in the administrator backend. [Log in](http://www.planet4.test/wp-login.php) with details gathered [from here](#login) and navigate to [Media > Stateless Setup](http://www.planet4.test/wp-admin/upload.php?page=stateless-setup).

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

The Wordpress plugin [nginx-helper](https://wordpress.org/plugins/nginx-helper/) is installed to enable FastCGI cache purges. Log in to the backend as above, navigate to [Settings > Nginx Helper](http://www.planet4.test/wp-admin/options-general.php?page=nginx) and click:

*   Enable Purge
*   Redis Cache
*   Enter `redis` in the Hostname field
*   Tick all checkboxes under 'Purging Conditions'

### Configuring ElasticSearch indexing

The Elasticsearch host is configured during initial build. But if you want to confirm that the setting is right, navigate to [Settings > ElasticPress > Settings](http://www.planet4.test/wp-admin/admin.php?page=elasticpress-settings). The Host should be: `http://elasticsearch:9200`.

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

The first number is the port number on your host, the second number is mapped to port 80 on the openresty service container.  Now you can access the site at  [www.planet4.test:8000](http://www.planet4.test:8000) instead.

A more robust solution for hosting multiple services on port 80 is to use a reverse proxy  such as Traefik or [jwilder/openresty-proxy](https://github.com/jwilder/openresty-proxy) in a separate project, and use [Docker named networking](https://docs.docker.com/compose/networking/) features to isolate virtual networks.

### Traefik administration interface

Traefik comes with a simple admin interface accessible at [www.planet4.test:8080](http://www.planet4.test:8080).

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
