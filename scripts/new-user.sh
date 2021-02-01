#!/bin/sh
UNID=$1
USERNAME=$2

USERDIR="/Users/$USERNAME"

echo "Creating a new user (UID: $UNID, USERNAME: $USERNAME, DIR: $USERDIR)"

sudo mkdir -p $USERDIR
sudo dscl . -create $USERDIR
sudo dscl . -create $USERDIR UniqueID $UNID
sudo dscl . -create $USERDIR PrimaryGroupID 20
sudo dscl . -create $USERDIR UserShell /bin/bash 
sudo dscl . -create $USERDIR NFSHomeDirectory $USERDIR
sudo dscl . -passwd $USERDIR ocaml
sudo dscl . -append /groups/admin GroupMembership $USERNAME
sudo mkdir -p $USERDIR/local
sudo chown -R $USERNAME: $USERDIR
sudo chmod -R 775 $USERDIR

echo "Making default .bash_profile"
echo "export HOMEBREW_DISABLE_LOCKING=\"1\"" > "$USERDIR/.bash_profile"
echo "export HOMEBREW_NO_AUTO_UPDATE=\"1\"" >> "$USERDIR/.bash_profile"