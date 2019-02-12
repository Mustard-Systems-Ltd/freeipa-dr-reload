. server.inc
nmcli connection modify eth0 ipv4.dns "127.0.0.1,${forwarder1},${forwarder2}"
nmcli connection modify eth0 ipv4.dns-search "${bzn}"
hostnamectl set-hostname $(hostname | sed -e 's/^\([^.]*\)\..*$/\1/').${bzn}
systemctl restart network.service
sleep 3
if [[ -z $PW ]] ; then
        echo Set PW you fool. Do not forget the leading space
else
        brealm=$($bzn | tr '[a-z]' '[A-Z]')
	realmm=$($brealm | tr '.' '-')
        ipa-server-install -r ${brealm} -n ${bzn} -p $PW -a $PW --mkhomedir --hostname=$(hostname) --ip-address=$(ip route get 8.8.8.8 | awk '$(NF-1) == "src" { print $NF }') --ssh-trust-dns --setup-dns --no-host-dns --forwarder ${forwarder1} --forwarder ${forwarder2} -U
	ls -lrt ca*
	echo Sleeping for 130
	sleep 130
	sudo -u dirsrv -- db2ldif -Z $realmm -NU -n userRoot
	sleep 2
	sudo -u dirsrv -- db2ldif -Z $realmm -NU -n ipaca
	sleep 2
	sudo -u dirsrv -- db2ldif -Z $realmm -NU -n changelog
	sleep 2
	sudo -u dirsrv -- db2bak -Z $realmm
fi
sync
