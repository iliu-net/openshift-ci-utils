#!/bin/sh
#
# Package a Wordpress Plug
#
fatal() {
  echo "$@" 2>&1
  exit 1
}

[ -z "${TRAVIS_REPO_SLUG}" ] && fatal "NO TRAVIS_REPO_SLUG defined"
[ -z "${TRAVIS_TAG}" ] && fatal "NO TRAVIS_TAG defined"

plugname="$(basename "${TRAVIS_REPO_SLUG}")"
utils_dir="$(dirname $0 | sed -e 's!^./!!')"
zipfile="$plugname.$TRAVIS_TAG.zip"

workdir=".workdir" ; trap "echo cleanup; rm -rf $workdir" EXIT
mkdir -p "$workdir/$plugname"

find * -type f \
	| grep -v "^$utils_dir/" \
	| grep -v "^$zipfile\$" \
	| grep -v '/.git' | cpio -o | ( cd "$workdir/$plugname" && cpio -d  -i )
( here=$(pwd) && cd "$workdir" && zip -r "$here/$zipfile" "$plugname" )
