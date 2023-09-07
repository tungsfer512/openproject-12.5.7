# Testing OpenProject

OpenProject uses automated tests throughout the stack. Tests that are executed in the browser (angular frontend, rspec system tests) require to have Chrome installed.

You will likely start working with the OpenProject test suite through our continuous testing setup at [GitHub Actions](https://github.com/opf/openproject/actions). All pull requests and commits to the core repository will be tested by GitHub Actions.



# Continuous testing with GitHub Actions

As part of the [development flow at OpenProject](../../development/#branching-model-and-development-flow), proposed changes to the core application will be made through a GitHub pull request and the entire test suite is automatically evaluated on GitHub Actions. You will see the results as a status on your pull request.

Successful test suite runs are one requirement to see your changes merged.


## List failures

A failing status will look like the following on your pull request. You may need to click *Show all checks* to expand all checks to see the details link.

![Exemplary failing github actions test suite](github-broken-tests-pr.png)



Here you'll see that the *GitHub Actions* check has reported an error, which likely means that your pull request contains errors. It might also result from a [temporary error running the test suite](#tests-failing-on-github-actions-ci-and-passing-locally), or from a test that was broken in the `dev` branch.

The test suite is [run in parallel](#parallel-testing) to save time. The overall run time of the test suite is around *15 minutes* on GitHub.

Click on the Details link to see the individual *jobs* that GitHub executes.

[Here's a link to an exemplary failed test run on GitHub](https://github.com/opf/openproject/pull/9355/checks?check_run_id=2730782867). In this case, one of the feature jobs has reported an error.

![Exemplary failed status details](github-broken-tests-pr-details1.png)



Click on each job and each step to show the [log output for this job](https://github.com/opf/openproject/pull/9355/checks?check_run_id=2730782867). It will contain more information about how many tests failed and will also temporarily provide a screenshot of the browser during the occurrence of the test failure (only if a browser was involved in testing).

In our example, multiple tests are reported as failing:
```
rspec ./spec/features/work_packages/pagination_spec.rb[1:1:1:1] # Work package pagination with project scope behaves like paginated work package list is expected not to have text "WorkPackage No. 23"
rspec ./spec/features/work_packages/pagination_spec.rb[1:2:1:1] # Work package pagination globally behaves like paginated work package list is expected not to have text "WorkPackage No. 29"
rspec ./spec/features/work_packages/timeline/timeline_navigation_spec.rb:131 # Work package timeline navigation can save the open state and zoom of timeline
rspec ./spec/features/work_packages/timeline/timeline_navigation_spec.rb:193 # Work package timeline navigation with a hierarchy being shown toggles the hierarchy in both views
rspec ./spec/features/work_packages/timeline/timeline_navigation_spec.rb:317 # Work package timeline navigation when table is grouped shows milestone icons on collapsed project group rows but not on expanded ones
```

![GitHub job log showing failing test](github-broken-tests.png)



## Diagnose failures

Once you know which tests are failing, run them locally to try and reproduce the failures. Having reproducible failures locally is the first step to diagnose and fix them.

How to do this depends on the kind of job that failed.


**Errors in the npm group**

An error in the *npm* group means you likely have broken an existing Angular component spec or added an invalid new one. Please see the [Frontend tests](#frontend-tests) section on how to run them.



**Errors in the units group**

An error in the *units* group means there is a failing ruby unit test. Please see the [Unit tests](#unit-tests) section on how to run these.

**Errors in the features group**

You will be able to run failing tests locally in a similar fashion for all errors reported in the  `units`  and `features` jobs. Please see the [System tests](#system-tests) section for more information.



**Helper to extract all failing tests**

There is a small ruby script that will parse the logs of a GitHub Actions run and output all `rspec` tests that failed for you to run in one command.

```
./script/github_pr_errors
```

If you want to run the tests directly to rspec, you can use this command:

```
./script/github_pr_errors | xargs bundle exec rspec
```


## Tests failing on GitHub Actions CI and passing locally

Some tests can fail on GitHub actions CI, and pass locally which makes them harder to reproduce, diagnose, and fix.

Possible reasons are:

* Different configuration between CI environment and local environment
  * GitHub actions run with `CI=true` environment variable. This setting will eager load the app before running tests. As some classes may monkey patch parts of the code, the behavior can be different when the app is fully loaded.
    * Try running the tests with `CI=true`.
  * OpenProject configuration difference
    * Try changing or disabling any environment variables prefixed with `OPENPROJECT_` in your environment or `.env` files.
    * Try changing or removing `config/configuration.yml` settings under the `test:` key.
* Missing executables
  * Source control management tests may need `svnadmin` or `git` to execute properly.
  * LDAP tests may need `java` to spin up a LDAP server instance.
* Different test execution order
  * Parts of the OpenProject code are using memoization and caching for performance, and some tests can do weird things like prepending a module or other meta programming. Without proper clean up of the global state, subsequent tests may fail. It can go unnoticed depending on the test execution order.
  * RSpec tests order is different on each run. The order is defined by the random seed which can be set with `--seed` option. When running rspec, the random seed is displayed like this: `Randomized with seed 18352`.
  * Try running tests locally with the same random seed as the one used on CI.
    * Once you determined that the failure is order dependant, use [`--bisect`](https://relishapp.com/rspec/rspec-core/docs/command-line/bisect) to isolate the minimal set of examples that reproduce the same failures.
* Faster / slower machine and race conditions
  * Some system tests using browser and performing ajax requests may not be synchronized with the test execution: the test is testing something that has not happened yet. Sometimes the ajax runs at the right time and the test passes, sometimes it runs at the wrong time and the test fails.
  * Use `script/bulk_run_rspec` to run the same test multiple times. If it has both failing and passing results, it means it is a flickering test.
  * To help diagnose why a system test is failing:
    * Browser screenshots are created for failing system tests involving a browser. You can find them in the job log output.
    * Try running with `OPENPROJECT_TESTING_NO_HEADLESS=1` to view what the browser is doing. Use `OPENPROJECT_TESTING_AUTO_DEVTOOLS=1` to have DevTools opened so that you can use `debugger` statements in the js code.
* Migration executed locally
  * While developing on another branch, you may run migrations and forget to roll them back when switching branches. This can lead to different test results: a migration modifying a database column default value can impact system behavior and change test results.
  * To find if this is your case, run `rails db:migrate:status` to list migration status. Look for `up    <migration-id>  ********** NO FILE **********` patterns. If you have some, try looking up the commit associated with this migration and check if it explains behavior difference.
  * To look up commits referencing the migration, use the `<migration-id>` from previous command and run `git log -p --all -- '**/*<migration-id>*'`. For instance `git log -p --all -- '**/*20220816065025*'`.
  * If you find a commit and want to roll the associated migration back:
    * Checkout the commit: `git switch --detach <commit-sha>`
    * Roll the migration back: `rails db:migrate:down VERSION=<migration-id>`
    * Switch back to where you left: `git switch -`



## Skip test execution on GitHub Actions CI

Sometimes, you know you're pushing changes to a pull request that you now are work in progress or are known to break existing or new tests.

To avoid additional test executions, you can include `[skip ci]` in your commit message to ensure GitHub Actions are not being triggered and skips your build. Please note that a successful merge of your pull request will require a green CI build.



# Running tests locally

As there are multiple ways employed to test OpenProject, you may want to run a specific test or test group.



## Prerequisites

In order to be able to run tests locally, you need to have set up a local development stack.



### Verifying your dependencies

To ensure your local installation is up to date and prepared for development or running tests, there is a helper script `./bin/setup_dev` that installs backend and frontend dependencies. When switching branches or working on a new topic, it is recommended to run this script again.



### Setting up a test database

As part of the development environment guides, you will have created a development and test database and specified it under `config/database.yml`:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  host: localhost
  username: openproject
  password: openproject-dev-password

development:
  <<: *default
  database: openproject_dev

test:
  <<: *default
  database: openproject_test
```



The configuration above determines that a database called `openproject_test` is used for the backend unit and system tests. The entire contents of this database is being removed during every test suite run.



Before you can start testing, you will often need to run the database migrations first on the development and the test database. You can use the following rails command for this:

```bash
RAILS_ENV=development rails db:migrate db:test:prepare
```



This migrates the _development_ database, outputting its schema to `db/schema.rb` and will copy this schema to the test database. This ensures your test database matches your current expected schema.



## Frontend tests

To run JavaScript frontend tests, first ensure you have all necessary dependencies installed via npm (i.e. `npm install`).

You can run all frontend tests with the standard npm command:

    npm test



Alternatively, when in the `frontend/` folder, you can also use the watch mode of Angular to automatically run tests after you changed a file in the frontend.

```bash
./node_modules/.bin/ng test --watch
```



## Unit tests

After following the prerequisites, use the following command to run individual specs:

```bash
RAILS_ENV=test bundle exec rspec spec/models/work_package_spec.rb
```

Run multiple specs by separating them with spaces:

```bash
RAILS_ENV=test bundle exec rspec spec/models/work_package_spec.rb spec/models/project_spec.rb
```



## System tests

System tests are also called *rspec feature specs* and use [Capybara](https://rubydoc.info/github/teamcapybara/capybara/master) and [Selenium](https://www.selenium.dev/documentation/webdriver/) to run. They are automatically executed with an actual browser when `js: true` is set.

System tests are located in `spec/features`. Use the following command to run individual test:

```bash
RAILS_ENV=test bundle exec rspec spec/features/auth/login_spec.rb
```



### Dependencies

For the javascript dependent integration tests, you have to install Chrome and Firefox, to run them locally.

Capybara uses Selenium to drive the browser and perform the actions we describe in each spec. We have tests that mostly depend on Chrome and Chromedriver, but some also require specific behavior that works better in automated Firefox browsers.



### Running system tests

Almost all system tests depend on the browser for testing, you will need to have the Angular CLI running to serve frontend assets.

So with `npm run serve` running and completed in one tab, run the test using `rspec` as  for the unit tests:

```bash
RAILS_ENV=test bundle exec rspec ./modules/documents/spec/features/attachment_upload_spec.rb[1:1:1:1]
```

The tests will generally run a lot slower due to the whole application being run end-to-end, but these system tests will provide the most elaborate tests possible.



You can also run *all* feature specs locally with this command. This is not recommended due to the required execution time. Instead, prefer to select individual tests that you would like to test and let GitHub Actions CI test the entire suite.

```bash
RAILS_ENV=test bundle exec rake parallel:features -- --group-number 1 --only-group 1
```

#### WSL2

In case you are on Windows using WSL2 rather than Linux directly, running tests this way will not work. You will see an error like "Failed to find Chrome binary.". The solution here is to use Selenium Grid.

**1) Download the chrome web driver**

You can find the driver for your Chrome version [here](https://chromedriver.chromium.org/downloads)

**2) Add the driver to your `PATH`**

Either save the driver under `C:\Windows\system32` to make it available or add its alternative location to the `PATH` using the system environment variable settings ([press the WIN key and search for 'system env').

**3) Find out your WSL ethernet adapter IP**

You can do this by opening a powershell and running ```wsl cat /etc/resolv.conf `| grep nameserver `| cut -d ' ' -f 2```. Alternatively looking for the adapter's IP in the output of `ipconfig` works too.
It will be called something like "Ethernet adapter vEthernet (WSL)".

**4) Download Selenium hub**

Download version 3.141.59 (at the time of writing) [here](https://www.selenium.dev/downloads/)

The download is a JAR, i.e. a Java application. You will also need to download and install a Java Runtime Environment in at least version 8 to be able to run it.

**5) Run the Selenium Server**

In your powershell on Windows, find the JAR you downloaded in the previous step and run it like this:

```
java -jar .\Downloads\selenium-server-standalone-3.141.59.jar -host 192.168.0.216
```

Where `192.168.0.216` is your WSL IP from step 3).

**6) Setup your test environment**

Now you are almost ready to go. All that you need to do now is to set the necessary environment
for the browser on Windows to be able to access the application running on the Linux host.
Usually this should work transparently but it doesn't always. So we'll make sure it does.

Now in the linux world do the following variables:

```
export RAILS_ENV=test
export CAPYBARA_APP_HOSTNAME=`hostname -I`
export SELENIUM_GRID_URL=http://192.168.0.216:4444/wd/hub
```

Again `192.168.0.216` is the WSL IP from step 3). `hostname -I` is the IP of your Linux host seen from within Windows.
Setting this make sure the browser in Windows will try to access, for instance `http://172.29.233.42:3001/` rather than `http://localhost:3001` which may not work.

**7) Run the tests**

Now you can run the integration tests as usual as seen above. For instance like this:

```
bundle exec rspec ./modules/documents/spec/features/attachment_upload_spec.rb[1:1:1:1]
```

There is no need to prefix this with the `RAILS_ENV` here since we've exported it already before.

### Headless testing

Firefox tests through Selenium are run with Chrome as `--headless` by default. This means that you do not see the browser that is being tested. Sometimes you will want to see what the test is doing to debug. To override this behavior and watch the Chrome or Firefox instance set the ENV variable `OPENPROJECT_TESTING_NO_HEADLESS=1`.



### Troubleshooting

```
Failure/Error: raise ActionController::RoutingError, "No route matches [#{env['REQUEST_METHOD']}] #{env['PATH_INFO'].inspect}"

     ActionController::RoutingError:
       No route matches [GET] "/javascripts/locales/en.js"
```

If you get an error like this when running feature specs it means your assets have not been built.
You can fix this either by accessing a page locally (if the rails server is running) once or by ensuring the `bin/setup_dev` script has been run.



## Entire local RSpec suite

You can run the specs with the following commands:

* `bundle exec rake spec` Run all core specs and feature tests. Again ensure that the Angular CLI is running for these to work. This will take a long time locally, and it is not recommend to run the entire suite locally. Instead, wait for the test suite run to be performed on GitHub Actions CI as part of your pull request.

* `SPEC_OPTS="--seed 12935" bundle exec rake spec` Run the core specs with the seed 12935. Use this to control in what order the tests are run to identify order-dependent failures. You will find the seed that GitHub Actions CI used in their log output.


## Parallel testing

Running tests in parallel makes usage of all available cores of the machine.
Functionality is being provided by [parallel_tests](https://github.com/grosser/parallel_tests) gem.
See its GitHub page for any options like number of cpus used.

#### Prepare

By default, `parallel_test` will use CPU count to parallelize. This might be a bit much to handle for your system when 8 or more parallel browser instances are being run. To manually set the value of databases to create and tests to run in parallel, use this command:

```bash
export PARALLEL_TEST_PROCESSORS=4
```



Adjust `database.yml` to use different databases:

```yml
test: &test
  database: openproject_test<%= ENV['TEST_ENV_NUMBER'] %>
  # ...
```

Create all databases: `RAILS_ENV=test ./bin/rails parallel:create db:migrate parallel:prepare`

Prepare all databases:

First migrate and dump your current development schema with `RAILS_ENV=development ./bin/rails db:migrate db:schema:dump` (will create a db/structure.sql)

Then you can just use `RAILS_ENV=test ./bin/rails parallel:prepare` to prepare test databases.

#### RSpec specs

Run all unit and system tests in parallel with `RAILS_ENV=test ./bin/rails parallel:spec`

#### Running specific tests

If you want to run specific tests (e.g., only those from the team planner module), you can use this command:

```bash
RAILS_ENV=test bundle exec parallel_rspec -- modules/team_planner/spec
```

## Automatically run tests when files are modified

To run tests automatically when a file is modified, you can use [watchexec](https://github.com/watchexec/watchexec) like this:

```
watchexec --exts rb,erb -- bin/rspec spec/some/path/to/a_particular_spec.rb
```

This command instructs `watchexec` to watch `.rb` and `.erb` files for modifications in the current folder and its subfolders. Whenever a file modification is reported, the command `bin/rspec spec/some/path/to/a_particular_spec.rb` will be executed.

Stop `watchexec` by pressing `Ctrl+C`.

Set an alias to make it easier to call:
```
alias wrspec='watchexec --exts rb,erb -- bin/rspec'

wrspec spec/some/path/to/a_particular_spec.rb
```

To easily change the RSpec examples being run without relaunching `watchexec` every time, you can focus a particular example or example group with `focus: true`, `fit`, `fdescribe`, and `fcontext`. More details available on [RSpec documentation](https://relishapp.com/rspec/rspec-core/docs/filtering/filter-run-when-matching).


## Manual acceptance tests

* Sometimes you want to test things manually. Always remember: If you test something more than once, write an automated test for it.
* Assuming you do not have a version of Edge already installed on your computer, you can grab a VM with preinstalled IE's directly from [Microsoft](https://developer.microsoft.com/en-us/microsoft-edge/tools/vms/)



## Accessing a local OpenProject instance from a VM

If you want to access the development server of OpenProject from a VM, you need to work around the CSP `localhost` restrictions.

### Old way, fixed compilation

One way is to disable the Angular CLI that serves some of the assets when developing. To do that, run

```bash

# Precompile the application
./bin/rails assets:precompile

# Start the application server while disabling the CLI asset host
OPENPROJECT_CLI_PROXY='' ./bin/rails s -b 0.0.0.0 -p 3000
```

Now assuming networking is set up in your VM, you can access your app server on `<your local ip>:3000` from it.

### New way, with ng serve

**The better way** when you want to develop against Edge is to set up your server to allow the CSP to the remote host.
Assuming your openproject is served at `<your local ip>:3000` and your ng serve middleware is running at `<your local ip>:4200`,
you can access both from inside a VM with nat/bridged networking as follows:

```bash
# Start ng serve middleware binding to all interfaces
npm run serve:public

# Start your openproject server with the CLI proxy configuration set
OPENPROJECT_CLI_PROXY='http://<your local ip>:4200' ./bin/rails s -b 0.0.0.0 -p 3000

# Now access your server from http://<your local ip>:3000 with code reloading
```

## Legacy LDAP tests

OpenProject supports using LDAP for user authentications.  To test LDAP
with OpenProject, load the LDAP export from test/fixtures/ldap/test-ldap.ldif
into a testing LDAP server.  Test that the ldap server can be accessed
at 127.0.0.1 on port 389.

Setting up the test ldap server is beyond the scope of this documentation.
The Apache DS project provides a simple LDAP implementation that should work
good as a test server.

## Running tests locally in Docker

Most of the above applies to running tests locally, with some docker specific setup changes that are discussed [in the
docker development documentation](../development-environment-docker).
