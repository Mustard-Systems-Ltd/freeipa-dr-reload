getenforce 
setenforce 0
getenforce
. server.inc
brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$(echo $brealm | tr '.' '-')
bdcn=$(echo $bzn | sed -e 's/^/dc=/' -e 's/\./,dc=/g')
sed -r -e '/^(entry(dn|id|usn)|hasSubordinates|(create|modify)Timestamp|(creators|modifiers)Name|mepManaged(By|Entry)|parentid|passwordGraceUserTime|subschemaSubentry)/d' userRoot-recovery.ldif > nonmep-userRoot.ldif
sed -i -r -e '/^nsAccountLock/d' nonmep-userRoot.ldif
sed -i -r -e '/^nsUniqueId/d' nonmep-userRoot.ldif

# should make this conditional
sed -i -r -e '/^userCertificate/d' nonmep-userRoot.ldif

sed -i -r -e '/^idnsSOAserial/s/^idnsSOAserial: .*$/idnsSOAserial: '"$(date +%s)"'/' nonmep-userRoot.ldif
sed -i -e '/^dn.*cn=etc,'"${bdcn}"'/,/^$/{/^$/!d}' nonmep-userRoot.ldif
sed -i -e '/^dn.*cn=kerberos,'"${bdcn}"'/,/^$/{/^$/!d}' nonmep-userRoot.ldif
sed -i -e '/^dn.*cn=sec,cn=dns,'"${bdcn}"'/,/^$/{/^$/!d}' nonmep-userRoot.ldif
sed -i -e '/^memberOf: cn=replication managers,/d' nonmep-userRoot.ldif
sed -i -e '/^objectClass: ipaReplTopoManagedServer/d' nonmep-userRoot.ldif
sed -i -e '/^'"$(grep -Ei '^(dn: ipaUniqueID=.*,cn=hbac,'"${bdcn}"'|cn: allow_all)' userRoot-recovery.ldif | grep -B 1 allow_all | head -n 1)"'/,/^$/{/^$/!d}' nonmep-userRoot.ldif
sed -i -e '/^'"$(grep -Ei '^(dn: ipaUniqueID=.*,cn=caacls,cn=ca,'"${bdcn}"'|cn: hosts_services_caIPAserviceCert)' userRoot-recovery.ldif | grep -B 1 hosts_services_caIPAserviceCert | head -n 1)"'/,/^$/{/^$/!d}' nonmep-userRoot.ldif
for lis in ${legacyipasvrs} ; do
	sed -i -e '/^dn: krbprincipalname=HTTP\/'"${lis}"'.'"${bzn}"'@'"${brealm}"',cn=services,cn=accounts,'"${bdcn}"'/,/^$/{/^$/!d}' nonmep-userRoot.ldif
done ; unset lis
systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
if [[ -z $PW ]] ; then
        echo Set PW you fool. Do not forget the leading space
else
	sleep 10
        ldapadd -H ldap://localhost -D "cn=directory manager" -w $PW -f nonmep-userRoot.ldif -c -S skipped-userRoot.ldif
	sleep 2
        cat /dev/null > redomebership.ldif
        grep -E '^dn: .*(cn=admins,cn=groups,cn=accounts|cn=roles,cn=accounts|cn=privileges,cn=pbac)', skipped-userRoot.ldif | grep -vE 'cn=DNS Servers,cn=privileges,cn=pbac' | while read -r rmdn; do
                if sed -n -e '/^'"${rmdn}"'/,/^$/{/^member: /p}' skipped-userRoot.ldif | grep -q '^member: ' ; then
                        #echo "" >> redomebership.ldif
                        #echo $rmdn >> redomebership.ldif
                        #echo "changetype: modify" >> redomebership.ldif
                        #sed -n -e '/^'"${rmdn}"'/,/^$/{/^member: /{s/^/add: member\n/;s/$/\n-/;p}}' skipped-userRoot.ldif | sed -e '$d' >> redomebership.ldif
                        sed -n -e '/^'"${rmdn}"'/,/^$/{/^member: /{s/^/\n'"${rmdn}"'\nchangetype: modify\nadd: member\n/;p}}' skipped-userRoot.ldif >> redomebership.ldif
                fi
        done
        mv skipped-userRoot.ldif skipped-userRoot-$(date +%s).ldif
        ldapmodify -H ldap://localhost -D "cn=directory manager" -w $PW -f redomebership.ldif -c -S skipped-redomebership-$(date +%s).ldif
	echo Sleeping for 130
	sleep 130
	kdestroy
	echo $PW | kinit admin@${brealm}
        for du in $(grep -E '^dn:|nsAccountLock' userRoot-recovery.ldif | grep -B 1 nsAccountLock | grep '^dn' | grep 'cn=users,cn=accounts,'"${bdcn}" | grep -v '^dn: uid=admin,' | sed -e 's/^dn: uid=//' -e 's/,cn=users,cn=accounts,'"${bdcn}"'//') ; do
                echo Attempting ipa user-disable $du
                ipa user-disable $du
	done
	echo Sleeping for 10
	sleep 10
	for z in $(ipa dnszone-find --pkey-only --sizelimit=2000 | awk '/^  Zone name:/ { print $3 } { next }') ; do
		sleep 1
		echo Results of ipa dnszone-show $z --all --raw
		ipa dnszone-show $z --all --raw
		if $(echo $z | grep -q 'in-addr\.arpa\.$') ; then 
			# Reverse domain
			echo About to try ipa dnszone-mod $z --dynamic-update=TRUE
			ipa dnszone-mod $z --dynamic-update=TRUE
			echo About to try ipa dnszone-mod $z --allow-sync-ptr=FALSE
			ipa dnszone-mod $z --allow-sync-ptr=FALSE
			echo About to try ipa dnszone-mod $z --update-policy='grant '"${brealm}"' krb5-subdomain '"${z}"' PTR;'
			ipa dnszone-mod $z --update-policy='grant '"${brealm}"' krb5-subdomain '"${z}"' PTR;'
		else
			# Forward domain
			echo About to try ipa dnszone-mod $z --dynamic-update=TRUE
			ipa dnszone-mod $z --dynamic-update=TRUE
			echo About to try ipa dnszone-mod $z --allow-sync-ptr=TRUE
			ipa dnszone-mod $z --allow-sync-ptr=TRUE
			echo About to try ipa dnszone-mod $z --update-policy='grant '"${brealm}"' krb5-self * A; grant '"${brealm}"' krb5-self * AAAA; grant '"${brealm}"' krb5-self * SSHFP;'
			ipa dnszone-mod $z --update-policy='grant '"${brealm}"' krb5-self * A; grant '"${brealm}"' krb5-self * AAAA; grant '"${brealm}"' krb5-self * SSHFP;'
		fi
		echo Results of ipa dnsrecord-show $z '@' --all --raw
		ipa dnsrecord-show $z '@' --all --raw
		echo About to try ipa dnsrecord-add $z '@' --ns-rec=$(hostname).
		ipa dnsrecord-add $z '@' --ns-rec=$(hostname).
		echo About to try ipa dnsrecord-mod $z '@' --ns-rec=$(hostname).
		ipa dnsrecord-mod $z '@' --ns-rec=$(hostname).
		if [[ -n "$(echo $z | sed -e 's/\.$//' -e 's/[^.]//g')"  ]] ; then
			echo About to try Glue Records ipa dnsrecord-add/mod $(echo $z | sed -e 's/^[^.]*\.//') $(echo $z | sed -e 's/^\([^.]*\)\..*$/\1/') --ns-rec=$(hostname).
			ipa dnsrecord-add $(echo $z | sed -e 's/^[^.]*\.//') $(echo $z | sed -e 's/^\([^.]*\)\..*$/\1/') --ns-rec=$(hostname).
			ipa dnsrecord-mod $(echo $z | sed -e 's/^[^.]*\.//') $(echo $z | sed -e 's/^\([^.]*\)\..*$/\1/') --ns-rec=$(hostname).
		fi
		echo About to try ipa dnszone-mod $z --name-server=$(hostname).
		ipa dnszone-mod $z --name-server=$(hostname).
	done ; unset z
	echo Sleeping for 130
	sleep 130
	for lis in ${legacyipasvrs} ; do
		#ipa-replica-manage del ${lis}.${bzn} #ipa-replica-manage del will not help
		for hg in $(ipa hostgroup-find --pkey-only --sizelimit=500 --hosts=${lis}.${bzn} | awk '$1 == "Host-group:" { print $2 }') ; do
			ipa hostgroup-add-member ${hg} --hosts=$(hostname)
			ipa hostgroup-remove-member ${hg} --hosts=${lis}.${bzn}
		done ; unset hg
		for p in $(ipa service-find --pkey-only --sizelimit=2000 --man-by-hosts=${lis}.${bzn} | awk '$1 == "Principal:" { print $2 }') ; do
			sleep 1
			echo About to try ipa service-del $p
			ipa service-del $p
		done ; unset p
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
	done ; unset lis
	ipa config-mod --defaultshell=/bin/bash
	echo Sleeping for 130
	sleep 130
	sudo -u dirsrv -- db2ldif -Z $realmm -NU -n userRoot
	sleep 2
	sudo -u dirsrv -- db2ldif -Z $realmm -NU -n ipaca
	sleep 2
	sudo -u dirsrv -- db2ldif -Z $realmm -NU -n changelog
	sleep 2
	sudo -u dirsrv -- db2bak -Z $realmm 
	ls -lrt /var/lib/dirsrv/slapd-${realmm}/ldif/*
fi
sync
