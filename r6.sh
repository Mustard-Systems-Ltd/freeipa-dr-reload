getenforce 
setenforce 0
getenforce
. server.inc
brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$(echo $brealm | tr '.' '-')
yum makecache fast
systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
echo Sleeping for 131 then upgrading FreeIPA
sleep 131
if [[ -z $PW ]] ; then
        echo Set PW you fool. Do not forget the leading space
else
	echo $PW | kinit admin
	ipa domainlevel-get
	ipa domainlevel-set 1
	kdestroy
	sleep 2
	ipa-server-upgrade -v
	[[ -r /var/log/ipaserver-install.log ]] && mv /var/log/ipaserver-install.log /var/log/ipaserver-install.$(date +%s).log
	[[ -r /var/log/ipaupgrade.log ]] && mv /var/log/ipaupgrade.log /var/log/ipaupgrade.$(date +%s).log
	echo Sleeping for 31
	sleep 31
	systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
	echo Sleeping for 31 again
	sleep 31
	systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
	echo Sleeping for 131 then shutting down FreeIPA
	sleep 131
	sync ; ipactl stop ; sync
	sleep 2
	systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
	sleep 10
	systemctl stop {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
	sleep 10
	systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
	sleep 10
	yum versionlock list
	yum versionlock delete '*'
	sleep 2
	package-cleanup -y --oldkernels --count=2
	sleep 2
	sync
	sleep 2
	rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named|389-ds|kernel-|pki-' | sort > packages-before-r6.txt
	yum -y --setopt=multilib_policy=best --setopt=obsoletes=0 --exclude='*.i686' --skip-broken update
	rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named|389-ds|kernel-|pki-' | sort > packages-after-r6-skip-broken-update.txt
	[[ -r /var/log/ipaserver-install.log ]] && mv /var/log/ipaserver-install.log /var/log/ipaserver-install.$(date +%s).log
	[[ -r /var/log/ipaupgrade.log ]] && mv /var/log/ipaupgrade.log /var/log/ipaupgrade.$(date +%s).log
	sleep 2
	sync
	sleep 2
	systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
	sleep 10
	yum -y --setopt=multilib_policy=best --exclude='*.i686' --skip-broken upgrade
	rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named|389-ds|kernel-|pki-' | sort > packages-after-r6-skip-broken-upgrade.txt
	[[ -r /var/log/ipaserver-install.log ]] && mv /var/log/ipaserver-install.log /var/log/ipaserver-install.$(date +%s).log
	[[ -r /var/log/ipaupgrade.log ]] && mv /var/log/ipaupgrade.log /var/log/ipaupgrade.$(date +%s).log
	sleep 2
	systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
	sleep 10
	yum -y upgrade
	rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named|389-ds|kernel-|pki-' | sort > packages-after-r6-upgrade.txt
	[[ -r /var/log/ipaserver-install.log ]] && mv /var/log/ipaserver-install.log /var/log/ipaserver-install.$(date +%s).log
	[[ -r /var/log/ipaupgrade.log ]] && mv /var/log/ipaupgrade.log /var/log/ipaupgrade.$(date +%s).log
	sleep 2
	sync
	sleep 2
	sed -i -e 's/ elevator=noop//' /etc/defult/grub
	grub2-mkconfig -o /boot/grub2/grub.cfg
	sleep 2
	sync
	sleep 2
	systemctl --lines=0 status {dirsrv@${realmm},httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
	echo Sleeping for 61
	sleep 61
	sync
	echo Rebooting
	sync ; ipactl stop ; sync ; exec shutdown -r now
fi
