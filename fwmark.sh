#! /bin/bash

iptables -t mangle -I PREROUTING 1 -p dccp -s 192.168.100.10 -j MARK --set-mark 0x40000000
iptables -t mangle -I PREROUTING 1 -p dccp -s 192.168.101.10 -j MARK --set-mark 0x80000000

echo mpdccp_lte > /sys/module/mpdccplink/add_link
echo mpdccp_wifi > /sys/module/mpdccplink/add_link

sleep 1

printf %d 0xc0000000 > /sys/module/mpdccplink/links/name/mpdccp_lte/mpdccp_match_mask
printf %d 0x80000000 > /sys/module/mpdccplink/links/name/mpdccp_lte/mpdccp_match_mark

printf %d 0xc0000000 > /sys/module/mpdccplink/links/name/mpdccp_wifi/mpdccp_match_mask
printf %d 0x40000000 > /sys/module/mpdccplink/links/name/mpdccp_wifi/mpdccp_match_mark
