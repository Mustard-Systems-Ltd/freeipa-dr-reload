getenforce 
setenforce 0
getenforce 
sync
sleep 2
for d in $(grep -E 'deadline|cfq' /sys/block/*/queue/scheduler | grep -v '/sr' | sed -e 's/:.*$//') ; do
	echo "noop" > ${d}
done
sleep 2
sync
. server.inc
nmcli connection modify eth0 ipv4.dns "${forwarder1},${forwarder2}"
nmcli connection modify eth0 802-3-ethernet.mtu 1454
nmcli connection modify eth0 ipv4.dns-search "${bzn}"
hostnamectl set-hostname $(hostname | sed -e 's/^\([^.]*\)\..*$/\1/').${bzn}
systemctl restart network.service
sleep 3
echo 'dirsrv soft nofile 4096' > /etc/security/limits.d/71-mustard-dirsrv.conf
echo 'dirsrv hard nofile 8192' >> /etc/security/limits.d/71-mustard-dirsrv.conf
[[ -d /etc/systemd/journald.conf.d ]] || mkdir /etc/systemd/journald.conf.d
echo '[Journal]
Storage=persistent
SystemMaxUse=250M
MaxRetentionSec=13month' > /etc/systemd/journald.conf.d/mustard_recommeds.conf
systemctl restart systemd-journald.service
sleep 2
sed -i -e '/^GRUB_SERIAL_COMMAND/d' -e '/^GRUB_TERMINAL_OUTPUT=/{s/=".*$/="console serial"/;a\
GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"
}' /etc/default/grub
grep -q '^GRUB_CMDLINE_LINUX.*console=ttyS' /etc/default/grub || sed -i -e '/^GRUB_CMDLINE_LINUX=/s/="/="console=tty0 console=ttyS0,115200n8 /' -e 's/ rhgb quiet"$/ elevator=noop"/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
sleep 2
rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named|389-ds|kernel-|pki-|ntp|chrony' | sort > packages-before-r1-4272.txt
sleep 2
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
rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named|389-ds|kernel-|pki-|ntp|chrony' | sort > packages-r1-4272-before_ipa-server_install.txt
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
yum -y --setopt=obsoletes=0 install git watchdog nmap
sleep 2
rpm -qa | grep -E 'krb5|samba|sss|gssproxy|hbac|ipa|slapi|ldap|pkcs|ldb|bind|named|389-ds|kernel-|pki-|ntp|chrony' | sort > packages-after_r1-4272.txt
sleep 2
sync
echo Rebooting
exec shutdown -r now
