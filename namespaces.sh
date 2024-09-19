#! /bin/bash


##### TEST CONFIGURATION #####

dmesg -C

#iperfstr="iperf3 -c 10.0.42.1 -u -b 3000k -t 10 -4 -l 1050"
iperfstr="iperf3 -c 10.0.42.1 -t 100 -4" # -P 5"
#iperfstr="iperf3 -c 192.168.102.10 -t 10 -4"

delay1=30
delay2=10

/home/user/ccid5.sh

echo 0 > /sys/module/mpdccp/parameters/ro_dbug_state
echo 0 > /sys/module/dccp/parameters/ccid2_debug
echo 1 > /sys/module/dccp/parameters/dccp_debug
echo 1 > /sys/module/mpdccp/parameters/mpdccp_debug

#echo default > /proc/sys/net/mpdccp/mpdccp_reordering && rmmod mpdccp_reorder_active
echo active > /proc/sys/net/mpdccp/mpdccp_reordering
echo 0 > /proc/sys/mpdccp_active_reordering/equalize_delay

echo 0 > /proc/sys/mpdccp_active_reordering/adaptive
echo 150 > /proc/sys/mpdccp_active_reordering/fixed_timeout
echo 3 > /proc/sys/mpdccp_active_reordering/loss_detection
echo 200 > /proc/sys/mpdccp_active_reordering/expiry_timeout
echo 2500 > /proc/sys/mpdccp_active_reordering/not_rcv_max

#echo default > /proc/sys/net/mpdccp/mpdccp_scheduler
#echo srtt > /proc/sys/net/mpdccp/mpdccp_scheduler
echo rr > /proc/sys/net/mpdccp/mpdccp_scheduler
echo 4 > /proc/sys/net/mpdccp/mpdccp_rtt_config
echo 1 > /proc/sys/net/mpdccp/mpdccp_accept_prio

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
	ip netns exec ns1 bash -c 'client_setup "enp0s9" "100" "5"'

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
	sleep 2
	ip netns exec ns2 bash -c 'server_tun'
	sleep 2
	ip netns exec ns1 bash -c 'client_tun'
	echo "mpdccp tunnels configured"
}

reset () {
	ip netns exec ns1 ldt rmdev tp1
	sleep 1
	ip netns exec ns2 ldt rmdev tp0
	sleep 2
	modprobe -r ldt
	modprobe -r mpdccp_reorder_active
	modprobe -r mpdccp_sched_rr
	modprobe -r mpdccp
	exit
}

[ "$1" == "-x" ] && reset
[ "$(ip netns list | grep ns1)" ] || ns_setup
[ "$(ip netns exec ns2 ldt | grep tp0)" ] || tun_setup

ip netns exec ns1 bash -c 'tc -s qdisc show dev enp0s9 && tc -s qdisc show dev enp0s10'
echo " "
echo "Testing $(</proc/sys/net/mpdccp/mpdccp_scheduler) scheduler enp9: $(ip netns exec ns1 cat /sys/module/mpdccplink/links/dev/enp0s9/mpdccp_prio) enp10: $(ip netns exec ns1 cat /sys/module/mpdccplink/links/dev/enp0s10/mpdccp_prio)"

ip netns exec ns2 ssh 192.168.102.1 "{ \
    /home/user/setdelay.sh 8 $delay1 -q; \
    /home/user/setdelay.sh 9 $delay2; \
    /home/user/tcheck.sh s; \
}"

sleep 1
ip netns exec ns2 iperf3 -s -i 1 -4 & #> /dev/null 2>&1 &
sleep 1

read
echo 0 > /sys/module/dccp/parameters/dccp_debug
echo 0 > /sys/module/mpdccp/parameters/mpdccp_debug

ip netns exec ns1 $iperfstr > /dev/null 2>&1

ip netns exec ns2 ssh 192.168.102.1 /home/user/tcheck.sh r
sleep 1
ip netns exec ns2 pkill iperf3 > /dev/null 2>&1

server=$(dmesg | grep -m1 "role 3" | grep -oP '\(\K[^\)]+')
client=$(dmesg | grep -m1 "role 2" | grep -oP '\(\K[^\)]+')
sstring="DEQ($client): send"
rstring="DEQ($server): receive"
dstring="DEQ($server): delaying"
fstring="DEQ($server): forward"

dmesg | grep -e "$sstring" -e "$rstring" -e "$dstring" -e "$fstring" > /tmp/mptest.log

python3 /home/user/Documents/mpplot/delayplot.py &
python3 /home/user/Documents/mpplot/line.py &
python3 /home/user/Documents/mpplot/owd.py &

echo "Packet count - rx: $(dmesg | grep "$rstring" | wc -l) delay: $(dmesg | grep "$dstring" | wc -l)"
