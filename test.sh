#! /bin/bash
ip_c="192.168.100.10"
ip_r="192.168.102.1"
iperfstr="iperf3 -c 10.0.42.1 -u -b 3000k -t 10 -4 -l 1050"
#iperfstr="iperf3 -c 10.0.42.1 -t 10 -4"

setup=0

#echo default > /proc/sys/net/mpdccp/mpdccp_reordering
echo active > /proc/sys/net/mpdccp/mpdccp_reordering
echo 0 > /proc/sys/mpdccp_active_reordering/adaptive
echo 150 > /proc/sys/mpdccp_active_reordering/fixed_timeout
echo 3 > /proc/sys/mpdccp_active_reordering/loss_detection
echo 200 > /proc/sys/mpdccp_active_reordering/expiry_timeout
echo 0 > /proc/sys/mpdccp_active_reordering/rtt_type
echo 1 > /proc/sys/mpdccp_active_reordering/equalize_delay


#ssh $ip_r "tc qdisc add dev ifb0 root netem delay 30ms loss 3%"
#ssh $ip_r "tc qdisc add dev ifb0 root netem delay 30ms loss gemodel 5 60 80 1"

ssh $ip_r "{ \
    /home/user/setdelay.sh 8 30 -q; \
    /home/user/setdelay.sh 9 10; \
}"

#ssh $ip_r "tc qdisc add dev ifb0 root netem delay 30ms"
#ssh $ip_r "tc qdisc add dev ifb1 root netem delay 10ms"
#ssh $ip_r "tc qdisc add dev ifb1 root netem loss gemodel 5 60 80 1"

ssh $ip_c " { \
    echo cubic > /proc/sys/net/ipv4/tcp_congestion_control; \
    echo rr > /proc/sys/net/mpdccp/mpdccp_scheduler; \
    echo 4 > /proc/sys/net/mpdccp/mpdccp_rtt_config; \
    echo 0 > /sys/module/mpdccp/parameters/ro_dbug_state; \
    echo 1 > /sys/module/mpdccp/parameters/mpdccp_debug; \
    echo 1 > /sys/module/dccp/parameters/dccp_debug; \
    echo 1 > /proc/sys/net/ldt/debug; \
    echo 1 > /sys/module/dccp/parameters/ccid2_debug; \
    dmesg -C; \
}"

[ "$(ldt | grep tp0)" ] || ./tunsetup.sh

echo 0 > /sys/module/mpdccp/parameters/ro_dbug_state
echo 0 > /sys/module/mpdccp/parameters/mpdccp_debug
echo 0 > /sys/module/dccp/parameters/dccp_debug
echo 0 > /proc/sys/net/ldt/debug


dmesg -C
#ssh $ip_c "/home/user/tunsetup.sh && sleep 0.5"
#ssh $ip_c "/home/user/tunsetup.sh && sleep 0.5 && ping 10.0.42.1 -c 6 && sleep 0.5"
ssh $ip_c "/home/user/tunsetup.sh && sleep 0.5"
ssh $ip_c "dmesg" | grep -q "Failed to set up MPDCCP Client mpcb" && setup=failed

if [ $setup != "failed" ]; then
	iperf3 -s -i 1 -4 &
	#tcpdump -i tp0 -q udp port 5201 -tt -l -x > /home/user/tclogp &
	sleep 0.5

	ssh $ip_c $iperfstr > /dev/null 2>&1 && sleep 1
##	ssh $ip_c "iperf3 -c 10.0.42.1 -u -b 4M -t 10 -4 -l 1050 && sleep 1"

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


#ssting=$(dmesg | grep "send 100" | tail -1 | grep -o 'DEQ(\w*): send')
#rstring=$(dmesg | grep "receive 100" | tail -1 | grep -o 'DEQ(\w*)')
rstring=$(dmesg | grep -m1 "receive [0-9]*99" | grep -o 'DEQ(\w*)')
dmesg | grep -e "$rstring" > /tmp/mptest.log
python3 /home/user/Documents/mpplot/line.py &
python3 /home/user/Documents/mpplot/owd.py &


exit
echo "iperf packets out of order:"
python3 /home/user/Documents/mpplot/tcfinder.py
