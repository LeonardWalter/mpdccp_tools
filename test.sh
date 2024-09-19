#! /bin/bash

ip_c="192.168.100.10"
ip_r="192.168.102.1"

#iperfstr="iperf3 -c 10.0.42.1 -u -b 4000k -t 3 -4 -l 1050"
iperfstr="iperf3 -c 10.0.42.1 -t 100 -4 -P 5"
#iperfstr="iperf3 -c 192.168.102.10 -i 1 -4 --dccp --multipath -t 2 -b 3M"

delay1=30
delay2=10

setup=0

ccid=2
#nc -z -w 1 $ip_c 22 || exit

/home/user/ccid$ccid.sh

#echo default > /proc/sys/net/mpdccp/mpdccp_reordering #&& rmmod mpdccp_reorder_active
echo active > /proc/sys/net/mpdccp/mpdccp_reordering
echo 2 > /proc/sys/mpdccp_active_reordering/equalize_delay

echo 0 > /proc/sys/mpdccp_active_reordering/adaptive
echo 150 > /proc/sys/mpdccp_active_reordering/fixed_timeout
echo 3 > /proc/sys/mpdccp_active_reordering/loss_detection
echo 200 > /proc/sys/mpdccp_active_reordering/expiry_timeout
echo 0 > /proc/sys/mpdccp_active_reordering/rtt_type
echo 2500 > /proc/sys/mpdccp_active_reordering/not_rcv_max


#ssh $ip_r "/home/user/ts.sh"

ssh $ip_c "{ \
    /home/user/ccid$ccid.sh; \
    echo rr > /proc/sys/net/mpdccp/mpdccp_scheduler; \
    echo 0 > /proc/sys/net/mpdccp/mpdccp_rtt_config; \
    echo 0 > /sys/module/mpdccp/parameters/ro_dbug_state; \
    echo 0 > /sys/module/mpdccp/parameters/mpdccp_debug; \
    echo 0 > /sys/module/dccp/parameters/dccp_debug; \
    echo 0 > /proc/sys/net/ldt/debug; \
    echo 0 > /sys/module/dccp/parameters/ccid2_debug; \
}"

#    ip l set enp0s9 down; \
#    echo active > /proc/sys/net/mpdccp/mpdccp_reordering; \

ssh $ip_r "{ \
    /home/user/setdelay.sh 8 $delay1 -q; \
    /home/user/setdelay.sh 9 $delay2; \
    /home/user/tcheck.sh s; \
}"

[ "$(ldt | grep tp0)" ] || ./tunsetup.sh

sleep 1
echo 0 > /sys/module/mpdccp/parameters/ro_dbug_state
echo 0 > /sys/module/mpdccp/parameters/mpdccp_debug
echo 0 > /sys/module/dccp/parameters/dccp_debug
echo 0 > /proc/sys/net/ldt/debug


ssh $ip_c '{ \
    /home/user/tunsetup.sh && sleep 1; \
    dmesg | grep -q "Failed to set up MPDCCP Client mpcb" && setup=failed; \
    echo "Testing $(</proc/sys/net/mpdccp/mpdccp_scheduler) scheduler enp8: $(</sys/module/mpdccplink/links/dev/enp0s8/mpdccp_prio) enp9: $(</sys/module/mpdccplink/links/dev/enp0s9/mpdccp_prio)"; \
}'
#    dmesg -C; \

#read

dmesg -C
if [ $setup != "failed" ]; then
	iperf3 -s -i 1 -4 &
	#tcpdump -i tp0 -q udp port 5201 -tt -l -x > /home/user/tclogp &
	sleep 0.5

	ssh $ip_c $iperfstr > /dev/null 2>&1 && sleep 1
	#pkill tcpdump
	pkill iperf3

	ssh $ip_c "dmesg" > /home/user/Documents/mpplot/cl.log
	dmesg > /home/user/Documents/mpplot/run.log
	python3 /home/user/Documents/mpplot/plotter.py &
else
	echo "setup failed, ldt module bricked"
fi

ssh $ip_c "ldt rmdev tp0"

ssh $ip_r "{ \
    /home/user/setdelay.sh 8 0 -q; \
    /home/user/setdelay.sh 9 0; \
}"

#ssh $ip_r "tc qdisc | grep ifb0.*delay && tc qdisc del dev ifb0 root"
#ssh $ip_r "tc qdisc | grep ifb1.*delay && tc qdisc del dev ifb1 root"

ldt rmdev tp0

sleep 2 && ss -d | grep -q "192.168.102.10" && echo "socket still active" &


echo $iperfstr
ssh $ip_r /home/user/tcheck.sh r


#ssting=$(dmesg | grep "send 100" | tail -1 | grep -o 'DEQ(\w*): send')
#rstring=$(dmesg | grep "receive 100" | tail -1 | grep -o 'DEQ(\w*)')
rstring=$(dmesg | grep -m1 "receive [0-9]*99" | grep -o 'DEQ(\w*)')
dmesg | grep -e "$rstring" > /tmp/mptest.log
[ $(wc -l < /tmp/mptest.log) -lt 30 ] && exit


python3 /home/user/Documents/mpplot/line.py &
python3 /home/user/Documents/mpplot/owd.py &


exit
echo "iperf packets out of order:"
python3 /home/user/Documents/mpplot/tcfinder.py
