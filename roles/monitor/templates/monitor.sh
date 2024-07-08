#!/bin/sh

if test -f {{ ansible_env.HOME }}/ocluster.log ; then
	kc=$(tail {{ ansible_env.HOME }}/ocluster.log | grep pkill | wc -l)
	if [ $kc -eq 10 ] ; then
		rm -f {{ ansible_env.HOME }}/ocluster.log
		date
		sync
		sudo reboot
	fi
fi
