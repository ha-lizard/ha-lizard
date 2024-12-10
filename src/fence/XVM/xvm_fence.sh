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

# shellcheck source=/dev/null

# Redirect errors to /dev/null (for production, adjust as needed for troubleshooting)
exec 2>/dev/null

# Source required configuration and functions
source /etc/ha-lizard/ha-lizard.init
source /etc/ha-lizard/ha-lizard.func

#####################################
# Connect to Host
#####################################

log "fence_xvm: Searching for UUID of host to fence."

# Extract the UUID and IP address for the given host
FENCE_UUID=$(awk -F ':' -v host="$1" '$0 ~ host {print $2}' "/etc/ha-lizard/$FENCE_METHOD/$FENCE_METHOD.hosts")

# Validate the UUID and IP address
if [[ -z $FENCE_UUID || -z $FENCE_IPADDRESS ]]; then
  log "fence_xvm: Host $1 not found in /etc/ha-lizard/$FENCE_METHOD/$FENCE_METHOD.hosts"
  exit 1
fi

log "fence_xvm: Host $1 found. UUID: $FENCE_UUID, IP Address: $FENCE_IPADDRESS"

# Check if the host is reachable via ping
log "fence_xvm: Checking if host $FENCE_IPADDRESS is reachable."
if ! ping -c 1 "$FENCE_IPADDRESS" &>/dev/null; then
  log "fence_xvm: Host $1 IP Address $FENCE_IPADDRESS is not responding."
  exit 1
fi

log "fence_xvm: Host $1 is reachable. Proceeding with fencing."

#####################################
# Perform Fence Action
#####################################

# Determine the XVM command based on the action provided
case "$2" in
stop)
  XVM_COMMAND="xe vm-shutdown --force uuid=$FENCE_UUID"
  ;;
start)
  XVM_COMMAND="xe vm-start uuid=$FENCE_UUID"
  ;;
restart)
  XVM_COMMAND="xe vm-reboot --force uuid=$FENCE_UUID"
  ;;
*)
  log "fence_xvm: Invalid action: $2"
  exit 1
  ;;
esac

log "fence_xvm: Fence action selected: $2. Executing command on $FENCE_IPADDRESS."

# Remove old output file
rm -f "$FENCE_LOG/xvm_fence.out"

# Execute the fencing command via TCL
"$FENCE_FILE_LOC/$FENCE_METHOD/xvm_fence.tcl" "$FENCE_IPADDRESS" root "$FENCE_PASSWD" "$XVM_COMMAND"

#####################################
# Log TCL Session Output
#####################################

while read -r line; do
  log "fence_xvm: TCL Session Output: $line"
done <"$FENCE_LOG/xvm_fence.out"

#####################################
# Check Power State
#####################################

log "fence_xvm: Checking power state of $FENCE_UUID."
rm -f "$FENCE_LOG/xvm_fence.out"
XVM_COMMAND="xe vm-list uuid=$FENCE_UUID"
"$FENCE_FILE_LOC/$FENCE_METHOD/xvm_fence.tcl" "$FENCE_IPADDRESS" root "$FENCE_PASSWD" "$XVM_COMMAND"

while read -r line; do
  log "fence_xvm: TCL Session Output: $line"
done <"$FENCE_LOG/xvm_fence.out"

# Parse power state from the output
POWER_STATE=$(grep "power-state ( RO)" "$FENCE_LOG/xvm_fence.out" | awk -F ": " '{print $2}')

log "fence_xvm: Power state of $FENCE_UUID is $POWER_STATE."

# Determine exit status based on power state
if [[ $POWER_STATE == "halted" ]]; then
  log "fence_xvm: Power state is HALTED."
  exit 0
else
  log "fence_xvm: Power state is UNKNOWN or RUNNING."
  exit 1
fi
