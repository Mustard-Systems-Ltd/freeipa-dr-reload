. server.inc
brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$($brealm | tr '.' '-')
yum makecache fast
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
echo Sleeping for 131
sleep 131
sync
ipa-server-upgrade -y
sleep 2
sync
echo Sleeping for 131
sleep 131
sync
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sleep 2
echo Sleeping for 61
sleep 61
sync
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
