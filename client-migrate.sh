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

remote_cli()
{
        ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 ${USER}@${cli} -- $@
}

if ! remote_cli true 2>/dev/null ; then
	(>&2 echo "\"ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 \${USER}@${cli} true\" failed")
	exit 1
fi

sudo_remote_cli()
{
        remote_cli echo ${userpw} \| sudo -p "''" -S $@
}

remote_nmipa()
{
        ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 ${USER}@${nmipaip} -- $@
}

if ! remote_nmipa true 2>/dev/null ; then
	(>&2 echo "\"ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 \${USER}@${nmipaip} true\" failed")
	exit 1
fi

sudo_remote_nmipa()
{
        remote_nmipa echo ${userpw} \| sudo -p "''" -S $@
}

fqclient=$(remote_cli hostname --fqdn)
newmaster=$(remote_nmipa hostname --fqdn)
bzn=$(echo ${newmaster} | sed -e 's/^\([^.]*\)\.\(.*\)$/\2/')
brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$(echo $brealm | tr '.' '-')
bdcn=$(echo $bzn | sed -e 's/^/dc=/' -e 's/\./,dc=/g')

if remote_cli test -f /etc/os-release ; then
        # freedesktop.org and systemd
        . /etc/os-release
        RCOS=$NAME
        RCVER=$VERSION_ID
elif remote_cli type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        RCOS=$(lsb_release -si)
        RCVER=$(lsb_release -sr)
elif remote_cli test -f /etc/lsb-release; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        RCOS=$DISTRIB_ID
        RCVER=$DISTRIB_RELEASE
elif remote_cli test -f /etc/debian_version; then
        # Older Debian/Ubuntu/etc.
        RCOS=Debian
        RCVER=$(cat /etc/debian_version)
elif remote_cli test -f /etc/SuSe-release; then
        # Older SuSE/etc.
        ...
elif remote_cli test -f /etc/redhat-release; then
        # Older Red Hat, CentOS, etc.
        ...
else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        RCOS=$(remote_cli uname -s)
        RCVER=$(remote_cli uname -r)
fi

if remote_cli type systemctl >/dev/null 2>&1 ; then
	rinitutil=systemctl
elif remote_cli type initctl>/dev/null 2>&1 ; then
	rinitutil=initctl
else
	rinitutil=unknown
	(>&2 echo "Don't recognise the init system on this ${RCOS} ${RCVER} install")
	exit 1
fi

if type nmap >/dev/null 2>&1 ; then
	localkeepnmap=yes
else
	localkeepnmap=no
	case ${OS}:${VER} in
		Ubuntu:* )
			sudo apt-get -y update >/dev/null 2>&1
			sudo apt-get -y install nmap
			;;
		Centos:* )
			sudo yum makecache fast
			sudo yum -y --setopt=obsoletes=0 install epel-release
			sudo yum makecache fast
			sudo yum -y --setopt=multilib_policy=best --exclude='*.i686' install nmap
			;;
		* )
			(>&2 echo "No support for ${OS} ${VER}")
			exit 1
			;;
	esac
fi

oldkrb=$(sudo nmap -n -Pn -sU -p U:88 -oG - $(dig +short -t srv _kerberos._udp.${bzn}. | awk '{ print $NF}') | awk '/Ports: 88\/open/ { print $2 } { next }')

if [[ $localkeepnmap == "no" ]] ; then
	case ${OS}:${VER} in
		Ubuntu:* )
			sudo apt-get -y --purge remove nmap
			sudo apt-get -y autoremove
			;;
		Centos:* )
			sudo yum -y autoremove nmap
			;;
		* )
			(>&2 echo "No support for ${OS} ${VER}")
			exit 1
			;;
	esac
fi

if ! remote_nmipa type nmap >/dev/null 2>&1 ; then
	sudo_remote_nmipa yum makecache fast
	sudo_remote_nmipa yum -y --setopt=obsoletes=0 install epel-release
	sudo_remote_nmipa yum makecache fast
	sudo_remote_nmipa yum -y --setopt=multilib_policy=best --exclude='*.i686' install nmap
fi

newkrb=$(sudo_remote_nmipa nmap -n -Pn -sU -p U:88 -oG - $(remote_nmipa dig +short -t srv _kerberos._udp.${bzn}. | awk '{ print $NF}') | awk '/Ports: 88\/open/ { print $2 } { next }')

case ${RCOS}:${RCVER} in
	Ubuntu:* )
		pkgmeth=apt
		if remote_cli type resolvconf >/dev/null 2>&1 ; then
			resolvcmeth=resolconf
		else
			resolvcmeth=unknown
			(>&2 echo "No resolvconf on this ${RCOS} ${RCVER} install")
		fi
		;;
	Centos:* )
		pkgmeth=yum
		if remote_cli type nmcli >/dev/null 2>&1 ; then
			resolvcmeth=nmcli
		else
			resolvcmeth=unknown
			(>&2 echo "No nmcli on this ${RCOS} ${RCVER} install")
		fi
		;;
	* )
		pkgmeth=unknown
		resolvcmeth=unknown
		(>&2 echo "No support for ${RCOS} ${RCVER}")
		exit 1
		;;
esac



echo Debug: hit the bottom ; exit 0

#remote_cli echo ${userpw} \| kinit
