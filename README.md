# ONS 2017
This is a demo of Linux on both compute and network nodes. 
![Clos Topology](https://github.com/plumbis/nfd17/blob/master/ons2018.png "Clos Topology")

The network is built using Cumulus Linux within the network and Ubuntu hosts.

All servers are within the same VLAN. 

Cumulus NetQ is deployed on all compute and network nodes. 

An out of band management network exists, which all nodes are connected to. 

The node named `oob-mgmt-server` is the jump host, DHCP and Ansible server.
The node named `netq-ts` (not drawn in the topology) exists only on the management network and runs the Cumulus NetQ Telemetry Server. Vagrant assumes the NetQ TS image is called `cumulus/ts`. 

## Running the Lab
The Vagrantfile assumes a server with KVM, Libvirt and Vagrant installed.
`vagrant up oob-mgmt-server oob-mgmt-switch` 
`vagrant up netq-ts` 
`vagrant up leaf01 leaf02 leaf03 leaf04` 
`vagrant up spine01 spine02 server01 server02 server03 server04` 
`vagrant ssh oob-mgmt-server` 

At this point you can SSH to any host by hostname
`ssh leaf01` 
or 
`ssh netq-ts` 