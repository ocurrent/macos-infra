#!/bin/sh

if test -f {{ ansible_env.HOME }}/ocluster.log ; then
	kc=$(tail {{ ansible_env.HOME }}/ocluster.log | grep pkill | wc -l)
	if [ $kc -eq 10 ] ; then
		mv -f {{ ansible_env.HOME }}/ocluster.log {{ ansible_env.HOME }}/ocluster.old
		sync
		sudo reboot
	fi
fi
