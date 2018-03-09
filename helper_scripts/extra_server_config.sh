#!/bin/bash

echo "#################################"
echo "  Running Extra_Server_Config.sh"
echo "#################################"
sudo su

useradd cumulus -m -s /bin/bash
echo "cumulus:CumulusLinux!" | chpasswd

mkdir -p /home/cumulus/.ssh

#Test for Debian-Based Host
which apt &> /dev/null
if [ "$?" == "0" ]; then
    #These lines will be used when booting on a debian-based box
    echo -e "note: ubuntu device detected"
    #Install LLDP
    apt-get update -qy && apt-get install lldpd -qy
    echo "configure lldp portidsubtype ifname" > /etc/lldpd.d/port_info.conf
    
    # Replace existing network interfaces file
    echo -e "auto lo" > /etc/network/interfaces
    echo -e "iface lo inet loopback\n\n" >> /etc/network/interfaces
    echo -e  "source /etc/network/interfaces.d/*.cfg\n" >> /etc/network/interfaces

    echo -e "\n\nauto eth0" > /etc/network/interfaces.d/eth0.cfg
    echo -e "iface eth0 inet dhcp" >> /etc/network/interfaces.d/eth0.cfg
    echo -e "post-up wget -O /home/cumulus/.ssh/authorized_keys http://192.168.200.254/authorized_keys\n\n">> /etc/network/interfaces.d/eth0.cfg
    echo "retry 1;" >> /etc/dhcp/dhclient.conf
fi

#Test for Fedora-Based Host
which yum &> /dev/null
if [ "$?" == "0" ]; then
    echo -e "note: fedora-based device detected"
    /usr/bin/dnf install python -y
    echo -e "DEVICE=vagrant\nBOOTPROTO=dhcp\nONBOOT=yes" > /etc/sysconfig/network-scripts/ifcfg-vagrant
    echo -e "DEVICE=eth0\nBOOTPROTO=dhcp\nONBOOT=yes" > /etc/sysconfig/network-scripts/ifcfg-eth0
fi

echo "cumulus ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10_cumulus

# Disable AAAA records; speeds up APT for v4 only networks
sed -i -e 's/#precedence ::ffff:0:0\/96  10/#precedence ::ffff:0:0\/96  100/g' /etc/gai.conf

echo "#################################"
echo "   Finished"
echo "#################################"
