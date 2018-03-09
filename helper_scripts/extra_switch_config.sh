#!/bin/bash

echo "#################################"
echo "  Running Extra_Switch_Config.sh"
echo "#################################"
sudo su

echo "retry 1;" >> /etc/dhcp/dhclient.conf

cat <<EOT > /etc/network/interfaces
auto lo
iface lo inet loopback

 auto eth0
 iface eth0 inet dhcp
    vrf mgmt
    
auto mgmt
iface mgmt
    address 127.0.0.1/8
    vrf-table auto

EOT

#add line to support bonding inside virtualbox VMs
#sed -i '/.*iface swp.*/a\    #required for traffic to flow on Bonds in Vbox VMs\n    post-up ip link set $IFACE promisc on' /etc/network/interfaces

echo "#################################"
echo "   Finished"
echo "#################################"
