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
yum -y --setopt=multilib_policy=best --exclude='*.i686' --enablerepo=base --enablerepo=extras --enablerepo=updates update centos-release
sleep 2
yum-config-manager --disable C7.2.1511-base
sleep 2
yum-config-manager --disable C7.2.1511-extras
sleep 2
yum-config-manager --disable C7.2.1511-updates
sleep 2
yum-config-manager --enable C7.5.1804-base
sleep 2
yum-config-manager --enable C7.5.1804-extras
sleep 2
yum-config-manager --enable C7.5.1804-updates
sleep 2
yum makecache
sleep 2
#yum -y --setopt=multilib_policy=best --exclude='*.i686' downgrade centos-release-7-2.1511.el7.centos.2.10
sleep 2
yum -y --setopt=multilib_policy=best --setopt=obsoletes=0 --exclude='*.i686' --skip-broken update
sleep 2
yum -y --setopt=multilib_policy=best --exclude='*.i686' --skip-broken upgrade
sleep 2
yum versionlock list
yum versionlock delete '*'
yum versionlock list
sleep 2
yum -y --setopt=multilib_policy=best --setopt=obsoletes=0 --exclude='*.i686' --skip-broken update
sleep 2
yum -y --setopt=multilib_policy=best --exclude='*.i686' --skip-broken upgrade
sleep 2
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
echo Sleeping for 131 then shutting down FreeIPA
sleep 131
sync ; ipactl stop ; sync
sleep 2
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
yum upgrade
sleep 2
sync
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sleep 2
echo Sleeping for 61
sleep 61
sync
echo Rebooting
#sync ; ipactl stop ; sync ; exec shutdown -r now
