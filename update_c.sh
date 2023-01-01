#! /bin/bash
ip_c="192.168.100.10"

kern="4.14.111-mpdccp-2022-01-27+"
#kern="4.14.111original-mpdccp-2022-01-27+"
dir="/lib/modules/$kern/kernel/net"
#kern=$(uname -r)

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

cd ympdccp
#make M=net/core modules -j  $(nproc) || exit
make M=net/dccp modules -j  $(nproc) || exit

[ "$1" == "-x" ] && exit

cp net/dccp/dccp.ko $dir/dccp/
cp net/dccp/dccp_ipv4.ko $dir/dccp/
cp net/dccp/mpdccp.ko $dir/dccp/
cp net/dccp/mpdccplink.ko $dir/dccp/
cp net/dccp/scheduler/mpdccp_sched_*.ko $dir/dccp/scheduler/
cp net/dccp/non_gpl_scheduler/mpdccp_sched_*.ko $dir/dccp/scheduler/

#cp net/core/devlink.ko $dir/core/
#cp net/core/drop_monitor.ko $dir/core
#cp net/core/pktgen.ko $dir/core

#scp net/core/devlink.ko $ip_c:$dir/core/
#scp net/core/drop_monitor.ko $ip_c:$dir/core
#scp net/core/pktgen.ko $ip_c:$dir/core

modprobe -r mpdccp
modprobe mpdccp || exit
echo 1 > /sys/module/mpdccp/parameters/mpdccp_debug
echo 1 > /sys/module/dccp/parameters/dccp_debug

#exit

scp net/dccp/dccp.ko $ip_c:$dir/dccp/
scp net/dccp/dccp_ipv4.ko $ip_c:$dir/dccp/
scp net/dccp/mpdccp.ko $ip_c:$dir/dccp/
scp net/dccp/mpdccplink.ko $ip_c:$dir/dccp/
scp net/dccp/scheduler/mpdccp_sched_*.ko $ip_c:$dir/dccp/scheduler/
scp net/dccp/non_gpl_scheduler/mpdccp_sched_*.ko $ip_c:$dir/dccp/scheduler/

ssh $ip_c " { \
        modprobe -r mpdccp; \
	modprobe mpdccp; \
	echo 1 > /sys/module/mpdccp/parameters/mpdccp_debug; \
	echo 1 > /sys/module/dccp/parameters/dccp_debug; \
}"



echo "replaced mpdccp modules"
