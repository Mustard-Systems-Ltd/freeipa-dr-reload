#!/usr/bin/bash
if [[ -r server.inc ]] ; then 
	. server.inc
else
	(>&2 echo "Cannot import \"server.inc\" from the current directory. cd?")
	exit 1
fi
if [[ $# -ne 1 ]] ; then
	(>&2 echo "$0 usage - one argument: replica host IPv4 address")
	exit 1
fi 
if ! echo $1 | grep -Eq '^[0-9]+(\.[0-9]+){3}' ; then
	(>&2 echo "\"${1}\" does not look like an IPv4 address")
	exit 1
fi
if ssh -o IdentityAgent=none -o PreferredAuthentications=publickey -o ConnectTimeout=8 root@$1 true ; then
	echo SSH root trust OK
else
	(>&2 echo \"ssh -o IdentityAgent=none -o PreferredAuthentications=publickey -o ConnectTimeout=8 root@$1 true\" failed with result code $?)
	exit 1
fi
rip=$1
mip=$(ip route get 8.8.8.8 | awk '$(NF-1) == "src" { print $NF }')
if [[ -z $PW ]] ; then
        (>&2 echo "Set PW you fool. Do not forget the leading space")
	exit 1
else
	( echo $PW | kinit admin >/dev/null 2>&1) || exit $?
	kdestroy
fi

remote()
{
	ssh -o IdentityAgent=none -o PreferredAuthentications=publickey -o ConnectTimeout=8 root@${rip} -- $@
}

rscp()
{
	scp -p -o IdentityAgent=none -o PreferredAuthentications=publickey -o ConnectTimeout=8 ${1} root@${rip}:${1}
}


ripass()
{
        remote systemctl --lines=0 status dirsrv@${realmm}.service
        remote systemctl --lines=0 status {httpd,certmonger,ipa-dnskeysyncd,ipa_memcached,kadmin,krb5kdc,named-pkcs11,pki-tomcatd@pki-tomcat}.service
}

rreboot()
{
        ripass
        remote sync
        remote ipactl stop
        remote sync
	echo Rebooting
        remote exec shutdown -r now
        while ! remote true >/dev/null 2>&1 ; do
                echo Waiting for reboot ...
                sleep 11
        done
        echo Reboot is ready for SSH
        ripass
        echo Sleeping for 61
        sleep 61
        ripass
}

remote nmcli connection modify eth0 ipv4.dns \"${mip}\"
remote nmcli connection modify eth0 ipv4.dns-search "${bzn}"
urhn=$(remote hostname | sed -e 's/^\([^.]*\)\..*$/\1/')
remote hostnamectl set-hostname ${urhn}.${bzn}
remote nmcli connection modify eth0 802-3-ethernet.mtu 1454
remote exec systemctl restart network.service
sleep 3
brealm=$(echo $bzn | tr '[a-z]' '[A-Z]')
realmm=$(echo $brealm | tr '.' '-')
bdcn=$(echo $bzn | sed -e 's/^/dc=/' -e 's/\./,dc=/g')
remote getenforce 
remote setenforce 0
remote getenforce 
remote echo "'"dirsrv soft nofile 4096"'" \> /etc/security/limits.d/71-mustard-dirsrv.conf
remote echo "'"dirsrv hard nofile 8192"'" \>\> /etc/security/limits.d/71-mustard-dirsrv.conf
remote \[\[ -d /etc/systemd/journald.conf.d \]\] \|\| mkdir /etc/systemd/journald.conf.d
echo '[Journal]
Storage=persistent
SystemMaxUse=250M
MaxRetentionSec=13month' > /tmp/mustard_recommeds.conf.$$
rscp /tmp/mustard_recommeds.conf.$$
rm -f /tmp/mustard_recommeds.conf.$$
remote mv /tmp/mustard_recommeds.conf.$$ /etc/systemd/journald.conf.d/mustard_recommeds.conf
remote systemctl restart systemd-journald.service
sleep 2
echo '/^GRUB_SERIAL_COMMAND/d' > /tmp/sed1.$$
echo '/^GRUB_TERMINAL_OUTPUT=/{s/=".*$/="console serial"/;a\
GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"
}' >> /tmp/sed1.$$
rscp /tmp/sed1.$$
rm -f /tmp/sed1.$$
remote sed -i -f /tmp/sed1.$$ /etc/default/grub
remote rm -f /tmp/sed1.$$
remote grep -q "'"'^GRUB_CMDLINE_LINUX.*console=ttyS'"'" /etc/default/grub \|\| sed -i -e "'"'/^GRUB_CMDLINE_LINUX=/s/="/="console=tty0 console=ttyS0,115200n8 /'"'" -e "'"'s/ rhgb quiet"$/ elevator=kyber"/'"'" /etc/default/grub
remote grub2-mkconfig -o /boot/grub2/grub.cfg
sleep 2
remote yum makecache
sleep 2
remote yum -y --setopt=multilib_policy=best --exclude="'"'*.i686'"'" update
sleep 2
remote yum -y --setopt=multilib_policy=best --exclude="'"'*.i686'"'" install yum-versionlock yum-utils
sleep 2
remote yum -y --setopt=obsoletes=0 install ipa-server-4.6.4-10.el7.centos.2 ipa-server-dns-4.6.4-10.el7.centos.2
sleep 2
remote yum versionlock add ipa-server ipa-server-dns
sleep 2
remote yum -y --setopt=obsoletes=0 install wget
sleep 2
remote yum -y --setopt=obsoletes=0 install setroubleshoot-server setools bzip2 lsof strace
sleep 2
remote sudo service auditd restart
sleep 2
remote yum -y --setopt=multilib_policy=best --setopt=obsoletes=0 --exclude="'"*.i686"'" --skip-broken update
sleep 2
remote yum -y --setopt=multilib_policy=best --exclude="'"'*.i686'"'" --skip-broken upgrade
sleep 2
remote yum -y --setopt=obsoletes=0 install epel-release
sleep 2
remote yum makecache
sleep 2
remote yum -y --setopt=obsoletes=0 install haveged
sleep 2
remote systemctl enable haveged.service
remote systemctl start haveged.service
sleep 11
remote yum -y --setopt=obsoletes=0 install git watchdog nmap
sleep 2
rreboot

echo $PW | kinit admin
ipa dnsrecord-add ${bzn}. ${urhn} --a-ip-address=${1} --a-create-reverse

remote systemctl start certmonger.service
sleep 5
#remote wget -O /tmp/ca$$.crt http://$(hostname)/ipa/config/ca.crt 
#certutil -L -d dbm:/etc/pki/pki-tomcat/alias -n 'caSigningCert cert-pki-ca' -a > /tmp/ca$$.crt
#rscp /tmp/ca$$.crt
#rm -f /tmp/ca$$.crt
#remote ipa-client-install --domain=${bzn} --server=$(hostname) --realm=${brealm} -p admin@${brealm} -w $PW --mkhomedir --ssh-trust-dns -U --ca-cert-file=/tmp/ca$$.crt --request-cert --permit --enable-dns-updates 
#remote rm /tmp/ca$$.crt
remote ipa-client-install --domain=${bzn} --server=$(hostname) --realm=${brealm} -p admin@${brealm} -w $PW --mkhomedir --ssh-trust-dns -U --request-cert --permit --enable-dns-updates 
echo Sleeping for 61
sleep 61

remote firewall-cmd --state
remote systemctl --now disable firewalld.service
remote ipa-replica-install -P admin@${brealm} -w $PW --mkhomedir --ssh-trust-dns -U --setup-ca --setup-dns --forwarder ${forwarder1} --forwarder ${forwarder2} --auto-reverse

echo Sleeping for 61
sleep 61
ipa server-role-find
sleep 2
remote sudo -u dirsrv -- db2ldif -Z $realmm -NU -n userRoot
sleep 2
remote sudo -u dirsrv -- db2ldif -Z $realmm -NU -n ipaca
sleep 2
remote sudo -u dirsrv -- db2ldif -Z $realmm -NU -n changelog
sleep 2
#disable db2bak#remote sudo -u dirsrv -- db2bak -Z $realmm
remote ls -lrt /var/lib/dirsrv/slapd-${realmm}/ldif/\*
sudo -u dirsrv -- db2ldif -Z $realmm -NU -n userRoot
sleep 2
sudo -u dirsrv -- db2ldif -Z $realmm -NU -n ipaca
sleep 2
sudo -u dirsrv -- db2ldif -Z $realmm -NU -n changelog
sleep 2
#disable db2bak#sudo -u dirsrv -- db2bak -Z $realmm
ls -lrt /var/lib/dirsrv/slapd-${realmm}/ldif/\*
sleep 2
nmcli connection modify eth0 ipv4.dns "127.0.0.1,${rip}"
remote nmcli connection modify eth0 ipv4.dns \"127.0.0.1,${mip}\"
systemctl restart network.service
sleep 3
remote exec systemctl restart network.service
sleep 3
