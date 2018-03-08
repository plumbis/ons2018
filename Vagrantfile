# Created by Topology-Converter v5.0.0
#    Template Revision: v5.0.0
#    https://github.com/cumulusnetworks/topology_converter
#    using topology data from: test.dot
#    built with the following args: ['test.dot', '-c', '-p', 'libvirt', '-s', '3030']
#    NOTE: in order to use this Vagrantfile you will need:
#        - Vagrant(v2.0.2+) installed: http://www.vagrantup.com/downloads
#        - the "helper_scripts" directory that comes packaged with topology-converter.py
#        - Libvirt Installed -- guide to come
#        - Vagrant-Libvirt Plugin installed: $ vagrant plugin install vagrant-libvirt
#        - Start with "vagrant up --provider=libvirt --no-parallel"
#
#  Libvirt Start Port: 3030
#  Libvirt Port Gap: 1000

# Set the default provider to libvirt in the case they forget
# --provider=libvirt or if someone destroys a machine it reverts to virtualbox
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

Vagrant.require_version ">= 2.0.2"

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

    device.vm.provider "libvirt" do |v|      
        v.memory = 512    
        

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true

    # NETWORK INTERFACES
    # link for eth1 --> oob-mgmt-switch:swp1
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:19',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1037',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9037',
        :libvirt__iface_name => 'eth1',
        auto_config: false
    # link for eth0 --> NOTHING:eth1
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:2b',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1046',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9046',
        :libvirt__iface_name => 'eth0',
        auto_config: false 

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"
    # Copy over DHCP files and MGMT Network Files
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
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:19 --> eth1'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:19", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:2b --> eth0'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2b", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule

    device.vm.provision :shell , :inline => <<-vagrant_interface_rule
      echo '  INFO: Adding UDEV Rule: Vagrant interface = vagrant'
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
    device.vm.box = "cumuluscommunity/cumulus-vx"

    device.vm.provider "libvirt" do |v|      
        v.memory = 512    
        

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true

    # NETWORK INTERFACES
    # link for eth0 --> NOTHING:eth0
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:29',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1045',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9045',
        :libvirt__iface_name => 'eth0',
        auto_config: false
    # link for swp8 --> spine01:eth0
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:28',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9044',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1044',
        :libvirt__iface_name => 'swp8',
        auto_config: false
    # link for swp2 --> leaf04:eth0
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:1c',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9038',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1038',
        :libvirt__iface_name => 'swp2',
        auto_config: false
    # link for swp3 --> netq-ts:eth0
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:1e',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9039',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1039',
        :libvirt__iface_name => 'swp3',
        auto_config: false
    # link for swp1 --> oob-mgmt-server:eth1
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:1a',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9037',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1037',
        :libvirt__iface_name => 'swp1',
        auto_config: false
    # link for swp6 --> leaf01:eth0
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:24',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9042',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1042',
        :libvirt__iface_name => 'swp6',
        auto_config: false
    # link for swp7 --> spine02:eth0
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:26',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9043',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1043',
        :libvirt__iface_name => 'swp7',
        auto_config: false
    # link for swp4 --> leaf02:eth0
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:20',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9040',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1040',
        :libvirt__iface_name => 'swp4',
        auto_config: false
    # link for swp5 --> leaf03:eth0
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:22',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9041',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1041',
        :libvirt__iface_name => 'swp5',
        auto_config: false 

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    #Copy over Topology.dot File
    device.vm.provision "file", source: "test.dot", destination: "~/topology.dot"
    device.vm.provision :shell, privileged: false, inline: "sudo mv ~/topology.dot /etc/ptm.d/topology.dot"
 
    # Transfer Bridge File
    device.vm.provision "file", source: "./helper_scripts/auto_mgmt_network/bridge-untagged", destination: "~/bridge-untagged"
    device.vm.provision :shell , path: "./helper_scripts/OOB_switch_config.sh"
        
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
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:29 --> eth0'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:29", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:28 --> swp8'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:28", NAME="swp8", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:1c --> swp2'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1c", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:1e --> swp3'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1e", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:1a --> swp1'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1a", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:24 --> swp6'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:24", NAME="swp6", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:26 --> swp7'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:26", NAME="swp7", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:20 --> swp4'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:20", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:22 --> swp5'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:22", NAME="swp5", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule

    device.vm.provision :shell , :inline => <<-vagrant_interface_rule
      echo '  INFO: Adding UDEV Rule: Vagrant interface = vagrant'
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
    device.vm.box_version = "3.5.3"

    device.vm.provider "libvirt" do |v|      
        v.memory = 768    
        

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true

    # NETWORK INTERFACES
    # link for swp2 --> leaf02:swp52
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:17',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9036',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1036',
        :libvirt__iface_name => 'swp2',
        auto_config: false
    # link for swp3 --> leaf03:swp52
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:03',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9026',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1026',
        :libvirt__iface_name => 'swp3',
        auto_config: false
    # link for swp1 --> leaf01:swp52
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:0b',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9030',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1030',
        :libvirt__iface_name => 'swp1',
        auto_config: false
    # link for swp4 --> leaf04:swp52
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:0f',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9032',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1032',
        :libvirt__iface_name => 'swp4',
        auto_config: false
    # link for eth0 --> oob-mgmt-switch:swp7
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:25',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1043',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9043',
        :libvirt__iface_name => 'eth0',
        auto_config: false 

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    #Copy over Topology.dot File
    device.vm.provision "file", source: "test.dot", destination: "~/topology.dot"
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
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:17 --> swp2'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:17", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:03 --> swp3'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:03", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:0b --> swp1'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0b", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:0f --> swp4'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0f", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:25 --> eth0'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:25", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule

    device.vm.provision :shell , :inline => <<-vagrant_interface_rule
      echo '  INFO: Adding UDEV Rule: Vagrant interface = vagrant'
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
    device.vm.box_version = "3.5.3"

    device.vm.provider "libvirt" do |v|      
        v.memory = 768    
        

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true

    # NETWORK INTERFACES
    # link for swp2 --> leaf02:swp51
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:09',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9029',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1029',
        :libvirt__iface_name => 'swp2',
        auto_config: false
    # link for swp3 --> leaf03:swp51
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:07',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9028',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1028',
        :libvirt__iface_name => 'swp3',
        auto_config: false
    # link for swp1 --> leaf01:swp51
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:13',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9034',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1034',
        :libvirt__iface_name => 'swp1',
        auto_config: false
    # link for swp4 --> leaf04:swp51
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:0d',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9031',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1031',
        :libvirt__iface_name => 'swp4',
        auto_config: false
    # link for eth0 --> oob-mgmt-switch:swp8
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:27',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1044',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9044',
        :libvirt__iface_name => 'eth0',
        auto_config: false 

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    #Copy over Topology.dot File
    device.vm.provision "file", source: "test.dot", destination: "~/topology.dot"
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
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:09 --> swp2'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:09", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:07 --> swp3'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:07", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:13 --> swp1'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:13", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:0d --> swp4'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0d", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:27 --> eth0'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:27", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule

    device.vm.provision :shell , :inline => <<-vagrant_interface_rule
      echo '  INFO: Adding UDEV Rule: Vagrant interface = vagrant'
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
    device.vm.box_version = "3.5.3"

    device.vm.provider "libvirt" do |v|      
        v.memory = 768    
        

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true

    # NETWORK INTERFACES
    # link for swp49 --> leaf03:swp49
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:15',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9035',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1035',
        :libvirt__iface_name => 'swp49',
        auto_config: false
    # link for swp50 --> leaf03:swp50
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:05',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9027',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1027',
        :libvirt__iface_name => 'swp50',
        auto_config: false
    # link for swp51 --> spine01:swp4
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:0c',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1031',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9031',
        :libvirt__iface_name => 'swp51',
        auto_config: false
    # link for swp52 --> spine02:swp4
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:0e',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1032',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9032',
        :libvirt__iface_name => 'swp52',
        auto_config: false
    # link for eth0 --> oob-mgmt-switch:swp2
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:1b',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1038',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9038',
        :libvirt__iface_name => 'eth0',
        auto_config: false 

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    #Copy over Topology.dot File
    device.vm.provision "file", source: "test.dot", destination: "~/topology.dot"
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
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:15 --> swp49'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:15", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:05 --> swp50'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:05", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:0c --> swp51'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0c", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:0e --> swp52'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0e", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:1b --> eth0'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1b", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule

    device.vm.provision :shell , :inline => <<-vagrant_interface_rule
      echo '  INFO: Adding UDEV Rule: Vagrant interface = vagrant'
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
    device.vm.box_version = "3.5.3"

    device.vm.provider "libvirt" do |v|      
        v.memory = 768    
        

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true

    # NETWORK INTERFACES
    # link for swp49 --> leaf01:swp49
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:11',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9033',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1033',
        :libvirt__iface_name => 'swp49',
        auto_config: false
    # link for swp50 --> leaf01:swp50
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:01',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '9025',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '1025',
        :libvirt__iface_name => 'swp50',
        auto_config: false
    # link for swp51 --> spine01:swp2
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:08',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1029',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9029',
        :libvirt__iface_name => 'swp51',
        auto_config: false
    # link for swp52 --> spine02:swp2
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:16',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1036',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9036',
        :libvirt__iface_name => 'swp52',
        auto_config: false
    # link for eth0 --> oob-mgmt-switch:swp4
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:1f',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1040',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9040',
        :libvirt__iface_name => 'eth0',
        auto_config: false 

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    #Copy over Topology.dot File
    device.vm.provision "file", source: "test.dot", destination: "~/topology.dot"
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
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:11 --> swp49'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:11", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:01 --> swp50'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:01", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:08 --> swp51'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:08", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:16 --> swp52'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:16", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:1f --> eth0'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1f", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule

    device.vm.provision :shell , :inline => <<-vagrant_interface_rule
      echo '  INFO: Adding UDEV Rule: Vagrant interface = vagrant'
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
    device.vm.box_version = "3.5.3"

    device.vm.provider "libvirt" do |v|      
        v.memory = 768    
        

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true

    # NETWORK INTERFACES
    # link for swp49 --> leaf04:swp49
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:14',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1035',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9035',
        :libvirt__iface_name => 'swp49',
        auto_config: false
    # link for swp50 --> leaf04:swp50
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:04',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1027',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9027',
        :libvirt__iface_name => 'swp50',
        auto_config: false
    # link for swp51 --> spine01:swp3
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:06',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1028',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9028',
        :libvirt__iface_name => 'swp51',
        auto_config: false
    # link for swp52 --> spine02:swp3
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:02',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1026',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9026',
        :libvirt__iface_name => 'swp52',
        auto_config: false
    # link for eth0 --> oob-mgmt-switch:swp5
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:21',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1041',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9041',
        :libvirt__iface_name => 'eth0',
        auto_config: false 

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    #Copy over Topology.dot File
    device.vm.provision "file", source: "test.dot", destination: "~/topology.dot"
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
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:14 --> swp49'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:14", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:04 --> swp50'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:04", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:06 --> swp51'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:06", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:02 --> swp52'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:02", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:21 --> eth0'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:21", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule

    device.vm.provision :shell , :inline => <<-vagrant_interface_rule
      echo '  INFO: Adding UDEV Rule: Vagrant interface = vagrant'
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
    device.vm.box_version = "3.5.3"

    device.vm.provider "libvirt" do |v|      
        v.memory = 768    
        

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true

    # NETWORK INTERFACES
    # link for swp49 --> leaf02:swp49
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:10',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1033',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9033',
        :libvirt__iface_name => 'swp49',
        auto_config: false
    # link for swp50 --> leaf02:swp50
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:00',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1025',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9025',
        :libvirt__iface_name => 'swp50',
        auto_config: false
    # link for swp51 --> spine01:swp1
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:12',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1034',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9034',
        :libvirt__iface_name => 'swp51',
        auto_config: false
    # link for swp52 --> spine02:swp1
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:0a',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1030',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9030',
        :libvirt__iface_name => 'swp52',
        auto_config: false
    # link for eth0 --> oob-mgmt-switch:swp6
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:23',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1042',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9042',
        :libvirt__iface_name => 'eth0',
        auto_config: false 

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    #Copy over Topology.dot File
    device.vm.provision "file", source: "test.dot", destination: "~/topology.dot"
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
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:10 --> swp49'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:10", NAME="swp49", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:00 --> swp50'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:00", NAME="swp50", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:12 --> swp51'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:12", NAME="swp51", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:0a --> swp52'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0a", NAME="swp52", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:23 --> eth0'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:23", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule

    device.vm.provision :shell , :inline => <<-vagrant_interface_rule
      echo '  INFO: Adding UDEV Rule: Vagrant interface = vagrant'
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
    device.vm.box = "CumulusCommunity/netq-ts"

    device.vm.provider "libvirt" do |v|      
        v.memory = 1024    
        

    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true

    # NETWORK INTERFACES
    # link for eth0 --> oob-mgmt-switch:swp3
        device.vm.network "private_network",
        :mac => '44:38:39:00:00:1d',
        :libvirt__tunnel_type => 'udp',
        :libvirt__tunnel_local_ip => '127.0.0.1',
        :libvirt__tunnel_local_port => '1039',
        :libvirt__tunnel_ip => '127.0.0.1',
        :libvirt__tunnel_port => '9039',
        :libvirt__iface_name => 'eth0',
        auto_config: false 

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    

    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
      if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
        rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
      fi
      rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
    delete_udev_directory
    
    device.vm.provision :shell , :inline => <<-udev_rule
      echo '  INFO: Adding UDEV Rule: 44:38:39:00:00:1d --> eth0'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1d", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
    udev_rule

    device.vm.provision :shell , :inline => <<-vagrant_interface_rule
      echo '  INFO: Adding UDEV Rule: Vagrant interface = vagrant'
      echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
      echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
      cat /etc/udev/rules.d/70-persistent-net.rules
    vagrant_interface_rule

    # Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

  end
end