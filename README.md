# openshift-utils

Scripts that I used to integrate with openshift.

## deploy.sh

This is what I used to deploy to openshift.  I use it because
the built-in `dpl` script in `travis-ci` works a bit weird
for my taste.

### Configuring

0. Pre-requisites:
   - Install the travis command-line client.
1. Add this repo to your OpenShift project (as a submodule).
   - git submodule add $repourl $dir
1. When cloning your project repo use:
   - git clone --recursive $project
   or (within repo)
   - git update --init
2. Create/modify a `.travis.yml` file.
   - Add your tests as necessary
   - Configure your openshift credentials:
     - travis encrypt OPENSHIFT_USER=$username --add env.global
     - travis encrypt OPENSHIFT_SECRET=$pwd --add env.global
   - OPENSHIFT_APP will default to the travis branch name
   - Variables can be overriden from a `.diydeploy_rc` script
   - Create deploy section.  See example:

```yaml
    # Example deploy
    deploy:
      provider: script
      script: ./$dir/deploy.sh
      on:
        all_branches: true
```

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
