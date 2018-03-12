# ONS 2017
This is a demo of Linux on both compute and network nodes. 
![Clos Topology](https://github.com/plumbis/ons2018/blob/master/ons2018.png "Clos Topology")

The network is built using Cumulus Linux within the network and Ubuntu hosts.

All servers are within the same VLAN. 

Cumulus NetQ is deployed on all compute and network nodes. 

An out of band management network exists, which all nodes are connected to. 

The node named `oob-mgmt-server` is the jump host, DHCP and Ansible server.
The node named `netq-ts` (not drawn in the topology) exists only on the management network and runs the Cumulus NetQ Telemetry Server. Vagrant assumes the NetQ TS image is called `cumulus/ts`. 

## Running the Lab
The Vagrantfile assumes a server with KVM, Libvirt and Vagrant installed.

First, launch the lab using Vagrant.
`vagrant up oob-mgmt-server oob-mgmt-switch`  
`vagrant up netq-ts`  
`vagrant up leaf01 leaf02 leaf03 leaf04`  
`vagrant up spine01 spine02 server01 server02 server03 server04`  

Now, SSH to the oob-mgmt-server and provision the lab with Ansible.
`vagrant ssh oob-mgmt-server`  
`cd ons2018`  
`ansible-playbook configure_lab.yml`  

After this the lab will be fully configured and any node can be accessed from the oob-mgmt-server.

## Simulating an L2 Loop
To simulate a L2 loop for 5 minutes before automatically correcting, run the playbook 
`ansible-playbook create_loop.yml`  

This will disable STP on all network devices for 5 minutes and then restore STP. 

During this time a broadcast storm will begin and the nodes may not be accessable via SSH or Ansible. You may still be able to access the nodes via the Libvirt console with `virsh console <domain_name>`  

After the STP loop is resolved, all devices should once again be reachable. 
