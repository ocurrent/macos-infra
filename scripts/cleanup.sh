#!/bin/sh
USERNAME=$1
sudo dscl . -delete "/Users/$USERNAME"
echo "You might also want to delete the users home directory, be careful! (e.g. sudo rm -rf /Users/<USERNAME>)" 
