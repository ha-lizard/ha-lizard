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
# ha-lizard ILO fencing helper #
##############################

# shellcheck source=/dev/null

# Redirect errors to null (for troubleshooting, modify later if needed)
exec 2>/dev/null

# Source configuration and functions
source /etc/ha-lizard/ha-lizard.init
source /etc/ha-lizard/ha-lizard.func

# Log the host being searched
log "fence_host: Searching for IP address for host: $1"

# Extract the IP address associated with the host from the .hosts file
# TODO: exclude commented lines on the files
HOST_IP=$(grep "$1" "/etc/ha-lizard/$FENCE_METHOD/$FENCE_METHOD.hosts" | awk -F ":" '{print $2}')

# Check if the IP address was found
if [ -z "$HOST_IP" ]; then
  log "fence_host: IP Address for host: $1 not found"
  exit 1
fi

log "fence_host: IP Address for host: $1 found: $HOST_IP"

# Check if the fence interface is reachable via ping
log "fence_host: Checking if fencing interface can be reached"
if ! ping -c 1 "$HOST_IP" &>/dev/null; then
  log "fence_host: Ping to $HOST_IP failed"
  exit 1
fi

log "fence_host: Host fence port on $HOST_IP response = OK"

######################################
# Connect to ILO - Fence host
######################################

log "fence_host: Fence $HOST_IP -  TCL/SSH connection start"
rm -f "$FENCE_LOG/ilo_fence.out"

# Execute the TCL script to fence the host
"$FENCE_FILE_LOC/$FENCE_METHOD/ilo_fence.tcl" "$HOST_IP" root "$FENCE_PASSWD" "$2 /system1 -f"

##############################
# Log TCL session to log file
##############################

while read -r line; do
  log "fence_host: TCL Session Output: $line"
done <"$FENCE_LOG/ilo_fence.out"

########################################
# Reconnect to ILO - Check power status
########################################

rm -f "$FENCE_LOG/ilo_fence.out"
log "fence_host: Checking power state of $1, ILO: $HOST_IP"

# Execute the TCL script to check power state
"$FENCE_FILE_LOC/$FENCE_METHOD/ilo_fence.tcl" "$HOST_IP" root "$FENCE_PASSWD" power

##############################
# Log TCL session to log file
##############################

while read -r line; do
  log "fence_host: TCL Session Output: $line"
done <"$FENCE_LOG/ilo_fence.out"

####################################
# Read power and return exit status
####################################

POWER_STATE=$(grep "power: server power is currently:" "$FENCE_LOG/ilo_fence.out" | awk -F ": " '{print $3}')
log "fence_host: Server Power = $POWER_STATE"

# Check the power state and exit with the appropriate status
if [[ $POWER_STATE == *Off* ]]; then
  log "fence_host: Server power is OFF"
  # ILO_SERVER_POWER=0  # No need to set this, we handle the exit status directly
  exit 0
else
  log "fence_host: Server power is ON"
  # ILO_SERVER_POWER=1  # No need to set this, we handle the exit status directly
  exit 1
fi
