getenforce 
setenforce 0
getenforce
. server.inc
nmcli connection modify eth0 ipv4.dns "127.0.0.1,${forwarder1},${forwarder2}"
nmcli connection modify eth0 ipv4.dns-search "${bzn}"
hostnamectl set-hostname $(hostname | sed -e 's/^\([^.]*\)\..*$/\1/').${bzn}
systemctl restart network.service
sleep 3
brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$(echo $brealm | tr '.' '-')
bdcn=$(echo $bzn | sed -e 's/^/dc=/' -e 's/\./,dc=/g')
if [[ -s userRoot-recovery.ldif ]] ; then
	sed -n -e '/^dn: .*cn='"${brealm}"',cn=kerberos,'"${bdcn}"'/,/^$/p' userRoot-recovery.ldif > nonmep-kerberos.ldif
	sed -i -r -e '/^(entry(dn|id|usn)|hasSubordinates|(create|modify)Timestamp|(creators|modifiers)Name|mepManaged(By|Entry)|parentid|passwordGraceUserTime|subschemaSubentry)/d' nonmep-kerberos.ldif
	sed -i -r -e '/^nsUniqueId/d' nonmep-kerberos.ldif
	for lis in ${legacyipasvrs} ; do
		sed -i -r -e 's/'"${lis}"'/'"$(hostname | sed -e 's/^\([^.]*\)\..*$/\1/')"'/g' nonmep-kerberos.ldif
	done
	[[ -f /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py-real ]] && ( rm -f /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py ; mv /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py-real /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py )
	[[ -f /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py-real ]] || ( mv /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py-real ; cp -p /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py-real /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py )
	sed -i -e '/^\s*def __init_ipa_kdb(self):/,/^\s*ipautil\.run(args, nolog=(self\.master_password,), stdin='"''"'\.join(dialogue))/{/^\s*ipautil\.run/a\
            ipautil.run("/tmp/hack-krb-mk.sh")
}' /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py
	echo '#!/usr/bin/bash' > /tmp/hack-krb-mk.sh
	chmod u+x,go-rwx /tmp/hack-krb-mk.sh
	echo ldapsearch -LLL -o ldif-wrap=no -H ldap://localhost -D \"cn=directory manager\" -w \"${PW}\" -b cn=${brealm},cn=kerberos,${bdcn} dn \| sed -e "'"'/^$/d ; s/^dn: //'"'" \| while read b \; do ldapdelete -r -H ldap://localhost -D \"cn=directory manager\" -w \"${PW}\" \${b} \; done >> /tmp/hack-krb-mk.sh
	echo ldapadd -H ldap://localhost -D \"cn=directory manager\" -w \"${PW}\" -f nonmep-kerberos.ldif -c -S skipped-kerberos-$(date +%s).ldif >> /tmp/hack-krb-mk.sh
fi
package-cleanup -y --oldkernels --count=2
sleep 2
sync
sleep 2
if [[ -z $PW ]] ; then
        echo Set PW you fool. Do not forget the leading space
else
        ipa-server-install -r ${brealm} -n ${bzn} -p $PW -a $PW --mkhomedir --hostname=$(hostname) --ip-address=$(ip route get 8.8.8.8 | awk '$(NF-1) == "src" { print $NF }') --ssh-trust-dns --setup-dns --no-host-dns --forwarder ${forwarder1} --forwarder ${forwarder2} -U
	ls -lrt ~/ca*
	echo Sleeping for 130
	sleep 130
	systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
	sudo -u dirsrv -- db2ldif -Z $realmm -NU -n userRoot
	sleep 2
	sudo -u dirsrv -- db2ldif -Z $realmm -NU -n ipaca
	sleep 2
	sudo -u dirsrv -- db2ldif -Z $realmm -NU -n changelog
	sleep 2
	sudo -u dirsrv -- db2bak -Z $realmm
fi
sync
if [[ -s userRoot-recovery.ldif ]] ; then
	true
	rm -f /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py ; mv /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py-real /usr/lib/python2.7/site-packages/ipaserver/install/krbinstance.py
	rm -f /tmp/hack-krb-mk.sh
fi
sync
