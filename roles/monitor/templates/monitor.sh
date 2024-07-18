#!/bin/sh

if test -f {{ ansible_env.HOME }}/ocluster.log ; then
	kc=$(tail {{ ansible_env.HOME }}/ocluster.log | grep pkill | wc -l)
	if [ $kc -eq 10 ] ; then
		mv -f {{ ansible_env.HOME }}/ocluster.log {{ ansible_env.HOME }}/ocluster.old
		msg="Rebooting $(uname -n)\n$(ps -j -U 1000)"
		curl -H "Content-type: application/json" -d '{ "text": "'${msg}'"  }' -X POST {{ slack_hook_url }}
		sync
		sudo reboot
	fi
fi
