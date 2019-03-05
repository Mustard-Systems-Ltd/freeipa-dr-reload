#!/usr/bin/bash
if [[ -r server.inc ]] ; then 
	. server.inc
else
	(>&2 echo "Cannot import \"server.inc\" from the current directory. cd?")
	exit 1
fi
if [[ $# -ne 1 ]] ; then
	(>&2 echo "$0 usage - one argument: replica host IPv4 address")
	exit 1
fi 
if ! echo $1 | grep -Eq '^[0-9]+(\.[0-9]+){3}' ; then
	(>&2 echo "\"${1}\" does not look like an IPv4 address")
	exit 1
fi
if ssh -o IdentityAgent=none -o PreferredAuthentications=publickey -o ConnectTimeout=8 root@$1 true ; then
	echo SSH root trust OK
else
	(>&2 echo \"ssh -o IdentityAgent=none -o PreferredAuthentications=publickey -o ConnectTimeout=8 root@$1 true\" failed with result code $?)
	exit 1
fi
rip=$1
mip=$(ip route get 8.8.8.8 | awk '$(NF-1) == "src" { print $NF }')
if [[ -z $PW ]] ; then
        (>&2 echo "Set PW you fool. Do not forget the leading space")
        exit 1
else
        ( echo $PW | kinit admin >/dev/null 2>&1 ) || exit $?
        kdestroy
fi

remote()
{
	ssh -o IdentityAgent=none -o PreferredAuthentications=publickey -o ConnectTimeout=8 root@${rip} -- $@
}

rscp()
{
	scp -p -o IdentityAgent=none -o PreferredAuthentications=publickey -o ConnectTimeout=8 ${1} root@${rip}:${1}
}


ripass()
{
	remote systemctl --lines=0 status dirsrv@${realmm}.service
	remote systemctl --lines=0 status {httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
}

rreboot()
{
	ripass
	remote sync
	remote ipactl stop
	remote sync
	remote exec shutdown -r now
	while ! remote true >/dev/null 2>&1 ; do 
		echo Waiting for reboot ...
		sleep 11
	done
	echo Reboot is ready for SSH
	ripass
	echo Sleeping for 61
	sleep 61
	ripass
}

brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$(echo $brealm | tr '.' '-')
bdcn=$(echo $bzn | sed -e 's/^/dc=/' -e 's/\./,dc=/g')
urhn=$(remote hostname | sed -e 's/^\([^.]*\)\..*$/\1/')

#echo $PW | kinit admin

remote firewall-cmd --state
remote systemctl --now disable firewalld.service
#remote ipa-replica-install --domain=${bzn} --server=$(hostname) --realm=${brealm} -P admin@${brealm} -w $PW --mkhomedir --ssh-trust-dns -U --setup-dns --forwarder ${forwarder1} --forwarder ${forwarder2} --auto-reverse --force-join -d
remote ipa-replica-install -P admin@${brealm} -w $PW --mkhomedir --ssh-trust-dns -U --setup-dns --forwarder ${forwarder1} --forwarder ${forwarder2} --auto-reverse --force-join -d

# --setup-kra
# --no-pkinit

