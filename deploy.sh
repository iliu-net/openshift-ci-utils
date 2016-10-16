#!/bin/sh
#
fatal() {
  echo "$@" 1>&2
  exit 1
}

echo "DIY DEPLOY OPENSHIFT"
if [ -n "$TRAVIS_BRANCH" ] ; then
  OPENSHIFT_APP="$(grep ' - deploy '"$TRAVIS_BRANCH"':' .travis.yml | cut -d: -f2)"
  if [ -n "$OPENSHIFT_APP" ] ; then
    echo "App: $OPENSHIFT_APP"
  else
    echo "Branch $TRAVIS_BRANCH is not deployable"
    exit 0
  fi
else
  echo "Not a BRANCH commit.  No deployment possible"
  exit 0
fi

# Allow for additional customizations...
[ -f ".diydeploy_rc" ] && . ".diydeploy_rc"

[ -n "$OPENSHIFT_USER" ] && echo "USER: $OPENSHIFT_USER"
if [ -n "$OPENSHIFT_SECRET" ] ; then
  echo -n "SECRET: "
  cnt=$(expr length "$OPENSHIFT_SECRET")
  while [ $cnt -gt 0 ]
  do
    echo -n "*"
    cnt=$(expr $cnt - 1)
  done
  echo ""
fi
[ -n "$TRAVIS_BRANCH" ] && echo "Branch: $TRAVIS_BRANCH"
[ -n "$TRAVIS_PULL_REQUEST" ] && echo "PR: $TRAVIS_PULL_REQUEST"
[ -n "$TRAVIS_REPO_SLUG" ] && echo "Slug: $TRAVIS_REPO_SLUG"
[ -n "$TRAVIS_TAG" ] && echo "Tag: $TRAVIS_TAG"

for k in OPENSHIFT_USER OPENSHIFT_SECRET OPENSHIFT_APP
do
  eval v="\$$k"
  [ -z "$v" ] && fatal "MISSING $k"
done
#
set -e
gem install net-ssh --version 2.9.4
gem install rhc
AUTH="-l $OPENSHIFT_USER -p $OPENSHIFT_SECRET"
rhc app-show $OPENSHIFT_APP $AUTH | grep -v 'Password:' | grep -v 'Username:'
GITURL="$(rhc app-show $OPENSHIFT_APP $AUTH| grep '  Git URL: ' | cut -d: -f2-)"
[ -z "$GITURL" ] && fatal "MISSING GITURL"
GITHOST="$(echo $GITURL | cut -d'@' -f2 | cut -d/ -f1)"
[ -z "$GITHOST" ] && fatal "MISSING GITHOST"
ssh-keyscan $GITHOST > ~/.ssh/known_hosts

yes '' | ssh-keygen -N ''
rhc sshkey remove temp $AUTH || true
rhc sshkey add temp $HOME/.ssh/id_rsa.pub $AUTH
git remote add openshift -f $GITURL
pwd
git status
git remote -v
echo Merging changes from openshift/master to our branch
git merge openshift/master -s recursive -X ours
echo Sending changes to openshift/master
git push openshift HEAD:master
rhc sshkey remove temp $AUTH || true