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
            :mac => "44:38:39:00:00:10",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4041',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3041',
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
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:10 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:10", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
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
            :mac => "44:38:39:00:00:0f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3041',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4041',
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> netq-ts:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:11",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3042',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4042',
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> leaf02:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:13",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3043',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4043',
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> leaf01:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:15",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3044',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4044',
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp5 --> spine02:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:17",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3045',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4045',
            :libvirt__iface_name => 'swp5',
            auto_config: false
      # link for swp6 --> spine01:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:19",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3046',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4046',
            :libvirt__iface_name => 'swp6',
            auto_config: false
      # link for swp7 --> server01:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3047',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4047',
            :libvirt__iface_name => 'swp7',
            auto_config: false
      # link for swp8 --> server02:eth0
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3048',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4048',
            :libvirt__iface_name => 'swp8',
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
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0f --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0f", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:11 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:11", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:13 --> swp3"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:13", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:15 --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:15", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:17 --> swp5"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:17", NAME="swp5", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:19 --> swp6"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:19", NAME="swp6", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1b --> swp7"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1b", NAME="swp7", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1d --> swp8"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1d", NAME="swp8", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
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
      # link for eth0 --> oob-mgmt-switch:swp5
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:18",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4045',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3045',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> leaf01:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:07",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4035',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3035',
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> leaf02:swp52
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4039',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3039',
            :libvirt__iface_name => 'swp2',
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
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:18 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:18", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:07 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:07", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0e --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0e", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
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
      # link for eth0 --> oob-mgmt-switch:swp6
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4046',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3046',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> leaf01:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4037',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3037',
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> leaf02:swp51
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:09",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4036',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3036',
            :libvirt__iface_name => 'swp2',
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
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1a --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1a", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0b --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0b", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:09 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:09", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
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
      # link for eth0 --> oob-mgmt-switch:swp3
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:14",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4043',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3043',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> server02:eth1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:04",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4033',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3033',
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> server02:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4038',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3038',
            :libvirt__iface_name => 'swp2',
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
            :mac => "44:38:39:00:00:08",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3036',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4036',
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:0d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3039',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4039',
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
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:14 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:14", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:04 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:04", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0c --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0c", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:02 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:02", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:08 --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:08", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0d --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0d", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
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
      # link for eth0 --> oob-mgmt-switch:swp4
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:16",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4044',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3044',
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
      # link for swp2 --> server01:eth2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:05",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4034',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3034',
            :libvirt__iface_name => 'swp2',
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
            :mac => "44:38:39:00:00:0a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3037',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4037',
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp1
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:06",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3035',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4035',
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
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:16 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:16", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:03 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:03", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:05 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:05", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:01 --> swp50"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:01", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0a --> swp51"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0a", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:06 --> swp52"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:06", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
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
      # link for eth0 --> oob-mgmt-switch:swp7
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4047',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3047',
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
      # link for eth2 --> leaf01:swp2
      device.vm.network "private_network",
            :mac => "00:03:00:11:11:02",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3034',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4034',
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
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1c --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1c", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
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
      # link for eth0 --> oob-mgmt-switch:swp8
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:1e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4048',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3048',
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> leaf02:swp1
      device.vm.network "private_network",
            :mac => "00:03:00:22:22:01",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '3033',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '4033',
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> leaf02:swp2
      device.vm.network "private_network",
            :mac => "00:03:00:22:22:02",
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
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1e --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1e", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
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
      # link for eth0 --> oob-mgmt-switch:swp2
      device.vm.network "private_network",
            :mac => "44:38:39:00:00:12",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => '4042',
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => '3042',
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
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:12 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:12", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
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