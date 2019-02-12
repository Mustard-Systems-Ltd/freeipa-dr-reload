. server.inc
nmcli connection modify eth0 ipv4.dns "${forwarder1},${forwarder2}"
nmcli connection modify eth0 ipv4.dns-search "${bzn}"
hostnamectl set-hostname $(hostname | sed -e 's/^\([^.]*\)\..*$/\1/').${bzn}
systemctl restart network.service
sleep 3
echo '[vault-base]
name=CentOS-$releasever - Base
baseurl=http://vault.centos.org/7.2.1511/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates 
[vault-updates]
name=CentOS-$releasever - Updates
baseurl=http://vault.centos.org/7.2.1511/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[vault-extras]
name=CentOS-$releasever - Extras
baseurl=http://vault.centos.org/7.2.1511/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[vault-centosplus]
name=CentOS-$releasever - Plus
baseurl=http://vault.centos.org/7.2.1511/centosplus/$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7' > /etc/yum.repos.d/vault.repo

yum makecache
sleep 2
yum -y install yum-versionlock yum-utils
sleep 2
yum -y --setopt=obsoletes=0 update-to bind-license-9.9.4-29.el7_2.4 bind-libs-lite-9.9.4-29.el7_2.4
sleep 2
yum versionlock add bind-license
sleep 2
yum -y --setopt=obsoletes=0 install krb5-libs-1.13.2-12.el7_2
sleep 2
yum versionlock add krb5-libs
sleep 2
yum -y --setopt=obsoletes=0 install nfs-utils-1.3.0-0.21.el7_2.1 gssproxy-0.4.1-8.el7_2
sleep 2
yum versionlock add gssproxy
sleep 2
yum -y --setopt=obsoletes=0 install bind-libs-9.9.4-29.el7_2.4 bind-utils-9.9.4-29.el7_2.4
sleep 2
yum versionlock add bind-libs
sleep 2
yum -y --setopt=obsoletes=0 install sssd-1.13.0-40.el7_2.12 samba-client-libs-4.2.10-7.el7_2 libsmbclient-4.2.10-7.el7_2 libsss_idmap-1.13.0-40.el7_2.12 libsss_nss_idmap-1.13.0-40.el7_2.12
sleep 2
yum versionlock add sssd samba-client-libs libsmbclient libsss_idmap libsss_nss_idmap
sleep 2
yum -y --setopt=obsoletes=0 install krb5-workstation-1.13.2-12.el7_2 krb5-pkinit-1.13.2-12.el7_2 ipa-client-4.2.0-15.0.1.el7.centos.19 sssd-ipa-1.13.0-40.el7_2.12 sssd-ldap-1.13.0-40.el7_2.12 python-libipa_hbac-1.13.0-40.el7_2.12 ipa-server-4.2.0-15.0.1.el7.centos.19 slapi-nis-0.54-11.el7_2
sleep 2
yum versionlock add ipa-server
sleep 2
yum -y --setopt=obsoletes=0 install setroubleshoot-server bzip2 lsof strace
sleep 2
yum -y --setopt=obsoletes=0 install bind-pkcs11-libs-9.9.4-29.el7_2.4 bind-pkcs11-utils-9.9.4-29.el7_2.4 bind-pkcs11-9.9.4-29.el7_2.4 bind-dyndb-ldap-8.0-1.el7 bind-9.9.4-29.el7_2.4 ipa-server-dns-4.2.0-15.0.1.el7.centos.19
sleep 2
yum -y upgrade libblkid dbus-libs avahi-libs libuuid libmount
sleep 2
yum -y --setopt=multilib_policy=best --setopt=obsoletes=0 --exclude='*.i686' --skip-broken update
sleep 2
yum -y --setopt=multilib_policy=best --exclude='*.i686' --skip-broken upgrade
sleep 2
yum -y --setopt=obsoletes=0 install epel-release
sleep 2
yum makecache
sleep 2
yum -y --setopt=obsoletes=0 install haveged
sleep 2
systemctl enable haveged.service
systemctl start haveged.service
sleep 11
yum -y --setopt=obsoletes=0 install git
sleep 2
sync
echo Rebooting
exec shutdown -r now
