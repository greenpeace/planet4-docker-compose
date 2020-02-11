# Testing

For acceptance testing we use [codeception](https://codeception.com/) together with [WPBrowser](https://codeception.com/for/wordpress) for closer integration with WordPress.

Features:
* directly read/write to the WordPress database
* run in a full browser environment via selenium
* use the high level codeception API for writing simple tests

A very simple test might look like this:

```php
<?php
$I = new AcceptanceTester($scenario);
$I->wantTo('check home page');
$I->amOnPage('/');
$I->see('People Power', 'h2');
```

There are two environments in which the tests run:

* this developer environment
* CI environment
  * see [CircleCI configuration](https://github.com/greenpeace/planet4-base-fork/blob/codeception/.circleci/config.yml#L44) in base

Both of the environments start by loading the [default content](https://k8s.p4.greenpeace.org/defaultcontent/) so you can write tests against that content.

## Running tests

Assuming you docker-compose development environment is already up (see [README](README.md) and running, you first need to install test dependencies. This only needs to happen once:

```
make test
```

To run the tests next time just run:

```
make test-codeception
```

If you want to run individual tests it's easiest to get a php shell inside a docker container:

```
make php-shell
```

From there you can run all the tests with:

```
tests/vendor/bin/codecept run
```

... or a single test:

```
tests/vendor/bin/codecept run tests/acceptance/HomePageCept.php
```

### Troubleshooting

* In case you don't find the Codeception binary (`tests/vendor/bin/codecept`), run:

```
cd tests
composer install
```

Inside the PHP container you accessed through `php-shell`.

* To ensure the code you changed is being tested, make sure to flush the cache between tests by typing:

```
make flush
```

In the docker-compose root.

### Test failures

If a test fails you'll get a screenshot plus the HTML of the page inside:

```
persistence/app/tests/_output/
```

You can also rerun just the failed tests with:

```
vendor/bin/codecept run -g failed
```

### VNC connection

You can watch the browser live as it runs the tests by connecting a VNC client to:

```
localhost:5900
```

## Writing tests

Tests start with a minimal boilerplate and a description:

```php
$I = new AcceptanceTester($scenario);
$I->wantTo('check something works!');
```

Most will then load a page:

```php
$I->amOnPage('/act');
```

And then check some content on the page:

```php
// check some text is on the page
$I->see('Welcome to WordPress!');

// ... or within a particular selector
$I->see('People Power', '.example-class h2')

// check an element is on the page
$I->seeElement('.page-header');

// ... or an element with a particular attribute
$I->seeElement('.cat-gallery img', [
    'src' => 'http://www.planet4.test/wp-content/uploads/2018/05/my-cat.jpg']
);

// check is link is present
$I->seeLink('Facebook', 'https://www.facebook.com/greenpeace.international');
````

There might be further interaction with the page:

```php
// click a button
$I->click('Some Button Text');

// fill in and submit a form
$I->submitForm('#search_form', ['s' => 'climate']);
//
```

Check the existing tests or see the following documentation for more useful helper methods:

* [codeception.com/docs/modules/WebDriver#Actions](https://codeception.com/docs/modules/WebDriver#Actions)
* [github.com/lucatume/wp-browser/blob/master/README.md#wpdb-module](https://github.com/lucatume/wp-browser/blob/master/README.md#wpdb-module)
* [github.com/lucatume/wp-browser/blob/master/src/Codeception/Module/WPDb.php](https://github.com/lucatume/wp-browser/blob/master/src/Codeception/Module/WPDb.php)

### Creating content during the test

Sometimes you might write tests against the default content,
but other times you might want to create specific content during the test.

For example, we can create a new published page with a specific shortcode element:

```php
$slug = $I->generateRandomSlug();

$I->havePageInDatabase([
  'post_name' => $slug,
  'post_status' => 'publish',
  'post_content' => $I->generateShortcode('shortcake_two_columns', [
    'title_1' 		=> 'column one title',
    'description_1' => 'column one description',
    'button_text_1' => 'column one button',
    'button_link_1' => 'http://buttonone.com',
    'title_2' 		=> 'column two title',
    'description_2' => 'column two description',
    'button_text_2' => 'column two button',
    'button_link_2' => 'http://buttontwo.com'
  ])
]);

$I->amOnPage('/' . $slug);
```

Any created database content is automatically cleaned up at the end of the test
(although sometimes this does not happen).

### Helper methods

If you want to reuse some functionality across tests you can
add helpers to the `AcceptanceTester` class in:

```
persistence/app/tests/_support/AcceptanceTester.php
```

If the helper is just a function and doesn't need to make use of the `$I` tester
then you can put them in:

```
persistence/app/tests/_support/Helper/Acceptance.php
```

### Debugging

You can cause codeception to print out debug variables with:

```php
codecept_debug($somevariable);
```

... and then run codeception with the `--debug` flag:

```
vendor/bin/codecept run --debug tests/acceptance/YourTestCept.php
```

## CI

The tests run in a similar way inside CI, the main differences are:
* it uses the images that were built inside CI and pushed to gcloud
* there are no docker-compose mounts so it's all self contained
* no ports are exposed

If you are debugging a problem with the CI setup,
you can run the same command locally
if you tell it where get the APP/OPENRESTY images from:

```
export OPENRESTY_IMAGE=gcr.io/planet-4-151612/planet4-base-openresty:codeception
export APP_IMAGE=gcr.io/planet-4-151612/planet4-base-app:codeception
make ci
```

## NRO

The NRO-specific tests are a simplified version of the main tests. In particular:

- only one suite (an acceptance suite named "tests")
- mainly designed to run against the gcloud deployed environments
- NRO repos contain no codeception configuration, only a `tests/` directory, with the tests directly in
- when executed the codeception configuration is copied into the directory
- configuration and dependencies are defined in [greenpeace/planet4-circleci-codeception](https://github.com/greenpeace/planet4-circleci-codeception)
- `codeceptionify.sh <destination>` script copies the needed configuration files into `<destination>`
- only base codeception modules are available (i.e. nothing from [lucatume/wp-browser](https://github.com/lucatume/wp-browser)) - so no direct db access or content seeding
