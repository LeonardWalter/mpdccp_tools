#! /bin/bash

client_setup () {
	ip a add 192.168.$2.10/24 dev $1
	ip l set dev $1 up
	ip ru add from all fwmark 0x$2 table $2
	iptables -A OUTPUT -s 192.168.$2.10 -t mangle -j MARK --set-mark 0x$2
	ip r add 192.168.$2.0/24 dev $1 scope link table $2
	ip r add default via 192.168.$2.1 dev $1 table $2
	ip r add default via 192.168.$2.1 dev $1 metric $2
	printf "0x%x\n" $((($(cat "/sys/class/net/$1/flags"))|0x200000)) > "/sys/class/net/$1/flags"
	echo $3 > /sys/module/mpdccplink/links/dev/$1/mpdccp_prio
}
export -f client_setup

server_tun () {
	ldt new tp0
	ldt newtun tp0 -T mpdccp
	ldt setmtu tp0 -m 1300
	ldt tunbind tp0 -b 192.168.102.10:1337
	ldt serverstart tp0
	ip a add 10.0.42.1 dev tp0 peer 10.0.42.2
	ip l set up dev tp0
}
export -f server_tun

client_tun () {
	ldt new tp0
	ldt newtun tp0 -T mpdccp
	ldt setmtu tp0 -m 1300
	ldt tunbind tp0 -b 192.168.100.10:1337
	ldt setpeer tp0 -r 192.168.102.10:1337
	ip a add 10.0.42.2 dev tp0 peer 10.0.42.1
	ip l set up dev tp0
}
export -f client_tun


ip netns add ns1
ip l set enp0s9 netns ns1
ip netns exec ns1 bash -c 'client_setup "enp0s9" "100" "7"'

ip l set enp0s10 netns ns1
ip netns exec ns1 bash -c 'client_setup "enp0s10" "101" "4"'


ip netns add ns2

ip l set enp0s8 netns ns2
ip netns exec ns2 ip a add 192.168.102.10/24 dev enp0s8
ip netns exec ns2 ip l set dev enp0s8 up
ip netns exec ns2 ip r add default via 192.168.102.1 dev enp0s8

ip netns exec ns2 bash -c 'server_tun'
sleep 2

ip netns exec ns1 bash -c 'client_tun'
sleep 1
