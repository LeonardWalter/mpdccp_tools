v=${1:-2}
if [ $v == "2" ]; then
    echo "enable ccid2"
            #### CCID2 configuration ###
    echo 2 > /proc/sys/net/dccp/default/tx_ccid
    echo 2 > /proc/sys/net/dccp/default/rx_ccid
    
    echo pfifo > /proc/sys/net/core/default_qdisc
    #echo fq > /proc/sys/net/core/default_qdisc
    echo cubic > /proc/sys/net/ipv4/tcp_congestion_control
    
    echo 20000 > /proc/sys/net/dccp/default/tx_qlen
    
    ## Default and maximum amount for the receive socket memory ##
    echo 20000000 > /proc/sys/net/core/rmem_max
    echo 20000000 > /proc/sys/net/core/rmem_default
    
    ## Default and maximum amount for the send socket memory ##
    ## Having a larger value avoids the cycle sleep/wakeup/send ##
    ## on a waitqueue in the dccp_sendmsg() function, wich might ##
    ## not be very efficient at hihgh throughput##
    echo 20000000 > /proc/sys/net/core/wmem_max
    echo 20000000 > /proc/sys/net/core/wmem_default
    echo 1000000 > /proc/sys/net/core/netdev_max_backlog
    
    
    echo "4096 87380 4194304" > /proc/sys/net/ipv4/tcp_rmem
    echo "4096 87380 4194304" > /proc/sys/net/ipv4/tcp_wmem

elif [ $v == "5" ]; then
    echo "enable ccid5"
    #### CCID5 configuration ###
    echo 5 > /proc/sys/net/dccp/default/tx_ccid
    echo 5 > /proc/sys/net/dccp/default/rx_ccid
    
    echo fq > /proc/sys/net/core/default_qdisc
    echo bbr > /proc/sys/net/ipv4/tcp_congestion_control
    
    tc qdisc replace dev enp0s8 root fq flow_limit 2000
    tc qdisc replace dev enp0s9 root fq flow_limit 2000
    tc qdisc replace dev enp0s10 root fq flow_limit 2000
    
    echo 1000 > /proc/sys/net/dccp/default/tx_qlen
    echo 20000000 > /proc/sys/net/core/rmem_max
    echo 2000000 > /proc/sys/net/core/rmem_default
    echo 20000000 > /proc/sys/net/core/wmem_max
    echo 2000000 > /proc/sys/net/core/wmem_default
    echo 1000000 > /proc/sys/net/core/netdev_max_backlog

    echo "93921 125229 187842" > /proc/sys/net/ipv4/tcp_wmem
    echo "93921 125229 187842" > /proc/sys/net/ipv4/tcp_rmem

else
        echo "error"
        exit
fi

