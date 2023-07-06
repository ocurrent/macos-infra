#!/bin/bash
set -eux

if [ $# -eq 0 ] || [ -z "$1" ] ; then
  echo "update.sh [intel|apple]"
  exit 1
fi

if [ "$1" = "intel" ] ; then
  POOL="macos-x86_64"
  PREFIX="i7"
else
  if [ "$1" = "apple" ] ; then
    POOL="macos-arm64"
    PREFIX="m1"
  else
    echo "update.sh [intel|apple]"
    exit 1
  fi
fi

# for nn in 01 02 03 04 ; do
for nn in 01 ; do
  NAME="$PREFIX-worker-$nn"
  FQDN="$NAME.macos.ci.dev"
  ci3-admin pause --wait $POOL $NAME
  ssh $FQDN launchctl unload "~/Library/LaunchAgents/com.tarides.ocluster.worker.plist"
  ansible-playbook -i hosts --limit $FQDN playbook.yml
  ssh $FQDN launchctl load "~/Library/LaunchAgents/com.tarides.ocluster.worker.plist"
  ci3-admin unpause $POOL $NAME
done

