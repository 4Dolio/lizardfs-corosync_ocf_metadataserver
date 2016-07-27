#!/bin/bash
# This script will attempt to initialize the corosync settings for LizardFS
# The SetupCorosyncServices.sh script should be used first to prep them.
# This only needs to be run on one member of the corosync cluster.

if [ ! `pgrep corosync` ] || [ ! `pgrep pacemaker` ] ; then
 echo " The corosync and/or pacemaker services do not appear to be running."
 echo " /etc/init.d/corosync start ; sleep 1 ; /etc/init.d/pacemaker start # To start the services"
 echo " # Pausing so you can break ^C and correct this problem" ; read foo
fi

if [ ! $FailoverIP ] ; then
 echo " You must set FailoverIP to the appropriate IP, such as 10.10.10.FloatIPLastOctet"
 echo " export FailoverIP=10.10.10.?? # Pausing so you can break ^C and correct this problem" ; read foo
else echo " FailoverIP is set to $FailoverIP" ; fi

if [ ! `which crm` ] ; then
 echo " The crm command does not appear to be available, maybe install crmsh" ; read foo ; exit
else echo " The crm command is available, continuing..." ; fi

echo -e "property stonith-enabled=false\ncommit"   | crm configure
	echo " Disabled STONITH, should look into ability to enable. "
echo -e "property no-quorum-policy=ignore\ncommit" | crm configure
	echo " Disable quorum handling, should look into ability to enable. "
echo -e "primitive Failover-IP ocf:heartbeat:IPaddr2 params ip=$FailoverIP cidr_netmask=24 op monitor interval=1s\ncommit" | crm configure
	echo " Added VirtualIP"
crm configure rsc_defaults resource-stickiness=100
	echo " Changed the resource stickiness to prevent unnecessary movement of resources "
primitiv='primitive lizardfs-master ocf:lizardfs:metadataserver params master_cfg="/etc/mfs/mfsmaster.cfg"' # Define the primitive for lizardfs-master 
monitor='op monitor role="Master" interval="1s" timeout="30" op monitor role="Slave" interval="2s" timeout="40"' # Primitives monitor settings 
transit='op start interval="0" timeout="1800" op stop interval="0" timeout="1800" op promote interval="0" timeout="1800" op demote interval="0" timeout="1800"' # Primitives transitions. 
echo -e $primitiv $monitor $transit | crm configure
	echo " created the Primitive with it's monitor and transition settings. "
echo -e 'ms lizardfs-ms lizardfs-master meta master-max="1" master-node-max="1" clone-node-max="1" notify="true" target-role="Master"' | crm configure
	echo " Setup Primitive "
echo -e 'colocation ip-with-master inf: Failover-IP lizardfs-ms:Master' | crm configure
	echo " Define how the IP and Master primitives relate "
echo -e 'order master-after-ip inf: Failover-IP:start lizardfs-ms:promote' | crm configure
	echo " Define how the IP and master will transition. "

echo
echo " Finished Initializing corosync settings for LizardFS services and Failover-IP address"
echo " /etc/init.d/pacemaker stop ; /etc/init.d/corosync stop # Stop the managed service by pacemaker and then corosync. "
echo " /etc/init.d/corosync start ; sleep 1 ; /etc/init.d/pacemaker start # Startup the corosync and pacemaker services. "
echo "  While it should be safe to run this multiple times it will likely have no effect after the initial run."
echo " #Run# rm -rfv /var/lib/pengine/* /var/lib/heartbeat/crm/* # To Destroy the old cluster information and start over. "

##