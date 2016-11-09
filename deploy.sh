#!/bin/sh
#
fatal() {
  echo "$@" 1>&2
  exit 1
}

echo "DIY DEPLOY OPENSHIFT"
if [ -z "$OPENSHIFT_APP" ] ; then
  if [ -n "$TRAVIS_BRANCH" ] ; then
    OPENSHIFT_APP="$TRAVIS_BRANCH"
  else
    echo "Not a BRANCH commit.  No deployment possible"
    exit 0
  fi
fi

# Allow for additional customizations...
user_cfg="./.diydeploy_rc"
[ -f "$user_cfg" ] && . "$user_cfg"

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
echo "Will Deploy to $OPENSHIFT_APP"
#
set -e
if ! type rhc ; then
  gem install net-ssh --version 2.9.4
  gem install rhc
fi
AUTH="-l $OPENSHIFT_USER -p $OPENSHIFT_SECRET"
rhc app-show $OPENSHIFT_APP $AUTH | grep -v 'Password:' | grep -v 'Username:'
GITURL="$(rhc app-show $OPENSHIFT_APP $AUTH| grep '  Git URL: ' | cut -d: -f2-)"
[ -z "$GITURL" ] && fatal "MISSING GITURL"
GITHOST="$(echo $GITURL | cut -d'@' -f2 | cut -d/ -f1)"
[ -z "$GITHOST" ] && fatal "MISSING GITHOST"

if [ -f $HOME/.ssh/known_hosts ] ; then
  cp $HOME/.ssh/known_hosts $HOME/.ssh/known_hosts.tmp
  RECOVER_KNOWN_HOSTS=yes
else
  RECOVER_KNOWN_HOSTS=no
fi
ssh-keyscan $GITHOST > ~/.ssh/known_hosts

if [ -f $HOME/.ssh/id_rsa ] ; then
  REKEY=:
else
  REKEY=
fi
yes '' | $REKEY ssh-keygen -N ''
$REKEY rhc sshkey remove temp $AUTH || true
$REKEY rhc sshkey add temp $HOME/.ssh/id_rsa.pub $AUTH

git remote remove openshift || true
git remote add openshift -f $GITURL
pwd
git status
git remote -v
export GIT_EDITOR=false # It is an error to ask for this!
echo Merging changes from openshift/master to our branch
git merge openshift/master -s recursive -X ours -m "$(date +%Y-%m-%d.%H:%M:%S)"
echo Sending changes to openshift/master
git push openshift HEAD:master
$REKEY rhc sshkey remove temp $AUTH || true
[ $RECOVER_KNOWN_HOSTS = yes ] \
  && mv $HOME/.ssh/known_hosts.tmp $HOME/.ssh/known_hosts
