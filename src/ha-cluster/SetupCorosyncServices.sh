#!/bin/bash
# This script will attempt to "fix" corosync and pacemaker services on Debian distributions
# to work properly with the LizardFS metadataserver OCF Script and Floating FailoverIP

if [ `dpkg -l | grep -c corosync` -lt 1 ]  ; then echo " corosync does not appear to be installed"  ; fi
if [ `dpkg -l | grep -c pacemaker` -lt 1 ] ; then echo " pacemaker does not appear to be installed" ; fi
if [ ! $mcastaddr ] ; then # for corosync use
 echo " You must set mcastaddr to the appropriate IP, such as 226.94.1.FloatIPLastOctet"
 echo " export mcastaddr=226.94.1.?? # Pausing so you can break ^C and correct this problem" ; read foo
else echo " mcastaddr is set to $mcastaddr" ; fi

if [ ! $FailoverIP ] ; then # for lizardfs cluster master address
 echo " You must set FailoverIP to the appropriate IP, such as 10.10.10.FloatIPLastOctet"
 echo " export FailoverIP=10.10..?? # Pausing so you can break ^C and correct this problem" ; read foo
else echo " FailoverIP is set to $FailoverIP" ; fi
bindnetaddr=$( echo $FailoverIP | cut -f1-3 -d\. ) # Assumes a Class C block
echo " bindnetaddr is set to $bindnetaddr.0"

sed -i 's/^.*ver:.*/ \tver: 1/' /etc/corosync/corosync.conf # This makes pacemaker behave as an independent service 
sed -i 's/^# Required-Stop:.*/# Required-Stop:\t$network corosync/' /etc/init.d/pacemaker # Pacemaker needs to know it must stop before corosync can stop 
sed -i 's/^# Default-Start:.*/# Default-Start:\t2 3 4 5/' /etc/init.d/pacemaker # Since pacemaker is an independent service we should start 
sed -i 's/^# Default-Stop:.*/# Default-Stop: \t0 1 6/' /etc/init.d/pacemaker # and stop it. 
sed -i 's%echo -n "Starting $desc: "$%echo -n "Starting $desc: " ; sleep 2 # might fail to start if corosync also started recently%' /etc/init.d/pacemaker
update-rc.d pacemaker defaults ; update-rc.d corosync defaults # Fix up the default for corosync and pacemaker 
sed -i 's/mcastaddr: .*/mcastaddr: '$mcastaddr'/' /etc/corosync/corosync.conf # VERIFY THIS IS CORRECT FOR THE INTENDED CLUSTER 
sed -i 's/^.*mcastaddr: .*/\t\tmcastaddr: '$mcastaddr'/' /etc/corosync/corosync.conf # Deb 8.5-ish has this commented out by default
sed -i 's/bindnetaddr: 127.0.0.1/bindnetaddr: '$bindnetaddr'/' /etc/corosync/corosync.conf # this should match the network on which the floating IP will live. 
sed -i 's/bindnetaddr: .*/bindnetaddr: '$bindnetaddr.0/ /etc/corosync/corosync.conf # this should match the network on which the floating IP will live.
sed -i 's/START=no/START=yes/' /etc/default/corosync 

grep "ver:\|Required\|Default\|addr:\|START" /etc/init.d/pacemaker /etc/default/corosync /etc/corosync/corosync.conf

echo " You should run corosync-keygen on your first node to generate an /etc/corosync/authkey which should be coppied to all other nodes."

##
