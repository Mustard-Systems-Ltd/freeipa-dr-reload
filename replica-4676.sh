getenforce 
setenforce 0
getenforce 
. server.inc
nmcli connection modify eth0 ipv4.dns "${forwarder1},${forwarder2}"
nmcli connection modify eth0 ipv4.dns-search "${bzn}"
hostnamectl set-hostname $(hostname | sed -e 's/^\([^.]*\)\..*$/\1/').${bzn}
systemctl restart network.service
sleep 3
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
grep -q '^GRUB_CMDLINE_LINUX.*console=ttyS' /etc/default/grub || sed -i -e '/^GRUB_CMDLINE_LINUX=/s/="/="console=tty0 console=ttyS0,115200n8 /' -e 's/ rhgb quiet"$/"/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
sleep 2
yum makecache
sleep 2
yum -y --setopt=multilib_policy=best --exclude='*.i686' update
sleep 2
yum -y --setopt=multilib_policy=best --exclude='*.i686' install yum-versionlock yum-utils
sleep 2
yum -y --setopt=obsoletes=0 install ipa-server-4.6.4-10.el7.centos.2 ipa-server-dns-4.6.4-10.el7.centos.2
sleep 2
yum versionlock add ipa-server ipa-server-dns
sleep 2
yum -y --setopt=obsoletes=0 install setroubleshoot-server setools bzip2 lsof strace
sleep 2
sudo service auditd restart
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
yum -y --setopt=obsoletes=0 install git watchdog
sleep 2
sync
# ipa-replica-install # stuff
echo Rebooting
#exec shutdown -r now
