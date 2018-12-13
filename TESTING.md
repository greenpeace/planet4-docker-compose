# Testing

We use [codeception](https://codeception.com/) for running end-to-end testing in a full browser environment.

## Running tests

If you docker-compose development environment is already up and running you can run them with:

```
make test-wp
```

If you want to run individual tests it's easiest to get a php shell inside a docker container:

```
make php
```

From there you can run all the tests with:

```
vendor/bin/codecept run
```

... or a single test:

```
vendor/bin/codecept run tests/acceptance/HomePageCept.php
```

If a test fails you'll get a screenshot plus the HTML of the page inside:

```
persistence/app/tests/_output/
```

You can rerun just the failed tests with:

```
vendor/bin/codecept run -g failed
```

If you want to see the browser whilst it runs the tests point your VNC client at `localhost:5900`.

## Writing tests

See the following documentation for useful helper methods:

* [codeception.com/docs/modules/WebDriver#Actions](https://codeception.com/docs/modules/WebDriver#Actions)
* [github.com/lucatume/wp-browser/blob/master/README.md#wpdb-module](https://github.com/lucatume/wp-browser/blob/master/README.md#wpdb-module)
* [github.com/lucatume/wp-browser/blob/master/src/Codeception/Module/WPDb.php](https://github.com/lucatume/wp-browser/blob/master/src/Codeception/Module/WPDb.php)

### Debugging

You can cause codeception to print out debug variables with:

```php
codecept_debug($somevariable);
```

... and then run codecept with the `--debug` flag:

```
vendor/bin/codecept run --debug tests/acceptance/YourTestCept.php
```

## CI

They run in a similar way inside CI, the main differences are:
* it uses the images that were built inside CI and pushed to gcloud
* there are no docker-compose mounts so it's all self contained
* no ports are exposed

If you are working on the CI, you can actually run it locally:

```
export OPENRESTY_IMAGE=gcr.io/planet-4-151612/planet4-base-openresty:codeception
export APP_IMAGE=gcr.io/planet-4-151612/planet4-base-app:codeception
make ci
```
