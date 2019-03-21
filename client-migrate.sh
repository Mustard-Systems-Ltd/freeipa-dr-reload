#!/bin/bash
debugecho=true

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
	[[ "${debugecho}" == "true" ]] && echo -e "Via SSH to ${cli} as ${USER} about to try: $@" 1>&2
        ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 ${USER}@${cli} -- $@
}

if ! remote_cli true 2>/dev/null ; then
	(>&2 echo "\"ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 \${USER}@${cli} true\" failed")
	exit 1
fi

urhn="$(remote_cli hostname | sed -e 's/^\([^.]*\)\..*$/\1/')"
ucli="$(echo ${cli} | sed -e 's/^\([^.]*\)\..*$/\1/')"
if [[ "${ucli}" != "${urhn}" ]] ; then
	(>&2 echo "Remote hostname \"${urhn}\" is dissimilar to \"${ucli}\" hostname argument supplied. Aborting!")
	exit 1
fi

sudo_remote_cli()
{
	[[ "${debugecho}" == "true" ]] && echo -e "Via SSH to ${cli} as ${USER} about to try: sudo $@" 1>&2
        (2>/dev/null remote_cli echo ${userpw} \| sudo -p "''" -S $@)
}

remote_nmipa()
{
	[[ "${debugecho}" == "true" ]] && echo -e "Via SSH to ${newmaster} as ${USER} about to try: $@" 1>&2
        ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 ${USER}@${nmipaip} -- $@
}

if ! remote_nmipa true 2>/dev/null ; then
	(>&2 echo "\"ssh -o PreferredAuthentications=publickey -o ConnectTimeout=8 \${USER}@${nmipaip} true\" failed")
	exit 1
fi

sudo_remote_nmipa()
{
	[[ "${debugecho}" == "true" ]] && echo -e "Via SSH to ${newmaster} as ${USER} about to try: sudo $@" 1>&2
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

newkrb="$(sudo_remote_nmipa nmap -n -Pn -sU -p U:88 -oG - $(remote_nmipa dig @127.0.0.1 +short -t srv _kerberos._udp.${bzn}. | awk '{ print $NF}') | awk '/Ports: 88\/open/ { print $2 } { next }')"
upgrep=""
for i in $newkrb ; do
	upgrep="${upgrep}|$(remote_nmipa dig @127.0.0.1 +short -x ${i} | sed -e 's/\..*$//')"
done
upgrep="$(echo ${upgrep} | sed -e 's/^|//')"
( remote_nmipa dig @127.0.0.1 +short -t srv _kerberos._udp.${bzn}. | awk '$1 == 0 && $4 ~ /'"${upgrep}"'/ { print $4 }'  ; remote_nmipa dig @127.0.0.1 +short -t srv _kerberos._udp.${bzn}. | awk '$1 > 0 && $4 ~ /'"${upgrep}"'/ { print $4 }' ) > /tmp/orderedcand.$$
newdns2=""
for i in $(head -n 2 /tmp/orderedcand.$$) ; do
	newdns2="${newdns2} $(remote_nmipa dig @127.0.0.1 +short $i)"
done
rm -f /tmp/orderedndnscand.$$

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

touch /tmp/sssdsed.$$ ; chmod go-rwx /tmp/sssdsed.$$
echo '
/^ipa_server/s/^.*$/ipa_server = _srv_/
' > /tmp/sssdsed.$$
#[[ "${debugecho}" == "true" ]] && cat /tmp/sssdsed.$$
remote_cli touch /tmp/sssdsed.$$ \; chmod go-rwx /tmp/sssdsed.$$
cat /tmp/sssdsed.$$ | remote_cli cat \> /tmp/sssdsed.$$
rm -f /tmp/sssdsed.$$
#[[ "${debugecho}" == "true" ]] && sudo_remote_cli cat /etc/sssd/sssd.conf
sudo_remote_cli sed -i -f /tmp/sssdsed.$$ /etc/sssd/sssd.conf \; rm -f /tmp/sssdsed.$$
[[ "${debugecho}" == "true" ]] && sudo_remote_cli cat /etc/sssd/sssd.conf

touch /tmp/krb5sed.$$ ; chmod go-rwx /tmp/krb5sed.$$
echo '
s/^\(\s*\)dns_lookup_kdc = .*/\1dns_lookup_kdc = true/
/^\s*'"${brealm}"' = {/,/^\s*}\s*$/{
/^\s*#*kdc = /d
/^\s*#*master_kdc = /d
/^\s*#*admin_server = /d
/^\s*#*default_domain = /d
/^\s*$/d
s/^\(\s*\)pkinit_anchors = \(.*\)$/\1#kdc = ???.'"${bzn}"'\n\1#master_kdc = '"${newmaster}"':88\n\1admin_server = '"${newmaster}"':749\n\1default_domain = '"${bzn}"'\n\1pkinit_anchors = \2\n/
}
' > /tmp/krb5sed.$$
#[[ "${debugecho}" == "true" ]] && cat /tmp/krb5sed.$$
remote_cli touch /tmp/krb5sed.$$ \; chmod go-rwx /tmp/krb5sed.$$
cat /tmp/krb5sed.$$ | remote_cli cat \> /tmp/krb5sed.$$
rm -f /tmp/krb5sed.$$
#[[ "${debugecho}" == "true" ]] && sudo_remote_cli cat /etc/krb5.conf
sudo_remote_cli sed -i -f /tmp/krb5sed.$$ /etc/krb5.conf \; rm -f /tmp/krb5sed.$$
[[ "${debugecho}" == "true" ]] && sudo_remote_cli cat /etc/krb5.conf

touch /tmp/ipadefdsed.$$ ; chmod go-rwx /tmp/ipadefdsed.$$
echo '
s/^#*server = .*$/#server = ???.'"${bzn}"'/
s/^xmlrpc_uri = .*$/xmlrpc_uri = https:\/\/'"${newmaster}"'\/ipa\/xml/
' > /tmp/ipadefdsed.$$
[[ "${debugecho}" == "true" ]] && cat /tmp/ipadefdsed.$$
remote_cli touch /tmp/ipadefdsed.$$ \; chmod go-rwx /tmp/ipadefdsed.$$
cat /tmp/ipadefdsed.$$ | remote_cli cat \> /tmp/ipadefdsed.$$
rm -f /tmp/ipadefdsed.$$
[[ "${debugecho}" == "true" ]] && sudo_remote_cli cat /etc/ipa/default.conf
sudo_remote_cli sed -i -f /tmp/ipadefdsed.$$ /etc/ipa/default.conf \; rm -f /tmp/ipadefdsed.$$
[[ "${debugecho}" == "true" ]] && sudo_remote_cli cat /etc/ipa/default.conf

remote_cli kdestroy
sudo_remote_cli kdestroy
sudo_remote_cli ipa-rmkeytab -k /etc/krb5.keytab -r ${brealm} 
[[ "${debugecho}" == "true" ]] && sudo_remote_cli klist -k /etc/krb5.keytab
echo -e "Via SSH to ${cli} as ${USER} about to try: sudo bash -c \"echo YOURPASSWORD | kinit ${USER}\""
sudo_remote_cli bash -c \"echo ${userpw} \| kinit ${USER}\" 2>/dev/null
[[ "${debugecho}" == "true" ]] && sudo_remote_cli klist
sudo_remote_cli ipa-getkeytab -s ${newmaster} -p host/${fqclient} -k /etc/krb5.keytab
[[ "${debugecho}" == "true" ]] && sudo_remote_cli klist -k /etc/krb5.keytab

case $rinitutil in
	systemctl )
		sudo_remote_cli bash -c \"systemctl stop sssd.service \; find /var/lib/sss/db -type f -print0 \| xargs -r0 rm -f \; systemctl start sssd.service\"
	;;
	initctl )
		sudo_remote_cli bash -c \"initctl stop sssd.service \; find /var/lib/sss/db -type f -print0 \| xargs -r0 rm -f \; initctl start sssd.service\"
	;;
	* )
		(>&2 echo "\$rinitutil undefined")
		exit 1
	;;
esac

[[ "${debugecho}" == "true" ]] && echo Debug: hit the bottom ; exit 0
