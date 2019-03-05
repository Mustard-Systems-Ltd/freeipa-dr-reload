getenforce 
setenforce 0
getenforce
. server.inc
brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$(echo $brealm | tr '.' '-')
sleep 2
package-cleanup -y --oldkernels --count=2
sleep 2
yum -y --enablerepo=C7.2.1511-base --enablerepo=C7.2.1511-extras --enablerepo=C7.2.1511-updates --enablerepo=C7.5.1804-base --enablerepo=C7.5.1804-extras --enablerepo=C7.5.1804-updates clean all
sleep 2
yum makecache fast
sleep 2
sync
systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
echo Sleeping for 131 then upgrading FreeIPA
sleep 131
ipa-server-upgrade -v
echo Sleeping for 31
sleep 31
sync
systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
top -bn 1 | head -n 15
echo Sleeping for 31 again
sleep 31
systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
top -bn 1 | head -n 15
sleep 2
fstrim /
sleep 2
if [[ -z $PW ]] ; then
        echo Set PW you fool. Do not forget the leading space
else
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n userRoot
        sleep 2
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n ipaca
        sleep 2
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n changelog
        sleep 2
        sudo -u dirsrv -- db2bak -Z $realmm
	ls -lrt /var/lib/dirsrv/slapd-${realmm}/ldif/*
        sleep 2
	kdestroy
	sleep 2
	ipa-kra-install -p $PW -U
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n userRoot
        sleep 2
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n ipaca
        sleep 2
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n changelog
        sleep 2
        sudo -u dirsrv -- db2bak -Z $realmm
	ls -lrt /var/lib/dirsrv/slapd-${realmm}/ldif/*
        sleep 2
	ipa-cacert-manage -p $PW renew --self-signed
        sleep 2
	echo $PW | kinit admin
        sleep 2
	ipa-certupdate
        sleep 2
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n userRoot
        sleep 2
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n ipaca
        sleep 2
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n changelog
        sleep 2
        sudo -u dirsrv -- db2bak -Z $realmm
	ls -lrt /var/lib/dirsrv/slapd-${realmm}/ldif/*
        sleep 2
	ipa-pkinit-manage status
	ipa-pkinit-manage enable
        sleep 2
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n userRoot
        sleep 2
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n ipaca
        sleep 2
        sudo -u dirsrv -- db2ldif -Z $realmm -NU -n changelog
        sleep 2
        sudo -u dirsrv -- db2bak -Z $realmm
	ls -lrt /var/lib/dirsrv/slapd-${realmm}/ldif/*
        sleep 2
fi
sync
getenforce 
setenforce 1
getenforce
