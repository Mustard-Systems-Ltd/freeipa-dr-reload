getenforce 
setenforce 0
getenforce 
. server.inc
nmcli connection modify eth0 ipv4.dns "${forwarder1},${forwarder2}"
nmcli connection modify eth0 ipv4.dns-search "${bzn}"
hostnamectl set-hostname $(hostname | sed -e 's/^\([^.]*\)\..*$/\1/').${bzn}
systemctl restart network.service
sleep 3
yum makecache
sleep 2
yum -y update centos-release
sleep 2
yum -y --setopt=multilib_policy=best --exclude='*.i686' --disablerepo=base --disablerepo=extras --disablerepo=updates --enablerepo=C7.2.1511-base --enablerepo=C7.2.1511-extras --enablerepo=C7.2.1511-updates update
sleep 2
yum -y --setopt=multilib_policy=best --exclude='*.i686' --disablerepo=base --disablerepo=extras --disablerepo=updates --enablerepo=C7.2.1511-base --enablerepo=C7.2.1511-extras --enablerepo=C7.2.1511-updates install yum-versionlock yum-utils
sleep 2
yum-config-manager --enable C7.2.1511-base
sleep 2
yum-config-manager --enable C7.2.1511-extras
sleep 2
yum-config-manager --enable C7.2.1511-updates
sleep 2
yum-config-manager --disable base
sleep 2
yum-config-manager --disable extras
sleep 2
yum-config-manager --disable updates
sleep 2
yum makecache
sleep 2
yum -y --setopt=multilib_policy=best --exclude='*.i686' downgrade centos-release-7-2.1511.el7.centos.2.10
sleep 2
yum -y --setopt=obsoletes=0 install ipa-server ipa-server-dns
sleep 2
yum versionlock add ipa-server libldb libsss_nss_idmap
sleep 2
yum -y --setopt=obsoletes=0 install setroubleshoot-server setools bzip2 lsof strace
sleep 2
sudo service auditd restart
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
