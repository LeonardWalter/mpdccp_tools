#! /bin/bash


##### TEST CONFIGURATION #####

dmesg -C

iperfstr="iperf3 -c 10.0.42.1 -u -b 3000k -t 20 -4 -l 1050"
#iperfstr="iperf3 -c 10.0.42.1 -t 10 -4"

echo cubic > /proc/sys/net/ipv4/tcp_congestion_control

echo 0 > /sys/module/mpdccp/parameters/ro_dbug_state
echo 0 > /sys/module/mpdccp/parameters/mpdccp_debug
echo 0 > /sys/module/dccp/parameters/ccid2_debug
echo 0 > /sys/module/dccp/parameters/dccp_debug
echo 0 > /proc/sys/net/mpdccp/mpdccp_debug

#echo default > /proc/sys/net/mpdccp/mpdccp_reordering
echo active > /proc/sys/net/mpdccp/mpdccp_reordering

echo 0 > /proc/sys/mpdccp_active_reordering/adaptive
echo 150 > /proc/sys/mpdccp_active_reordering/fixed_timeout
echo 3 > /proc/sys/mpdccp_active_reordering/loss_detection
echo 200 > /proc/sys/mpdccp_active_reordering/expiry_timeout
echo 1 > /proc/sys/mpdccp_active_reordering/equalize_delay

#echo default > /proc/sys/net/mpdccp/mpdccp_scheduler
echo srtt > /proc/sys/net/mpdccp/mpdccp_scheduler
#echo rr > /proc/sys/net/mpdccp/mpdccp_scheduler
echo 4 > /proc/sys/net/mpdccp/mpdccp_rtt_config


server_setup () {
	ip a add 192.168.102.10/24 dev enp0s8
	ip l set dev enp0s8 up
	ip r add default via 192.168.102.1 dev enp0s8
}
export -f server_setup

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
	ldt new tp1
	ldt newtun tp1 -T mpdccp
	ldt setmtu tp1 -m 1300
	ldt tunbind tp1 -b 192.168.100.10:1337
	ldt setpeer tp1 -r 192.168.102.10:1337
	ip a add 10.0.42.2 dev tp1 peer 10.0.42.1
	ip l set up dev tp1
}
export -f client_tun

ns_setup () {
	ip netns add ns1
	ip l set enp0s9 netns ns1
	ip netns exec ns1 bash -c 'client_setup "enp0s9" "100" "7"'

	ip l set enp0s10 netns ns1
	ip netns exec ns1 bash -c 'client_setup "enp0s10" "101" "4"'

	ip netns add ns2
	ip l set enp0s8 netns ns2
	ip netns exec ns2 bash -c 'server_setup'
	sleep 1
	echo "namespaces configured"
}

tun_setup () {
	echo 0 > /proc/sys/net/ldt/debug
	ip netns exec ns2 bash -c 'server_tun'
	sleep 2

	ip netns exec ns1 bash -c 'client_tun'
	sleep 2
	echo "mpdccp tunnels configured"
}

reset () {
	ip netns exec ns1 ldt rmdev tp1
	sleep 1
	ip netns exec ns2 ldt rmdev tp0
	sleep 1
	modprobe -r ldt
	modprobe -r mpdccp_reorder_active
	modprobe -r mpdccp_sched_rr
	modprobe -r mpdccp
	exit
}

[ "$1" == "-x" ] && reset
[ "$(ip netns list | grep ns1)" ] || ns_setup
[ "$(ip netns exec ns2 ldt | grep tp0)" ] || tun_setup

#ip netns exec ns1 dmesg -C
#ip netns exec ns2 dmesg -C

ip netns exec ns2 ssh 192.168.102.1 "{ \
    /home/user/setdelay.sh 8 30 -q; \
    /home/user/setdelay.sh 9 10; \
}"

sleep 1
ip netns exec ns2 iperf3 -s -i 1 -4 & #> /dev/null 2>&1 &
sleep 1
ip netns exec ns1 $iperfstr > /dev/null 2>&1
sleep 1
ip netns exec ns2 pkill iperf3

sstring=$(dmesg | grep -m1 "send [0-9]*99" | grep -o 'DEQ(\w*): send')
rstring=$(dmesg | grep -v "${sstring%%:*}" | grep -m1 "receive [0-9]*99" | grep -o 'DEQ(\w*)')
dmesg | grep -e "$sstring" -e "$rstring" > /tmp/mptest.log

python3 /home/user/Documents/mpplot/delayplot.py &
python3 /home/user/Documents/mpplot/line.py &
python3 /home/user/Documents/mpplot/owd.py &
