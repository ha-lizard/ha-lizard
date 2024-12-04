#!/bin/bash
#################################################################################################
#
# HA-Lizard - Open Source High Availability Framework for Xen Cloud Platform and XenServer
#
# Copyright 2024 Salvatore Costantino
# ha@ixi0.com
#
# This file is part of HA-Lizard.
#
#    HA-Lizard is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    HA-Lizard is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with HA-Lizard.  If not, see <http://www.gnu.org/licenses/>.
#
##################################################################################################
exec 2>/dev/null
source /etc/ha-lizard/ha-lizard.init
source /etc/ha-lizard/ha-lizard.func

#####################################
# Connect to host
######################################

log "fence_xvm: Looking for UUID of host to fence."
FENCE_UUID=`(cat $FENCE_FILE_LOC/$FENCE_METHOD/$FENCE_METHOD.hosts | grep $1 | awk -F ":" '{print $2}')`
if [ -z "$FENCE_UUID" ]
then
	log "fence_xvm: $1 not found in $FENCE_FILE_LOC/$FENCE_METHOD/$FENCE_METHOD.hosts"
else
	log "fence_xvm: Checking if host $FENCE_IPADDRESS is live"
        ping -c 1 $FENCE_IPADDRESS
        if [ $? = "0" ]
	then
		log "fence_xvm: Host $ID response on $FENCE_IPADDRESS = OK"
		
		case $2 in
                	stop)
                        	XVM_COMMAND="xe vm-shutdown --force vm=$FENCE_UUID"
                        	;;
                	start)
                        	XVM_COMMAND="xe vm-start vm=$FENCE_UUID"
                        	;;
                	restart)
                        	XVM_COMMAND="xe vm-reboot --force vm=$FENCE_UUID"
                        	;;
		esac

                #####################################
                # Connect to host with ssh
                ######################################
		log "fence_xvm: Fence $FENCE_IPADDRESS -  TCL/SSH connection start"
		rm -f $FENCE_FILE_LOC/$FENCE_METHOD/xvm_fence.out
		`$FENCE_FILE_LOC/$FENCE_METHOD/xvm_fence.tcl $FENCE_IPADDRESS root $FENCE_PASSWD "$XVM_COMMAND"`

                ###############################
                # Write TCL session to log file
                ###############################
		while read l
		do
        		log "fence_xvm: TCL Session Output: $l"
		done < $FENCE_FILE_LOC/$FENCE_METHOD/xvm_fence.out

                ########################################
                # Reconnect to host - Check power status
                ########################################
		rm -f $FENCE_FILE_LOC/$FENCE_METHOD/xvm_fence.out
		log "fence_xvm: Checking power state of $FENCE_UUID"
		XVM_COMMAND="xe vm-list uuid=$FENCE_UUID"
		`$FENCE_FILE_LOC/$FENCE_METHOD/xvm_fence.tcl $FENCE_IPADDRESS root $FENCE_PASSWD "$XVM_COMMAND"`

                ###############################
                # Write TCL session to log file
                ###############################
		while read l
		do
        		log "fence_xvm: TCL Session Output: $l"
		done < $FENCE_FILE_LOC/$FENCE_METHOD/xvm_fence.out

                ####################################
                # Read power and return exit status
                ####################################
		POWER_STATE=`cat $FENCE_FILE_LOC/$FENCE_METHOD/xvm_fence.out | grep "power-state ( RO)" | awk -F ": " '{print $2}'`
		log "fence_host: Server Power = $POWER_STATE"
		if [[ $POWER_STATE == *halted* ]]
		then
			log "xvm_fence: Power State = halted"
			exit 0
		else
        		log "xvm_fence: Power State = unknown"
			exit 1
		fi


	else
		log "fence_xvm: Host $ID IP Address $FENCE_IPADDRESS not responding"
		exit 1
	fi	
fi
