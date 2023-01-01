#! /bin/bash

ldt new tp0 	# Create tunnel interface
ldt newtun tp0 -T mpdccp 	# Setup MP-DCCP socket
ldt setmtu tp0 -m 1300
ldt tunbind tp0 -b 192.168.102.10:1337 	# Bind socket to the locat IP address intended to accept the connections
ldt serverstart tp0
ip address add 10.0.42.1 dev tp0 peer 10.0.42.2 	# Assing IP address to the tunnel interface
ip link set up dev tp0
