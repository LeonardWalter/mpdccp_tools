#! /bin/bash
ip_c="192.168.100.10"

kern="4.14.111-mpdccp-2022-01-27+"
dir="/lib/modules/$kern/kernel/net/dccp"
#kern=$(uname -r)

cd ympdccp
make M=net/dccp modules -j  $(nproc) || exit

echo "local"
modprobe -r mpdccp
cp net/dccp/mpdccp.ko $dir/mpdccp.ko
cp net/dccp/scheduler/mpdccp_sched_*.ko $dir/scheduler/
cp net/dccp/non_gpl_scheduler/mpdccp_sched_*.ko $dir/scheduler/

modprobe mpdccp
echo 1 > /sys/module/mpdccp/parameters/mpdccp_debug
sysctl -w net.mpdccp.mpdccp_accept_prio=1 >/dev/null

echo "remote"
ssh $ip_c "modprobe -r mpdccp"
scp net/dccp/mpdccp.ko $ip_c:$dir/mpdccp.ko
scp net/dccp/scheduler/mpdccp_sched_*.ko $ip_c:$dir/scheduler/
scp net/dccp/non_gpl_scheduler/mpdccp_sched_*.ko $ip_c:$dir/scheduler/

ssh $ip_c " { \
	modprobe mpdccp; \
	echo 1 > /sys/module/mpdccp/parameters/mpdccp_debug; \
	sysctl -w net.mpdccp.mpdccp_accept_prio=1 >/dev/null; \
	}"

echo "replaced mpdccp modules"
