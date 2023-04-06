#!/bin/bash

case "$1" in
  backup)
    mkfile 10G /Volumes/backup.zfs
    zpool create backup /Volumes/backup.zfs
    zfs send -R obuilder/cache/c-homebrew@snap | zfs receive -d backup/cache/c-homebrew
    zfs send -R obuilder/cache/c-opam-archives@snap | zfs receive -d backup/cache/c-opam-archives
  ;;

  restore)
    zfs send -R backup/cache/c-homebrew@snap | zfs receive -d obuilder/cache/c-homebrew
    zfs send -R backup/cache/c-opam-archives@snap | zfs receive -d obuilder/cache/c-opam-archives
    zfs destroy -f backup
    rm /Volumes/backup.zfs
  ;;

  *)
    echo "Usage $0 backup|restore"
  ;;
esac
