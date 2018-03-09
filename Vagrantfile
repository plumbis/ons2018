# Created by Topology-Converter v4.6.6
#    Template Revision: v4.6.5
#    https://github.com/cumulusnetworks/topology_converter
#    using topology data from: topology.dot
#    built with the following args: topology_converter.py topology.dot -p libvirt -c -s 3030
#
#    NOTE: in order to use this Vagrantfile you will need:
#       -Vagrant(v1.8.6+) installed: http://www.vagrantup.com/downloads
#       -the "helper_scripts" directory that comes packaged with topology-converter.py
#        -Libvirt Installed -- guide to come
#       -Vagrant-Libvirt Plugin installed: $ vagrant plugin install vagrant-libvirt
#       -Start with \"vagrant up --provider=libvirt --no-parallel\n")

#  Libvirt Start Port: 3030
#  Libvirt Port Gap: 1000

#Set the default provider to libvirt in the case they forget --provider=libvirt or if someone destroys a machine it reverts to virtualbox
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'

# Check required plugins
REQUIRED_PLUGINS_LIBVIRT = %w(vagrant-libvirt)
exit unless REQUIRED_PLUGINS_LIBVIRT.all? do |plugin|
  Vagrant.has_plugin?(plugin) || (
    puts "The #{plugin} plugin is required. Please install it with:"
    puts "$ vagrant plugin install #{plugin}"
    false
  )
end

Vagrant.require_version ">= 1.8.6"

$script = <<-SCRIPT
if grep -q -i 'cumulus' /etc/lsb-release &> /dev/null; then
    echo "### RUNNING CUMULUS EXTRA CONFIG ###"
    source /etc/lsb-release
    if [ -z /etc/app-release ]; then
        echo "  INFO: Detected NetQ TS Server"
        source /etc/app-release
        echo "  INFO: Running NetQ TS Appliance Version $APPLIANCE_VERSION"
    else
        if [[ $DISTRIB_RELEASE =~ ^2.* ]]; then
            echo "  INFO: Detected a 2.5.x Based Release"

            echo "  adding fake cl-acltool..."
            echo -e "#!/bin/bash\nexit 0" > /usr/bin/cl-acltool
            chmod 755 /usr/bin/cl-acltool

            echo "  adding fake cl-license..."
            echo -e "#!/bin/bash\nexit 0" > /usr/bin/cl-license
            chmod 755 /usr/bin/cl-license

            echo "  Disabling default remap on Cumulus VX..."
            mv -v /etc/init.d/rename_eth_swp /etc/init.d/rename_eth_swp.backup

            echo "### Rebooting to Apply Remap..."

        elif [[ $DISTRIB_RELEASE =~ ^3.* ]]; then
            echo "  INFO: Detected a 3.x Based Release"
            echo "### Disabling default remap on Cumulus VX..."
            mv -v /etc/hw_init.d/S10rename_eth_swp.sh /etc/S10rename_eth_swp.sh.backup &> /dev/null
            echo "### Disabling ZTP service..."
            systemctl stop ztp.service
            ztp -d 2>&1
            echo "### Resetting ZTP to work next boot..."
            ztp -R 2>&1
            echo "  INFO: Detected Cumulus Linux v$DISTRIB_RELEASE Release"
            if [[ $DISTRIB_RELEASE =~ ^3.[1-9].* ]]; then
                echo "### Fixing ONIE DHCP to avoid Vagrant Interface ###"
                echo "     Note: Installing from ONIE will undo these changes." 
                mkdir /tmp/foo
                mount LABEL=ONIE-BOOT /tmp/foo
                sed -i 's/eth0/eth1/g' /tmp/foo/grub/grub.cfg
                sed -i 's/eth0/eth1/g' /tmp/foo/onie/grub/grub-extra.cfg
                umount /tmp/foo
            fi
            if [[ $DISTRIB_RELEASE =~ ^3.[2-9].* ]]; then
                if [[ $(grep "vagrant" /etc/netd.conf | wc -l ) == 0 ]]; then
                    echo "### Giving Vagrant User Ability to Run NCLU Commands ###"
                    sed -i 's/users_with_edit = root, cumulus/users_with_edit = root, cumulus, vagrant/g' /etc/netd.conf
                    sed -i 's/users_with_show = root, cumulus/users_with_show = root, cumulus, vagrant/g' /etc/netd.conf
                fi
            fi
        fi
    fi
fi
echo "### DONE ###"
echo "### Rebooting Device to Apply Remap..."
nohup bash -c 'sleep 10; shutdown now -r "Rebooting to Remap Interfaces"' &
SCRIPT

Vagrant.configure("2") do |config|

  config.vm.provider :libvirt do |domain|
    # increase nic adapter count to be greater than 8 for all VMs.
    domain.nic_adapter_count = 130
  end




  ##### DEFINE VM for oob-mgmt-server #####
  config.vm.define "oob-mgmt-server" do |device|
    
    device.vm.hostname = "oob-mgmt-server" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.memory = 512
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth1 --> oob-mgmt-switch:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:36",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4062',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3062',
            :libvirt__iface_name => 'eth1',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    #Copy over DHCP files and MGMT Network Files
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/dhcpd.conf", destination: "~/dhcpd.conf"
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/dhcpd.hosts", destination: "~/dhcpd.hosts"
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/hosts", destination: "~/hosts"
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/ansible_hostfile", destination: "~/ansible_hostfile"
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/ztp_oob.sh", destination: "~/ztp_oob.sh"

    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/auto_mgmt_network/OOB_Server_Config_auto_mgmt.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:36 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:36", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for oob-mgmt-switch #####
  config.vm.define "oob-mgmt-switch" do |device|
    
    device.vm.hostname = "oob-mgmt-switch" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"

    device.vm.provider :libvirt do |v|
      v.memory = 512
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for swp1 --> oob-mgmt-server:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:35",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3062',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4062',
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> leaf04:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:37",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3063',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4063',
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> netq-ts:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:39",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3064',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4064',
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> leaf02:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3065',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4065',
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp5 --> leaf03:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3066',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4066',
            :libvirt__iface_name => 'swp5',
            auto_config: false
      # link for swp6 --> leaf01:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3067',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4067',
            :libvirt__iface_name => 'swp6',
            auto_config: false
      # link for swp7 --> spine02:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:41",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3068',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4068',
            :libvirt__iface_name => 'swp7',
            auto_config: false
      # link for swp8 --> spine01:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:43",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3069',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4069',
            :libvirt__iface_name => 'swp8',
            auto_config: false
      # link for swp9 --> server01:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:45",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3070',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4070',
            :libvirt__iface_name => 'swp9',
            auto_config: false
      # link for swp10 --> server03:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:47",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3071',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4071',
            :libvirt__iface_name => 'swp10',
            auto_config: false
      # link for swp11 --> server02:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:49",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3072',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4072',
            :libvirt__iface_name => 'swp11',
            auto_config: false
      # link for swp12 --> server04:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:4b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3073',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4073',
            :libvirt__iface_name => 'swp12',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    #Copy over Topology.dot File
    device.vm.provision "file", source: "topology.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"

# Transfer Bridge File
      device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/bridge-untagged", destination: "~/bridge-untagged"

    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/oob_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:35 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:35", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:37 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:37", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:39 --> swp3"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:39", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3b --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3b", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3d --> swp5"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3d", NAME="swp5", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3f --> swp6"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3f", NAME="swp6", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:41 --> swp7"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:41", NAME="swp7", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:43 --> swp8"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:43", NAME="swp8", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:45 --> swp9"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:45", NAME="swp9", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:47 --> swp10"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:47", NAME="swp10", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:49 --> swp11"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:49", NAME="swp11", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:4b --> swp12"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:4b", NAME="swp12", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for spine02 #####
  config.vm.define "spine02" do |device|
    
    device.vm.hostname = "spine02" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.5.1"

    device.vm.provider :libvirt do |v|
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp7
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:42",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4068',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3068',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> leaf01:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:18",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4045',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3045',
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> leaf02:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:34",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4060',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3060',
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> leaf03:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:12",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4041',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3041',
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> leaf04:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4055',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3055',
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp31 --> spine01:swp31
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4056',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3056',
            :libvirt__iface_name => 'swp31',
            auto_config: false
      # link for swp32 --> spine01:swp32
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:25",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4052',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3052',
            :libvirt__iface_name => 'swp32',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    #Copy over Topology.dot File
    device.vm.provision "file", source: "topology.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:42 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:42", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:18 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:18", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:34 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:34", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:12 --> swp3"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:12", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2b --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2b", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2d --> swp31"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2d", NAME="swp31", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:25 --> swp32"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:25", NAME="swp32", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for spine01 #####
  config.vm.define "spine01" do |device|
    
    device.vm.hostname = "spine01" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.5.1"

    device.vm.provider :libvirt do |v|
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp8
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:44",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4069',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3069',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> leaf01:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:31",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4058',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3058',
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> leaf02:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4046',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3046',
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> leaf03:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4057',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3057',
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> leaf04:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:27",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4053',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3053',
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp31 --> spine02:swp31
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3056',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4056',
            :libvirt__iface_name => 'swp31',
            auto_config: false
      # link for swp32 --> spine02:swp32
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:24",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3052',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4052',
            :libvirt__iface_name => 'swp32',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    #Copy over Topology.dot File
    device.vm.provision "file", source: "topology.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:44 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:44", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:31 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:31", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1a --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1a", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2f --> swp3"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2f", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:27 --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:27", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2c --> swp31"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2c", NAME="swp31", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:24 --> swp32"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:24", NAME="swp32", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for leaf04 #####
  config.vm.define "leaf04" do |device|
    
    device.vm.hostname = "leaf04" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.5.1"

    device.vm.provider :libvirt do |v|
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:38",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4063',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3063',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> server03:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:32",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4059',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3059',
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> server04:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4048',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3048',
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp45 --> leaf04:swp46
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3040',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4040',
            :libvirt__iface_name => 'swp45',
            auto_config: false
      # link for swp46 --> leaf04:swp45
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:10",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4040',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3040',
            :libvirt__iface_name => 'swp46',
            auto_config: false
      # link for swp47 --> leaf04:swp48
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:22",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3051',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4051',
            :libvirt__iface_name => 'swp47',
            auto_config: false
      # link for swp48 --> leaf04:swp47
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:23",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4051',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3051',
            :libvirt__iface_name => 'swp48',
            auto_config: false
      # link for swp49 --> leaf03:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4049',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3049',
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> leaf03:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:05",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4033',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3033',
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> spine01:swp4
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:26",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3053',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4053',
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp4
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3055',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4055',
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    #Copy over Topology.dot File
    device.vm.provision "file", source: "topology.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:38 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:38", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:32 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:32", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1d --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1d", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0f --> swp45"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0f", NAME="swp45", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:10 --> swp46"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:10", NAME="swp46", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:22 --> swp47"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:22", NAME="swp47", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:23 --> swp48"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:23", NAME="swp48", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1f --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1f", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:05 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:05", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:26 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:26", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2a --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2a", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for leaf02 #####
  config.vm.define "leaf02" do |device|
    
    device.vm.hostname = "leaf02" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.5.1"

    device.vm.provider :libvirt do |v|
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp4
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4065',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3065',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> server01:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4038',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3038',
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> server02:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4039',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3039',
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp45 --> leaf02:swp46
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:06",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3034',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4034',
            :libvirt__iface_name => 'swp45',
            auto_config: false
      # link for swp46 --> leaf02:swp45
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:07",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4034',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3034',
            :libvirt__iface_name => 'swp46',
            auto_config: false
      # link for swp47 --> leaf02:swp48
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:20",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3050',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4050',
            :libvirt__iface_name => 'swp47',
            auto_config: false
      # link for swp48 --> leaf02:swp47
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:21",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4050',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3050',
            :libvirt__iface_name => 'swp48',
            auto_config: false
      # link for swp49 --> leaf01:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:09",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4035',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3035',
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> leaf01:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:02",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4031',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3031',
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> spine01:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:19",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3046',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4046',
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:33",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3060',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4060',
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    #Copy over Topology.dot File
    device.vm.provision "file", source: "topology.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3c --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3c", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0d --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0d", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0e --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0e", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:06 --> swp45"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:06", NAME="swp45", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:07 --> swp46"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:07", NAME="swp46", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:20 --> swp47"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:20", NAME="swp47", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:21 --> swp48"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:21", NAME="swp48", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:09 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:09", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:02 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:02", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:19 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:19", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:33 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:33", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for leaf03 #####
  config.vm.define "leaf03" do |device|
    
    device.vm.hostname = "leaf03" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.5.1"

    device.vm.provider :libvirt do |v|
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp5
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4066',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3066',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> server03:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:16",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4044',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3044',
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> server04:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:15",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4043',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3043',
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp45 --> leaf03:swp46
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3047',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4047',
            :libvirt__iface_name => 'swp45',
            auto_config: false
      # link for swp46 --> leaf03:swp45
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4047',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3047',
            :libvirt__iface_name => 'swp46',
            auto_config: false
      # link for swp47 --> leaf03:swp48
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3036',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4036',
            :libvirt__iface_name => 'swp47',
            auto_config: false
      # link for swp48 --> leaf03:swp47
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4036',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3036',
            :libvirt__iface_name => 'swp48',
            auto_config: false
      # link for swp49 --> leaf04:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3049',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4049',
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> leaf04:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:04",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3033',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4033',
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> spine01:swp3
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:2e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3057',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4057',
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp3
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:11",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3041',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4041',
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    #Copy over Topology.dot File
    device.vm.provision "file", source: "topology.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3e --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3e", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:16 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:16", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:15 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:15", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1b --> swp45"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1b", NAME="swp45", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1c --> swp46"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1c", NAME="swp46", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0a --> swp47"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0a", NAME="swp47", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0b --> swp48"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0b", NAME="swp48", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1e --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1e", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:04 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:04", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2e --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2e", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:11 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:11", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for leaf01 #####
  config.vm.define "leaf01" do |device|
    
    device.vm.hostname = "leaf01" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.5.1"

    device.vm.provider :libvirt do |v|
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp6
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:40",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4067',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3067',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> server01:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:03",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4032',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3032',
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> server02:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4037',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3037',
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp45 --> leaf01:swp46
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:13",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3042',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4042',
            :libvirt__iface_name => 'swp45',
            auto_config: false
      # link for swp46 --> leaf01:swp45
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:14",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4042',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3042',
            :libvirt__iface_name => 'swp46',
            auto_config: false
      # link for swp47 --> leaf01:swp48
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:28",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3054',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4054',
            :libvirt__iface_name => 'swp47',
            auto_config: false
      # link for swp48 --> leaf01:swp47
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:29",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4054',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3054',
            :libvirt__iface_name => 'swp48',
            auto_config: false
      # link for swp49 --> leaf02:swp49
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:08",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3035',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4035',
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> leaf02:swp50
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:01",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3031',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4031',
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> spine01:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:30",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3058',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4058',
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:17",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3045',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4045',
            :libvirt__iface_name => 'swp52',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    #Copy over Topology.dot File
    device.vm.provision "file", source: "topology.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"


    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_switch_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:40 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:40", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:03 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:03", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0c --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0c", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:13 --> swp45"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:13", NAME="swp45", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:14 --> swp46"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:14", NAME="swp46", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:28 --> swp47"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:28", NAME="swp47", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:29 --> swp48"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:29", NAME="swp48", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:08 --> swp49"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:08", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:01 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:01", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:30 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:30", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:17 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:17", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for server01 #####
  config.vm.define "server01" do |device|
    
    device.vm.hostname = "server01" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp9
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:46",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4070',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3070',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> leaf01:swp1
      device.vm.network "private_network",
            :mac => "00:03:00:11:11:01",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3032',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4032',
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> leaf02:swp1
      device.vm.network "private_network",
            :mac => "00:03:00:11:11:02",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3038',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4038',
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:46 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:46", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:11:11:01 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:11:11:01", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:11:11:02 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:11:11:02", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for server03 #####
  config.vm.define "server03" do |device|
    
    device.vm.hostname = "server03" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp10
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:48",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4071',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3071',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> leaf03:swp1
      device.vm.network "private_network",
            :mac => "00:03:00:33:33:01",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3044',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4044',
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> leaf04:swp1
      device.vm.network "private_network",
            :mac => "00:03:00:33:33:02",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3059',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4059',
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:48 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:48", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:33:33:01 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:33:33:01", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:33:33:02 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:33:33:02", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for server02 #####
  config.vm.define "server02" do |device|
    
    device.vm.hostname = "server02" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp11
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:4a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4072',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3072',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> leaf01:swp2
      device.vm.network "private_network",
            :mac => "00:03:00:22:22:01",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3037',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4037',
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> leaf02:swp2
      device.vm.network "private_network",
            :mac => "00:03:00:22:22:02",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3039',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4039',
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:4a --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:4a", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:22:22:01 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:22:22:01", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:22:22:02 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:22:22:02", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for server04 #####
  config.vm.define "server04" do |device|
    
    device.vm.hostname = "server04" 
    
    device.vm.box = "yk0/ubuntu-xenial"

    device.vm.provider :libvirt do |v|
      v.nic_model_type = 'e1000' 
      v.memory = 512
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp12
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:4c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4073',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3073',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> leaf03:swp2
      device.vm.network "private_network",
            :mac => "00:03:00:44:44:01",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3043',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4043',
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> leaf04:swp2
      device.vm.network "private_network",
            :mac => "00:03:00:44:44:02",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3048',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4048',
            :libvirt__iface_name => 'eth2',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/extra_server_config.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:4c --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:4c", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:44:44:01 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:44:44:01", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:44:44:02 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:44:44:02", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for netq-ts #####
  config.vm.define "netq-ts" do |device|
    
    device.vm.hostname = "netq-ts" 
    
    device.vm.box = "cumulus/ts"

    device.vm.provider :libvirt do |v|
      v.memory = 1024
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp3
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:3a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4064',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3064',
            :libvirt__iface_name => 'eth0',
            auto_config: false



    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    #Copy over Topology.dot File
    device.vm.provision "file", source: "topology.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"



    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:3a --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:3a", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end



end