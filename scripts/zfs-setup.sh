sudo zpool create obuilder /dev/disk0s3
sudo zfs set atime=off obuilder
sudo zfs set checksum=off obuilder
sudo zfs set compression=off obuilder
