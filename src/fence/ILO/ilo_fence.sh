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
##############################
# ha-lizard ILO fenceing helper #
##############################
exec 2>/dev/null
source /etc/ha-lizard/ha-lizard.init
source /etc/ha-lizard/ha-lizard.func

log "fence_host: Searching for IP address for host: $1"
HOST_IP=`(cat $FENCE_FILE_LOC/$FENCE_METHOD/$FENCE_METHOD.hosts | grep $1 | awk -F ":" '{print $2}')`
if [ $? = "0" ]
then
	log "fence_host: IP Address for host: $1 found: $HOST_IP"
	log "fence_host: Checking if fencing interface can be reached"
	ping -c 1 $HOST_IP
	if [ $? = "0" ]
	then
		log "fence_host: Host fence port on $HOST_IP response = OK"
                ######################################
                # Connect to ILO - Fence host
                ######################################
		log "fence_host: Fence $HOST_IP -  TCL/SSH connection start"
		rm -f $FENCE_FILE_LOC/$FENCE_METHOD/ilo_fence.out
		`$FENCE_FILE_LOC/$FENCE_METHOD/ilo_fence.tcl $HOST_IP root $FENCE_PASSWD "$2 /system1 -f"`

                ##############################
                # Log TCL session to log file
                ##############################
                while read l
                do
                	log "fence_host: TCL Session Output: $l"
                done < $FENCE_FILE_LOC/$FENCE_METHOD/ilo_fence.out

                ########################################
                # Reconnect to ILO - Check power status
                ########################################
                rm -f $FENCE_FILE_LOC/$FENCE_METHOD/ilo_fence.out
                log "fence_host: Checking power state of $1, ILO: $HOST_IP"
                `$FENCE_FILE_LOC/$FENCE_METHOD/ilo_fence.tcl $HOST_IP root $FENCE_PASSWD power`

                 ##############################
                 # Log TCL session to log file
                 ##############################
                 while read l
                 do
                 	log "fence_host: TCL Session Output: $l"
                 done < $FENCE_FILE_LOC/$FENCE_METHOD/ilo_fence.out

                 ####################################
                 # Read power and return exit status
                 ####################################
                 POWER_STATE=`cat $FENCE_FILE_LOC/$FENCE_METHOD/ilo_fence.out | grep "power: server power is currently:" | awk -F ": " '{print $3}'`
                 log "fence_host: Server Power = $POWER_STATE"
                 if [[ "$POWER_STATE" == *Off* ]]
                 then
                 	ILO_SERVER_POWER=0
                        #`echo "0" > $FENCE_FILE_LOC/$FENCE_METHOD/power_state`
			exit 0
                 else
                 	ILO_SERVER_POWER=1
                        #`echo "1" > $FENCE_FILE_LOC/$FENCE_METHOD/power_state`
			exit 1
                 fi
	fi
else
	log "ILO check failed - aborting fencing"
fi
