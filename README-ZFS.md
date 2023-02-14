
# ZFS on macOS architecture overview

A macOS base image consists of a user home directory and a brew installation directory.  Typically, this is `/Users/mac1000` and either `/usr/local` (on Intel silicon) or `/opt/homebrew` (on Apple silicon).

An Obuilder job consists of a number of steps within the specification file.  Each job step is converted into a hash which allows steps to be cached and referenced.  Each step is stored on a `results` ZFS volume which contains the log of STDOUT which was written during execution.  ZFS subvolumes named `home` and `brew` store the state of the the home directory and brew installation for each step.  These volumes have snapshots `@snap` in place which are cloned for the next step.

When a worker is first started, it will create a recursive clone of the base image pool, then working in a clone of that pool, the first step of the job spec will be applied.  Perhaps installing Opam packages.  On successful completion, a recursive snapshot will be taken ready to be cloned for the next step.  If the job fails, the clone will be discarded.

A typical job would run as follows:

```
# Create a results folder based upon the base image name, say `macos-homebrew-ocaml-5.0`
zfs create obuilder/result/645c2ef2f88fa001579e248001924f94ff36415fd9c5ec359cc6a6e8cd432525

# Try to open the snapshot which would indicate that the job had completed (so this will fail for now)
zfs mount obuilder/result/645c2ef2f88fa001579e248001924f94ff36415fd9c5ec359cc6a6e8cd432525@snap

# Clone the base image into the results pool
zfs clone -o mountpoint=none obuilder/base-image/macos-homebrew-ocaml-5.0/home@snap obuilder/result/645c2ef2f88fa001579e248001924f94ff36415fd9c5ec359cc6a6e8cd432525/home
zfs clone -o mountpoint=none obuilder/base-image/macos-homebrew-ocaml-5.0/brew@snap obuilder/result/645c2ef2f88fa001579e248001924f94ff36415fd9c5ec359cc6a6e8cd432525/brew

# Take a snapshot of the results
zfs snapshot -r obuilder/result/645c2ef2f88fa001579e248001924f94ff36415fd9c5ec359cc6a6e8cd432525@snap

# Move on to the first step of the job specification which relies on the hash of the base image

# Try to open the snapshot which would indicate that the job had completed (this now succeeds)
zfs mount obuilder/result/645c2ef2f88fa001579e248001924f94ff36415fd9c5ec359cc6a6e8cd432525@snap

# Loop start

# Try to open the snapshot representing the next step of the job (which will fail as it has not been run)
zfs mount obuilder/result/a5f372ff59673df9d9209889009b6b09f252fbea3dea15bf642833ee010f264c@snap

# Clone the base image snapshot into a new results pool
zfs clone obuilder/result/645c2ef2f88fa001579e248001924f94ff36415fd9c5ec359cc6a6e8cd432525@snap obuilder/result/a5f372ff59673df9d9209889009b6b09f252fbea3dea15bf642833ee010f264c
zfs clone -o mountpoint=none obuilder/result/645c2ef2f88fa001579e248001924f94ff36415fd9c5ec359cc6a6e8cd432525/home@snap obuilder/result/a5f372ff59673df9d9209889009b6b09f252fbea3dea15bf642833ee010f264c/home
zfs clone -o mountpoint=none obuilder/result/645c2ef2f88fa001579e248001924f94ff36415fd9c5ec359cc6a6e8cd432525/brew@snap obuilder/result/a5f372ff59673df9d9209889009b6b09f252fbea3dea15bf642833ee010f264c/brew

# Mount the results pool over the homebrew and user home directory
zfs set mountpoint=/Users/mac1000 obuilder/result/a5f372ff59673df9d9209889009b6b09f252fbea3dea15bf642833ee010f264c/home
zfs set mountpoint=/usr/local obuilder/result/a5f372ff59673df9d9209889009b6b09f252fbea3dea15bf642833ee010f264c/brew

# Execute the job specification step, perhaps something like `ln -f ~/local/bin/opam-2.1 ~/local/bin/opam`

# Unmount the resulting pools (we won't need them again)
zfs set mountpoint=none obuilder/result/a5f372ff59673df9d9209889009b6b09f252fbea3dea15bf642833ee010f264c/home
zfs set mountpoint=none obuilder/result/a5f372ff59673df9d9209889009b6b09f252fbea3dea15bf642833ee010f264c/brew

# Create a recursive snapshot of the results pool
zfs snapshot -r obuilder/result/a5f372ff59673df9d9209889009b6b09f252fbea3dea15bf642833ee010f264c@snap

# Loop
```

The log file for a job is split across the multiple result snapshots so when a job runs there may be a dozen or more snapshot which are accessed to read the logs up to this point.  The file is called `log` and is located in `<ZFS pool>/results/<SHA>@snap/log`

# Deploy macOS worker with ZFS

## Clear any existing installation

Remove macFuse via System Preferences.

If you have a previous deployment or are unsure of the state of your Mac, then try this very dangerous playbook which removes the following:

- ~/ocluster
- ~/lib
- ~/scoreboard
- ~/.opam
- /Users/mac1000
- /var/lib/ocluster-worker
- /Volumes/rsync
- **Homebrew** (either /usr/local/ or /opt/homebrew)

Run it as follows

```
ansible-playbook -i hosts --limit i7-worker-04.macos.ci.dev wipe-mac.yml
```

## Pre-requisites

The Ansible playbook can be used to deploy Mac workers.  The following pre-requisites must be satisfied:

- Security & Privacy \ General \ Require Password -- disables screen saver
- Sharing \ Screen sharing -- enables VNC
- Sharing \ Remote login -- enables SSH.  Also select the “Allow full disk access for remote users” checkbox.
- Energy Saver \ Prevent your Mac from automatically sleeping
- Energy Saver \ Start up automatically after power failure
- Install Apple Developer Command line tools `xcode-select --install`
- Turn off SIP by entering Recovery Mode (Intel: Command-R; M1: hold power button) `csrutil disable`
- Install [OpenZFS on OSX](https://openzfsonosx.org/wiki/Downloads) which requires approval via System Preferences and sometimes a reboot of the system.
- Add your ssh key to the `~/.ssh/authorized_keys` and update your `~/.ssh/config` so that you can SSH to the mac without prompting for a username:

```
Host *
	User administrator
```

> Homebrew is not a pre-requisite as it is installed by the playbook

Unlike previous deployments, the recommendation is to have the Mac at the login screen, not sign in at the desktop.  This means that `Finder` will not be running which reduces the CPU load.

## Configure a ZFS Pool

You must now configure a ZFS pool for Obuilder to use.

I am using a virtual machine on my MacPro so I have just added a second hard disk.  This is visible via `diskutil list` and a ZFS pool can be created like this:

```sh=
sudo zpool create obuilder /dev/disk0
sudo zfs set atime=off obuilder
sudo zfs set checksum=off obuilder
```

> `checksum=off` is not the recommended configuration for a production ZFS pool but it does use less CPU.

On a physical Mac, it may be easiest to create an empty file and use that for the ZFS pool.

```sh=
sudo mkfile 20G /Volumes/zfs
sudo zpool create obuilder /Volumes/zfs
sudo zfs set atime=off obuilder
sudo zfs set checksum=off obuilder
```

The result should be visble via `zpool`:

```sh=
% zpool list
NAME       SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
obuilder  49.5G  1.88M  49.5G        -         -     0%     0%  1.00x    ONLINE  -
```

## Deploying the worker

Run the playbook as below  I have used `--limit` to target a single worker.

```sh=
ansible-playbook -i hosts --limit i7-worker-01 playbook.yml
```

## ZFS state

Before any job are performed this will be the state of the ZFS pool:

```
% zfs list
NAME                                                 USED  AVAIL  REFER  MOUNTPOINT
obuilder                                            2.63G  45.3G  1.69M  /Volumes/obuilder
obuilder/base-image                                 2.63G  45.3G  1.69M  /Volumes/obuilder/base-image
obuilder/base-image/busybox                         5.05M  45.3G  1.68M  /Volumes/obuilder/base-image/busybox
obuilder/base-image/busybox/brew                    1.68M  45.3G  1.68M  none
obuilder/base-image/busybox/home                    1.69M  45.3G  1.69M  none
obuilder/base-image/macos-homebrew-ocaml-4.14       1.30G  45.3G  1.68M  /Volumes/obuilder/base-image/macos-homebrew-ocaml-4.14
obuilder/base-image/macos-homebrew-ocaml-4.14/brew   715M  45.3G   715M  none
obuilder/base-image/macos-homebrew-ocaml-4.14/home   613M  45.3G   613M  none
obuilder/base-image/macos-homebrew-ocaml-5.0        1.32G  45.3G  1.68M  /Volumes/obuilder/base-image/macos-homebrew-ocaml-5.0
obuilder/base-image/macos-homebrew-ocaml-5.0/brew    716M  45.3G   716M  none
obuilder/base-image/macos-homebrew-ocaml-5.0/home    636M  45.3G   636M  none
```

## Starting and Stopping

Ocluster-worker is run as a launch daemon.

The Ansible scripts create a system wide service definition `.plist` in `/Library/LaunchDaemons/com.tarides.ocluster.worker.plist`.

To start the service run

```shell=
sudo launchctl load /Library/LaunchDaemons/com.tarides.ocluster.worker.plist
```

To stop the service run

```shell=
sudo launchctl unload /Library/LaunchDaemons/com.tarides.ocluster.worker.plist
```

STDOUT and STDERR are redirected to `~/ocluster.log`

