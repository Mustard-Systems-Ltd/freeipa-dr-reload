. server.inc
brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$(echo $brealm | tr '.' '-')
yum makecache fast
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
echo Sleeping for 131 then shutting down FreeIPA
sleep 131
sync ; ipactl stop ; sync
sleep 2
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sleep 10
systemctl stop {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sleep 10
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sleep 10
yum-config-manager --enable base
sleep 2
yum-config-manager --enable extras
sleep 2
yum-config-manager --enable updates
sleep 2
yum-config-manager --disable C7.5.1804-base
sleep 2
yum-config-manager --disable C7.5.1804-extras
sleep 2
yum-config-manager --disable C7.5.1804-updates
sleep 2
yum makecache
sleep 2
sync
sleep 2
rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named' | sort > packages-before-r7.txt
#not yet#yum -y --setopt=multilib_policy=best --setopt=obsoletes=0 --exclude='*.i686' --skip-broken update
#not yet#rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named' | sort > packages-after-r7-update.txt
#not yet#sleep 2
#not yet#sync
#not yet#sleep 2
#not yet#systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
#not yet#sleep 10
#not yet#yum -y --setopt=multilib_policy=best --exclude='*.i686' --skip-broken upgrade
#not yet#rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named' | sort > packages-after-r7-upgrade.txt
#not yet#sleep 2
#not yet#sync
#not yet#sleep 2
#not yet#systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
#not yet#echo Sleeping for 61 then rebooting
#not yet#sleep 61
#not yet#sync
#not yet#echo Rebooting
#not yet##exec shutdown -r now
