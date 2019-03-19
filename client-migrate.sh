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
newmaster=$nmipaip
userpw=$3

remote_cli()
{
	echo -e "Via SSH to ${cli} as ${USER} about to try: $@" 1>&2
        ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 ${USER}@${cli} -- $@
}

if ! remote_cli true 2>/dev/null ; then
	(>&2 echo "\"ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 \${USER}@${cli} true\" failed")
	exit 1
fi

sudo_remote_cli()
{
	echo -e "sudo Via SSH to ${cli} as ${USER} about to try: sudo $@" 1>&2
        (2>/dev/null remote_cli echo ${userpw} \| sudo -p "''" -S $@)
}

remote_nmipa()
{
	echo -e "nmi Via SSH to ${newmaster} as ${USER} about to try: $@" 1>&2
        ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 ${USER}@${nmipaip} -- $@
}

if ! remote_nmipa true 2>/dev/null ; then
	(>&2 echo "\"ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 \${USER}@${nmipaip} true\" failed")
	exit 1
fi

sudo_remote_nmipa()
{
	echo -e "sudo nmi Via SSH to ${newmaster} as ${USER} about to try: sudo $@" 1>&2
        (2>/dev/null remote_nmipa echo ${userpw} \| sudo -p "''" -S $@)
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
	localpkgrefreshed=true
fi

oldkrb="$(sudo nmap -n -Pn -sU -p U:88 -oG - $(dig +short -t srv _kerberos._udp.${bzn}. | awk '{ print $NF}') | awk '/Ports: 88\/open/ { print $2 } { next }')"

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

if remote_nmipa type nmap >/dev/null 2>&1 ; then
	nmikeepnmap=yes
else
	nmikeepnmap=no
	sudo_remote_nmipa yum makecache fast
	nmipkgrefreshed=true
	sudo_remote_nmipa yum -y --setopt=obsoletes=0 install epel-release
	sudo_remote_nmipa yum makecache fast
	sudo_remote_nmipa yum -y --setopt=multilib_policy=best --exclude='*.i686' install nmap
fi

newkrb="$(sudo_remote_nmipa nmap -n -Pn -sU -p U:88 -oG - $(remote_nmipa dig +short -t srv _kerberos._udp.${bzn}. | awk '{ print $NF}') | awk '/Ports: 88\/open/ { print $2 } { next }')"
newdns2="$(echo $newkrb | head -n 2)"

if [[ $nmikeepnmap == "no" ]] ; then
	sudo_remote_nmipa yum -y autoremove nmap
fi

if remote_cli type wget >/dev/null 2>&1 ; then
	keepwget=yes
else
	keepwget=no
fi

case ${RCOS}:${RCVER} in
	Ubuntu:* )
		pkgmeth=apt
		if remote_cli type resolvconf >/dev/null 2>&1 ; then
			resolvcmeth=resolconf
			remote_cli test -s /run/resolvconf/resolv.conf && sudo_remote_cli bash -c \"cd /etc \; rm -f resolv.conf \; ln -s ../run/resolvconf/resolv.conf resolv.conf\"
			touch /tmp/resolv.$$ ; chmod go-rwx /tmp/resolv.$$
			remote_cli cat /run/resolvconf/resolv.conf | grep -vE '^#?nameserver' > /tmp/resolv.$$
			for i in ${newdns2} ; do
				sed -i -e '/^search /i\
nameserver '"$i"'

' /tmp/resolv.$$
			done
			cat /tmp/resolv.$$ | remote_cli cat \> /tmp/resolv.$$
			sudo_remote_cli bash -c \"cat /tmp/resolv.$$ \> /run/resolvconf/resolv.conf \; rm -f /tmp/resolv.$$\"
			rm -f /tmp/resolv.$$
			remote_cli rm -f /tmp/resolv.$$
		else
			resolvcmeth=unknown
			(>&2 echo "No resolvconf on this ${RCOS} ${RCVER} install")
			exit 1
		fi
		if [[ $keepwget == "no" ]] ; then
			if ! [[ $pkgrefreshed == "true" ]] ; then
				sudo_remote_cli apt-get -y update >/dev/null 2>&1
				pkgrefreshed=true
			fi
			sudo_remote_cli apt-get -y install wget
		fi
		;;
	Centos:* )
		pkgmeth=yum
		if remote_cli type nmcli >/dev/null 2>&1 ; then
			resolvcmeth=nmcli
			(>&2 echo "TBD")
			exit 1
		else
			resolvcmeth=unknown
			(>&2 echo "No nmcli on this ${RCOS} ${RCVER} install")
			exit 1
		fi
		if [[ $keepwget == "no" ]] ; then
			if ! [[ $pkgrefreshed == "true" ]] ; then
				sudo_remote_cli yum makecache fast >/dev/null 2>&1
				pkgrefreshed=true
			fi
			sudo_remote_cli yum -y --setopt=multilib_policy=best --exclude='*.i686' install wget
		fi
		;;
	* )
		pkgmeth=unknown
		resolvcmeth=unknown
		(>&2 echo "No support for ${RCOS} ${RCVER}")
		exit 1
		;;
esac

sudo_remote_cli wget -O /etc/ipa/ca.crt http://${newmaster}/ipa/config/ca.crt

if [[ $keepwget == "no" ]] ; then
	case ${RCOS}:${RCVER} in
		Ubuntu:* )
			sudo_remote_cli apt-get -y --purge remove wget
			sudo_remote_cli apt-get -y autoremove
			;;
		Centos:* )
			sudo_remote_cli yum -y autoremove wget
			;;
		* )
			(>&2 echo "No support for ${OS} ${VER}")
			exit 1
			;;
	esac
fi

remote_cli kdestroy
sudo_remote_cli kdestroy
sudo_remote_cli ipa-rmkeytab -k /etc/krb5.keytab -r ${brealm} 
sudo_remote_cli klist -k /etc/krb5.keytab
echo -e "sudo Via SSH to ${cli} as ${USER} about to try: sudo bash -c \"echo YOURPASSWORD | kinit ${USER}\""
sudo_remote_cli bash -c \"echo ${userpw} \| kinit ${USER}\" 2>/dev/null
sudo_remote_cli klist
sudo_remote_cli ipa-getkeytab -s ${newmaster} -p host/${fqclient} -k /etc/krb5.keytab
sudo_remote_cli klist -k /etc/krb5.keytab



echo Debug: hit the bottom ; exit 0

