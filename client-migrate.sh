#!/bin/bash

if [ -f /etc/os-release ]; then
	# freedesktop.org and systemd
	. /etc/os-release
	OS=$NAME
	VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
	# linuxbase.org
	OS=$(lsb_release -si)
	VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
	# For some versions of Debian/Ubuntu without lsb_release command
	. /etc/lsb-release
	OS=$DISTRIB_ID
	VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
	# Older Debian/Ubuntu/etc.
	OS=Debian
	VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
	# Older SuSE/etc.
	...
elif [ -f /etc/redhat-release ]; then
	# Older Red Hat, CentOS, etc.
	...
else
	# Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
	OS=$(uname -s)
	VER=$(uname -r)
fi

if type systemctl >/dev/null 2>&1 ; then
	initutil=systemctl
else
	initutil=initctl
fi

if [[ "$(id -urn)" == "root" ]] ; then
	(>&2 echo "Do not run as root")
	exit 1
fi

if [[ $# -ne 3 ]] ; then
        (>&2 echo "$0 usage - three arguments:")
        (>&2 echo -e "\tIPv4 address of the new master XMLRPC FreeIPA server")
        (>&2 echo -e "\tThe hostname of client you wish to migrate")
        (>&2 echo -e "\tYour user password for kinit etc")
        (>&2 echo "")
        (>&2 echo "So do not run as root. Invoke from a workstation pointing at the old infrastructure")
        exit 1
fi

if ! echo $1 | grep -Eq '^[0-9]+(\.[0-9]+){3}' ; then
        (>&2 echo "\"${1}\" does not look like an IPv4 address")
        exit 1
fi

cli=$2
nmipaip=$1
userpw=$3

if ! ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 ${USER}@${cli} true 2>/dev/null ; then
	(>&2 echo "\"ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 \${USER}@${cli} true\" failed")
	exit 1
fi

remote_cli()
{
        ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 ${USER}@${cli} -- $@
}

sudo_remote_cli()
{
        remote_cli echo ${userpw} \| sudo -p "''" -S $@
}

remote_nmipa()
{
        ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 ${USER}@${nmipaip} -- $@
}

remote_cli hostname
sudo_remote_cli id

echo Debug: hit the bottom
