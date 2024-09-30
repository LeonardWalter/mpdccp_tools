#! /bin/bash
ip_c="192.168.100.10"
ip_r="192.168.102.1"

kern="4.14.111-mpdccp-2022-01-27+"
#kern="4.14.111original-mpdccp-2022-01-27+"
dir="/lib/modules/$kern/kernel/net"
#kern=$(uname -r)

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

lsmod | grep -q ldt && ldt | grep -q tp0 && ldt rmdev tp0

cd ympdccp
#make M=net/core modules -j  $(nproc) || exit
make M=net/dccp modules -j  $(nproc) || exit

[ "$1" == "-x" ] && exit

nc -z -w 1 $ip_r 22 && ssh $ip_r "{ \
    /home/user/setdelay.sh 8 0 -q; \
    /home/user/setdelay.sh 9 0 -q; \
}"

cp net/dccp/dccp.ko $dir/dccp/
cp net/dccp/dccp_ipv4.ko $dir/dccp/
cp net/dccp/mpdccp.ko $dir/dccp/
cp net/dccp/mpdccplink.ko $dir/dccp/
cp net/dccp/scheduler/mpdccp_sched_*.ko $dir/dccp/scheduler/
#cp net/dccp/reordering/*.ko $dir/dccp/reordering/
cp net/dccp/non_gpl_reordering/*.ko $dir/dccp/reordering/
cp net/dccp/non_gpl_scheduler/mpdccp_sched_*.ko $dir/dccp/scheduler/

#cp net/core/devlink.ko $dir/core/
#cp net/core/drop_monitor.ko $dir/core
#cp net/core/pktgen.ko $dir/core

#scp net/core/devlink.ko $ip_c:$dir/core/
#scp net/core/drop_monitor.ko $ip_c:$dir/core
#scp net/core/pktgen.ko $ip_c:$dir/core

modprobe -r ldt
modprobe -r mpdccp_reorder_active
modprobe -r mpdccp
#modprobe mpdccp || exit
modprobe ldt


nc -z -w 1 $ip_c 22 || exit

scp net/dccp/dccp.ko $ip_c:$dir/dccp/
scp net/dccp/dccp_ipv4.ko $ip_c:$dir/dccp/
scp net/dccp/mpdccp.ko $ip_c:$dir/dccp/
scp net/dccp/mpdccplink.ko $ip_c:$dir/dccp/
scp net/dccp/scheduler/*.ko $ip_c:$dir/dccp/scheduler/
scp net/dccp/non_gpl_scheduler/*.ko $ip_c:$dir/dccp/scheduler/
scp net/dccp/non_gpl_reordering/*.ko $ip_c:$dir/dccp/reordering/

ssh $ip_c " { /home/user/refresh_mods; }"
echo "replaced mpdccp modules"

[ "$1" == "-r" ] && { ssh $ip_c "reboot" || true; reboot; }
