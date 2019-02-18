. server.inc
brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$(echo $brealm | tr '.' '-')
bdcn=$(echo $bzn | sed -e 's/^/dc=/' -e 's/\./,dc=/g')
sed -r -e '/^(entry(dn|id|usn)|hasSubordinates|(create|modify)Timestamp|(creators|modifiers)Name|mepManaged(By|Entry)|parentid|passwordGraceUserTime|subschemaSubentry)/d' userRoot-recovery.ldif > nonmep-userRoot.ldif
sed -i -r -e '/^nsaccountLock/d' nonmep-userRoot.ldif
sed -i -r -e '/^nsUniqueId/d' nonmep-userRoot.ldif
sed -i -e '/^dn.*cn=etc,'"${bdcn}"'/,/^$/{/^$/!d}' nonmep-userRoot.ldif
sed -i -e '/^dn.*cn=kerberos,'"${bdcn}"'/,/^$/{/^$/!d}' nonmep-userRoot.ldif
sed -i -e '/^memberOf: cn=replication managers,/d' nonmep-userRoot.ldif
sed -i -e '/^objectClass: ipaReplTopoManagedServer/d' nonmep-userRoot.ldif
sed -i -e '/^'"$(grep -Ei '^(dn: ipaUniqueID=.*,cn=hbac,'"${bdcn}"'|cn: allow_all)' userRoot-recovery.ldif | grep -B 1 allow_all | head -n 1)"'/,/^$/{/^$/!d}' nonmep-userRoot.ldif
sed -i -e '/^'"$(grep -Ei '^(dn: ipaUniqueID=.*,cn=caacls,cn=ca,'"${bdcn}"'|cn: hosts_services_caIPAserviceCert)' userRoot-recovery.ldif | grep -B 1 hosts_services_caIPAserviceCert | head -n 1)"'/,/^$/{/^$/!d}' nonmep-userRoot.ldif
for lis in ${legacyipasvrs} ; do
	sed -i -e '/^dn: krbprincipalname=HTTP\/'"${lis}"'.'"${bzn}"'@'"${brealm}"',cn=services,cn=accounts,'"${bdcn}"'/,/^$/{/^$/!d}' nonmep-userRoot.ldif
done
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
if [[ -z $PW ]] ; then
        echo Set PW you fool. Do not forget the leading space
else
	sleep 10
        ldapadd -H ldap://localhost -D "cn=directory manager" -w $PW -f nonmep-userRoot.ldif -c -S skipped-userRoot-$(date +%s).ldif
	echo Sleeping for 130
	sleep 130
	kdestroy
	echo $PW | kinit admin@${brealm}
	for z in $(ipa dnszone-find --pkey-only --sizelimit=2000 | awk '/^  Zone name:/ { print $3 } { next }') ; do
		sleep 1
		if $(echo $z | grep -q 'in-addr\.arpa\.$') ; then 
			echo reverse
		else
			echo normal
		fi
		echo About to try ipa dnsrecord-mod $z @ --ns-rec=$(hostname).
		ipa dnsrecord-mod $z @ --ns-rec=$(hostname).
		echo About to try Glue Records ipa dnsrecord-add/mod $(echo $z | sed -e 's/^[^.]*\.//') $(echo $z | sed -e 's/^\([^.]*\)\..*$/\1/') --ns-rec=$(hostname).
		ipa dnsrecord-add $(echo $z | sed -e 's/^[^.]*\.//') $(echo $z | sed -e 's/^\([^.]*\)\..*$/\1/') --ns-rec=$(hostname).
		ipa dnsrecord-mod $(echo $z | sed -e 's/^[^.]*\.//') $(echo $z | sed -e 's/^\([^.]*\)\..*$/\1/') --ns-rec=$(hostname).
		echo About to try ipa dnszone-mod $z --name-server=$(hostname).
		ipa dnszone-mod $z --name-server=$(hostname).
	done
	#ipa-replica-manage del will not help
	echo Sleeping for 130
	sleep 130
	for lis in ${legacyipasvrs} ; do
		#ipa-replica-manage del ${lis}.${bzn}
		for p in $(ipa service-find --pkey-only --sizelimit=2000 --man-by-hosts=${lis}.${bzn} | awk '$1 == "Principal:" { print $2 }') ; do
			sleep 1
			echo About to try ipa service-del $p
			ipa service-del $p
		done
		sleep 1
		echo About to try ipa host-del ${lis}.${bzn} --updatedns
		ipa host-del ${lis}.${bzn} --updatedns
		sleep 1
		echo About to try ipa dnsrecord-del ${bzn}. $lis --del-all
		ipa dnsrecord-del ${bzn}. $lis --del-all
		sleep 1
		echo About to try ipa dnsrecord-del mustard. $lis --del-all
		ipa dnsrecord-del mustard. $lis --del-all
		sleep 1
		echo About to try ipa dnsrecord-del mustard. ${lis}-phyhost --del-all
		ipa dnsrecord-del mustard. ${lis}-phyhost --del-all
		#sleep 1
		#echo About to try ipa dnsrecord-del cnames.${bzn}. $lis --del-all
		#ipa dnsrecord-del cnames.${bzn}. $lis --del-all
	done
	echo Sleeping for 130
	sleep 130
	sudo -u dirsrv -- db2ldif -Z $realmm  -NU -n userRoot
	sleep 2
	sudo -u dirsrv -- db2ldif -Z $realmm  -NU -n ipaca
	sleep 2
	sudo -u dirsrv -- db2ldif -Z $realmm  -NU -n changelog
	sleep 2
	sudo -u dirsrv -- db2bak -Z $realmm 
fi
