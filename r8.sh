. server.inc
brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$(echo $brealm | tr '.' '-')
sleep 2
package-cleanup -y --oldkernels --count=2
sleep 2
yum -y clean all
sleep 2
yum makecache fast
sleep 2
sync
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
echo Sleeping for 131 then upgrading FreeIPA
sleep 131
ipa-server-upgrade -v
echo Sleeping for 31
sleep 31
sync
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
top -bn 1 | head -n 15
echo Sleeping for 31 again
sleep 31
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
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
fi
sync
