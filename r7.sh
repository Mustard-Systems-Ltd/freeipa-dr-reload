getenforce 
setenforce 0
getenforce
. server.inc
brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$(echo $brealm | tr '.' '-')
yum makecache fast
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
echo Sleeping for 131 then shutting down FreeIPA
sleep 131
sync ; ipactl stop ; sync
sleep 2
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sleep 10
systemctl stop {dirsrv@${realmm},httpd,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sleep 10
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
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
yum -y --setopt=multilib_policy=best --exclude='*.i686' upgrade-to ipa-server-4.6.4-10.el7.centos.2 ipa-server-dns-4.6.4-10.el7.centos.2
package-cleanup -y --oldkernels --count=2
yum versionlock add ipa-server ipa-server-dns
sync
sleep 2
rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named' | sort > packages-upgrade-to-ipa-server-r7.txt
sleep 2
yum -y --setopt=multilib_policy=best --setopt=obsoletes=0 --exclude='*.i686' --skip-broken update
rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named' | sort > packages-after-r7-update.txt
sleep 2
sync
sleep 2
echo Sleeping for 131 then shutting down FreeIPA
sleep 131
sync ; ipactl stop ; sync
sleep 2
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sleep 10
systemctl stop {dirsrv@${realmm},httpd,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sleep 10
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sleep 10
yum -y --setopt=multilib_policy=best --exclude='*.i686' --skip-broken upgrade
rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named' | sort > packages-after-r7-skip-broken-upgrade.txt
sleep 2
sync
sleep 2
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sleep 10
yum -y upgrade
rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named' | sort > packages-after-r7-upgrade.txt
sleep 2
sync
sleep 2
systemctl --lines=0 status {dirsrv@${realmm},httpd,ipa-dnskeysyncd,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
sync
echo Sleeping for 61 then rebooting
sleep 61
sync
echo Rebooting
exec shutdown -r now
