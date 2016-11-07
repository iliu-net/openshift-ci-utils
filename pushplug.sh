#!/bin/sh
#
fatal() {
  echo "$@" 1>&2
  exit 1
}

echo "PUSH PLUG"
if [ -z "$OPENSHIFT_APP" ] ; then
  if [ -n "$TRAVIS_BRANCH" ] ; then
    OPENSHIFT_APP="$TRAVIS_BRANCH"
  else
    echo "Not a BRANCH commit.  No deployment possible"
    exit 0
  fi
fi

if [ -n "$TRAVIS_REPO_SLUG" ] ; then
  WP_PLUGIN="$(basename "$TRAVIS_REPO_SLUG")"
fi

UNPACK_CMD='tar -zxf -'
PACK_CMD='tar -zcf - --exclude-vcs .'

# Allow for additional customizations...
user_cfg="./.pushplug_rc"
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

for k in OPENSHIFT_USER OPENSHIFT_SECRET OPENSHIFT_APP WP_PLUGIN
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

SSHADDR="$(rhc app-show $OPENSHIFT_APP $AUTH| grep '  SSH: ' | cut -d: -f2-)"
[ -z "$SSHADDR" ] && fatal "MISSING SSHADDR"
SSHHOST="$(echo $SSHADDR| cut -d'@' -f2)"
[ -z "$SSHHOST" ] && fatal "MISSING SSHHOST ($SSHADDR)"
ssh-keyscan $SSHHOST > ~/.ssh/known_hosts

if [ -f $HOME/.ssh/id_rsa ] ; then
  REKEY=:
else
  REKEY=
fi
yes '' | $REKEY ssh-keygen -N ''
$REKEY rhc sshkey remove temp $AUTH || true
$REKEY rhc sshkey add temp $HOME/.ssh/id_rsa.pub $AUTH

SSHCMD="ssh -i $HOME/.ssh/id_rsa $SSHADDR"

# Remove current Plugin data/directory
# Copy plugin <content>/$WP_PLUGIN.t
# Move $WP_PLUGIN to $WP_PLUGIN.o
# move $WP_PLUGIN.t to $WP_PLUGIN
# rm -rf $P_PLUGIN.o

plug_path="app-root/data/current/wp-content/plugins/$WP_PLUGIN"
$SSHCMD mkdir -p "$plug_path.t"
$PACK_CMD | $SSHCMD $UNPACK_CMD -C "$plug_path.t"
(
  echo "mv \"$plug_path\" \"$plug_path.p\""
  echo "mv \"$plug_path.t\" \"$plug_path\""
  echo "rm -rf \"$plug_path.p\""
) | $SSHCMD

$REKEY rhc sshkey remove temp $AUTH || true
