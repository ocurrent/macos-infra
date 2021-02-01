Setup Scripts
=============

The MacOS infrastructure works by taking an Obuilder spec such as: 

```
((from "macos-homebrew-ocaml-4.11") ...)
```

And copying a "template user" of the same name (i.e. `/Users/macos-homebrew-ocaml-4.11`) into the current builder's home directory (a.k.a a ZFS snapshot). 

There is no magic that happens here, for Linux the "magic" is pulling a docker image from docker hub and making that the root filesystem. For MacOS, we are not so fortunate. Instead we're relying on the infrastructure managers to set up a worker with the template users that are needed for that system.

As such this folder, `scripts`, contains simple bash scripts for initialising a template user for a MacOS builder.

 - `new-user.sh` expects two things -- a `UID` and a `USERNAME` so something like `701 macos-homebrew-ocaml-4.11` should suffice. This will create a new user with uid `701` and an initial home directory `/Users/macos-homebrew-ocaml-4.11`. In order for homebrew to install you must be an admin user so this user is one. 
 - `macos-homebrew-ocaml.sh` is to be run in the template user whilst the FUSE filesystem is running. Once you have your user created with `new-user.sh` you will want to `cp ./scripts/macos-homebrew-ocaml.sh /Users/<USERNAME>` and then (with FUSE running) run the script with `sudo -u <USERNAME> -i ./macos-homebrew-ocaml.sh` (note this takes a while and can be fragile).
   + This scripts installs a modified homebrew and `opam` from the `2.0` branch and `master`.
 - `clean-up.sh` deletes the user you specify (you will likely also want to delete their home directory afterwards too).