# openshift-utils

Scripts that I used to integrate with openshift and travis-ci.

## Pre-requisites

Most of the scripts here require the following:

1. Dependancies:
   - Install the travis command-line client.
   - Install the rhc command-line client.
2. Add this repo to your OpenShift project (as a submodule).
   - git submodule add $repourl $dir
3. When cloning your project repo use:
   - git clone --recursive $project
   or (within repo)
   - git submodule update --init

## deploy.sh

This is what I use to deploy to openshift.  I use it because
the built-in `dpl` script in `travis-ci` works a bit weird
for my taste.

### Configuring

1. Create/modify a `.travis.yml` file, add your tests as necessary.
2. Configure your openshift credentials:
   - travis encrypt OPENSHIFT_USER=$username --add env.global
   - travis encrypt OPENSHIFT_SECRET=$pwd --add env.global
3. OPENSHIFT_APP will default to the travis branch name
4. Variables can be overriden from a `.diydeploy_rc` script
5. Create deploy section.  See example:

```yaml
    # Example deploy
    deploy:
      provider: script
      script: ./$dir/deploy.sh
      on:
        all_branches: true
```

### Running locally

From the root of the git repo:

- TRAVIS_BRANCH=branch OPENSHIFT_USER=user OPENSHIFT_SECRET=password ./.openshift/ci-utils/deploy.sh

## mkplug.sh

Packages a wordpress plugin into a zip for deployment
into a wordpress instance.

### Configuring

1. Use travis:
  - travis setup release
  - Use `*.zip` for the file to upload.
2. Edit `.travis.yml`
  - add to the `deploy` section:
    - file_glob: true
    - on: tags: true
  - in `before_deploy:`
    - "./ci-utils/mkplug.sh wp"

This will upload the wordpress plugin into github
release tag.

### Running locally

This script can be run locally from the root of
the git repo.

- TRAVIS_REPO_SLUG=./plugin-name TRAVIS_TAG=version ./ci-utils/mkplug.sh wp

## pushplug.sh

Used to push a plugin to a running wordpress site hosted
on OpenShift.

### Configuring

1. Create/modify a `.travis.yml` file, add your tests as necessary.
2. Configure your openshift credentials:
   - travis encrypt OPENSHIFT_USER=$username --add env.global
   - travis encrypt OPENSHIFT_SECRET=$pwd --add env.global
3. OPENSHIFT_APP will default to the travis branch name
4. Plugin name defaults to the basename of the repo slug.
4. Variables can be overriden from a `.pushplug_rc` script
5. Call `pushplug.sh` from `.travis.yml`.  Since typically
   the `deploy` section would be used to create the plugin
   zip file, you should use the `script` section.  Example:
   - "./ci-utils/phpcheck && ./ci-utils/pushplug.sh"

### Running locally

From the root of the git repo:

- TRAVIS_BRANCH=branch WP_PLUGIN=plugname OPENSHIFT_USER=$user OPENSHIFT_SECRET=$pwd ./ci-utils/pushplug.sh

## Misc scripts

- phpcheck : Does a PHP lint check of all PHP
  files in the current directory (recursively).

## NOTES

- travis has a number of places to run stuff:
  - `before_install`, `install`, `before_script` : these run
    before the test script and stops immediatly when an error occurs.
    Any errors here will cause the build as being marked **failed**.
  - `script` : commands here can return non-zero and that marks the build
    as failed.  But it will not stop the script from executing.
  - `after_success`, `after_failure`, `after_script` : these run after
    `script` and its results do not affect the status of the build.
  - `deploy` : Can be overriden with _experimental_ script provider.
  - `before_deploy` can mark the build as **errored**.


