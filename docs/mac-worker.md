
# MacOS configuration

- Security & Privacy \ General \ Require Password
- Users & Groups \ Login Options \ Automatic login as administrator
- Sharing \ Screen sharing
- Sharing \ Remote login
- Energy Saver \ Prevent your Mac from automatically sleeping
- Energy Saver \ Start up automatically after power failure
- Install Apple Developer Command line tools
- Turn off SIP by entering Recovery Mode (Intel: Command-R; M1: hold power button) `csrutil disable`

# macFuse

Via a VNC session, install the latest version, currently 4.4.1, from [macFUSE](https://osxfuse.github.io) which requires a reboot

# Docker

> Note that Docker is not used for Mac builds yet, but `ocluster-worker` checks for it on start up so it needs to be installed.

Download and install [Docker Desktop for Mac](https://docs.docker.com/desktop/mac/install/).

Open the Docker app from Applications and authorise it to make changes to the system networking.

Set Docker desktop to start automatiaclly when a user signs in

# Remove password requirement for SUDO

This isn't essential but it saves retyping the password many, many times:

```
echo "%admin ALL=(ALL) NOPASSWD: ALL" > /private/etc/sudoers.d/admin
```

# Add SSH key

```
mkdir ~/.ssh
curl -o ~/.ssh/authorized_keys https://github.com/mtelvers.keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

# Rename the Mac to something sensible

```
sudo scutil --set HostName i7-worker-01
sudo scutil --set LocalHostName i7-worker-01
sudo scutil --set ComputerName i7-worker-01
dscacheutil -flushcache
```

# Disable Spotlight search index

```shell=
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist
```

# Homebrew

Install Homebrew

```shell=
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"


# Install Opam

```shell=
sudo chown -R $(whoami) /usr/local/lib/pkgconfig
chmod u+w /usr/local/lib/pkgconfig
brew install opam
opam init -y
eval $(opam env --switch=default)
opam install dune
```

# OCaml

Opam needs a helper application called `opam-sysintall` to allow it to install OCaml to the system folders rather than using a switch.  Install the helper like this:

```shell=
opam pin add opam-sysinstall git+https://github.com/patricoferris/opam-sysinstall --yes
```

Then install OCaml:

```shell=
cd ~
mkdir `pwd`/ocaml
opam exec -- opam sysinstall build --version 4.14.0 --prefix=`pwd`/ocaml --jobs=6
```

# Install OBuilder-fs

This is the Fuse file system.

```shell=
git clone https://github.com/ocurrent/obuilder-fs
brew install pkg-config
cd obuilder-fs
make && make install
cd ..
```

# Base Image Creation

Download Patrick's scripts:

```shell=
git clone https://github.com/ocurrent/macos-infra
cd macos-infra/scripts
chmod +x *.sh
```

Setup a `scoreboard` folder.  This folder is used by `obuilderfs` to redirect access to `/usr/local`.  See the steps below:

1) Create an empty folder
2) Create a user called `mac1000` to match so the opam installion folder will match later on.  Then rename the user folder from `/Users/mac1000' to `/Users/macos-homebrew-ocaml-4.14`. It can be any number > 501.  Password is `ocaml` which is needed for SUDO later
3) Create a link in the `scoreboard` folder redirecting to the users home directory
4) Run `obuilderfs` which takes the scoreboard folder and the folder being redirected as parameters.

Access to from user id 1000 to `/usr/local` will redirected/intercepted via `/System/Volumes/Data/scoreboard/1000` and sent to `/Users/mac1000/local`

```shell=
mkdir ~/scoreboard
./new-user.sh 1000 mac1000
ln -Fhs /Users/mac1000 ~/scoreboard/1000
sudo obuilderfs ~/scoreboard /usr/local -o allow_other
sudo chown -R mac1000:admin /Users/mac1000
```

Install script

```shell=
cp macos-homebrew-ocaml.sh /Users/mac1000
sudo -u mac1000 -i
sudo chown -R mac1000:admin /Users/mac1000
./macos-homebrew-ocaml.sh
```

After that has finished, delete the the user but leave the home directory (aka the base image) in place.

```shell=
sudo dscl . -delete /Users/mac1000
sudo mv /Users/mac1000 /Users/macos-homebrew-ocaml-4.14
```

And unmount obuilderfs on `/usr/local`

```shell=
sudo umount /usr/local
```

# Busybox home

```shell=
sudo mkdir /Users/busybox
sudo chmod g+w /Users/busybox
cat > /Users/busybox/.obuilder_profile.sh << 'EOF'
export HOMEBREW_DISABLE_LOCKING=1
export HOMEBREW_NO_AUTO_UPDATE=1
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:$PATH
export PATH=/Users/administrator/ocaml/4.14.0/bin:$PATH
export OPAMYES=1
export OPAMCONFIRMLEVEL=unsafe-yes
export OPAMERRLOGLEN=0
export OPAMPRECISETRACKING=1
EOF
```

# **Essential** random folder

```shell=
sudo mkdir -p /Volumes/rsync/result/9d75f0d7c398df565d7ac04c6819b62d6d8f9560f5eb4672596ecd8f7e96ae91/rootfs
sudo cp /Users/busybox/.obuilder_profile.sh /Volumes/rsync/result/9d75f0d7c398df565d7ac04c6819b62d6d8f9560f5eb4672596ecd8f7e96ae91/rootfs
sudo touch /Volumes/rsync/result/9d75f0d7c398df565d7ac04c6819b62d6d8f9560f5eb4672596ecd8f7e96ae91/env
sudo chmod g+w /Volumes/rsync/result/9d75f0d7c398df565d7ac04c6819b62d6d8f9560f5eb4672596ecd8f7e96ae91/env
sudo chgrp staff  /Volumes/rsync/result/9d75f0d7c398df565d7ac04c6819b62d6d8f9560f5eb4672596ecd8f7e96ae91/env
echo "((env ()))" >> /Volumes/rsync/result/9d75f0d7c398df565d7ac04c6819b62d6d8f9560f5eb4672596ecd8f7e96ae91/env
```

# Secret

Install `pool-macos-x86_64.cap` in the home directory

# OCluster

Install OCluster from Patrick's fork

```shell=
cd ~
git clone --recursive https://github.com/patricoferris/ocluster.git
cd ocluster
git checkout macos-v2
git submodule update --init
```

Edit `worker/obuilder_build.ml` line 25 and change the handler to `Obuilder.User_temp`.

> Ocluster-worker does a little health-check at the start so it tries to build something simple using busybox, with the above change this will read from `/Users/busybox` so this will need to be created and contain an empty `.obuilder_profile.sh` — this is as bare as a macOS “image” can be.

Then install the missing dependencies and compile:

```shell=
cd ~/ocluster
opam install . -y --confirm-level=unsafe-yes
eval $(opam env)
```

> `opam install alcotest-lwt current_github current_web -y` needed for newer releases

# Run the worker

```shell=
mkdir ~/lib
sudo -E DYLD_FALLBACK_LIBRARY_PATH=/Users/administrator/lib opam exec -- dune exec --profile release -- ocluster-worker --connect ~/pool-macos-x86_64.cap \
  --uid=1000 --fallback=/Users/administrator/lib --scoreboard=/Users/administrator/scoreboard \
  --obuilder-store=rsync:/Volumes/rsync --state-dir=/var/lib/ocluster-worker \
  --name=`hostname` --capacity=1 --obuilder-prune-threshold=10 --verbosity=info
```

# Testing with opam health check

Clone opam health check from this [fork](https://github.com/mtelvers/opam-health-check/tree/macos-v2)

```shell=
git clone https://github.com/mtelvers/opam-health-check/tree/macos-v2 
cd 
workdir=~/opam-health-check-data
ocluster_cap="$HOME/ocluster.cap"
dune exec -- opam-health-serve --connect "$ocluster_cap" "$workdir"
```

Update `~/opam-health-check-data/config.yaml` as follows and restart opam-health-serve

```
name: default
port: 8080
public-url: http://ocamllabs
admin-port: 9999
auto-run-interval: 48
processes: 200
enable-dune-cache: false
enable-logs-compression: true
default-repository: ocaml/opam-repository
extra-repositories: []
with-test: false
with-lower-bound: false
list-command: opam list --available --installable --short --all-versions z*
extra-command:
platform:
  os: macos
  arch: x86_64
  custom-pool:
  distribution: homebrew
  image: ocaml/opam:debian-unstable@sha256:a13c01aab19715953d47831effb2beb0ac90dc98c13b216893db2550799e3b9f
ocaml-switches:
- "414": ocaml-base-compiler.4.14.0
slack-webhooks: []
```

```shell=
workdir=~/opam-health-check-data
opam-health-check init --from-local-workdir "$workdir"
```



# Random fault finding code

```
rsync -aHq /Volumes/rsync/result/4b6c406d6a55ea19a1c0ec88f10666fac3344fcf7af39915537f3222d4670165/ /Volumes/rsync/result-tmp/9c9157825ad0b3aa5b879787ec1b91507451f85b9fc3aab7b31d265eb531c88c
sudo dscl . list /Users
dscl . -create /Users/mac1000 NFSHomeDirectory /Users/mac1000
ln -Fhs /Users/mac1000 /Users/administrator/scoreboard/1000
mkdir -p /tmp/obuilder-empty
sudo rsync -aHq --delete /tmp/obuilder-empty/ /Users/mac1000/
sudo rsync -aHq /Volumes/rsync/result-tmp/9c9157825ad0b3aa5b879787ec1b91507451f85b9fc3aab7b31d265eb531c88c/rootfs/ /Users/mac1000
sudo chown -R 1000:1000 /Users/mac1000
sudo chmod -R g+w /Users/mac1000
sudo obuilderfs /Users/administrator/scoreboard /usr/local -o allow_other
                                             
sudo -u mac1000 -i getconf DARWIN_USER_TEMP_DIR
sudo su -l mac1000 -c -- source ~/.obuilder_profile.sh && env 'TMPDIR=/var/folders/26/k5tgmc855q1956nwspjdv9sh0000z8/T/' 'OPAMPRECISETRACKING=1' 'OPAMSOLVERTIMEOUT=500' 'OPAMERRLOGLEN=0' 'OPAMDOWNLOADJOBS=1' $0 $@

sed -i.back 's/macos-homebrew-ocaml-4.14/mac1000/g' .opam/opam-init/*

/Users/mac1000/.opam/default/.opam-switch/config/ocaml.config 

opam install ocamlfind

/bin/bash -c opam update --depexts

rsync -aHq --delete /Users/mac1000/ /Volumes/rsync/result-tmp/9c9157825ad0b3aa5b879787ec1b91507451f85b9fc3aab7b31d265eb531c88c/rootfs
umount -f /usr/local
/bin/bash -c opam update --depexts failed with exit status 99
```




# Update a worker

```shell=

for a in $(sudo dscl . list /Users | grep mac) ; do echo $a ; sudo rm -rf /Users/$a ; sudo dscl . -delete /Users/$a ; done
sudo rm -rf /Users/macos-homebrew-ocaml-4.14-original
sudo mv /Users/macos-homebrew-ocaml-4.14 /Users/macos-homebrew-ocaml-4.14-original
mkdir ~/scoreboard
cd /Users/administrator/macos-infra/scripts
sudo ./new-user.sh 1000 mac1000
ln -Fhs /Users/mac1000 ~/scoreboard/1000
sudo obuilderfs ~/scoreboard /usr/local -o allow_other
cp macos-homebrew-ocaml.sh /Users/mac1000
sudo chown -R mac1000:admin /Users/mac1000
sudo -u mac1000 -i
sed -i '' "s/macos-homebrew-ocaml-4.14/mac1000/g" macos-homebrew-ocaml.sh
sed -i '' "s/macos-homebrew-\*/mac1000/g" macos-homebrew-ocaml.sh
sudo chown -R mac1000:admin /Users/mac1000
./macos-homebrew-ocaml.sh
exit
sudo dscl . -delete /Users/mac1000
sudo umount /usr/local
sudo mv /Users/mac1000 /Users/macos-homebrew-ocaml-4.14
sudo rm -rf /Volumes/rsync

# A typical command line

cd ~/ocluster
eval $(opam env)
sudo -E DYLD_FALLBACK_LIBRARY_PATH=/Users/administrator/lib dune exec --profile release -- ocluster-worker --connect ~/pool-macos-x86_64.cap \
  --uid=1000 --fallback=/Users/administrator/lib --scoreboard=/Users/administrator/scoreboard \
  --obuilder-store=rsync:/Volumes/rsync --state-dir=/var/lib/ocluster-worker \
  --name=`hostname` --capacity=1 --obuilder-prune-threshold=10 --verbosity=info

```


