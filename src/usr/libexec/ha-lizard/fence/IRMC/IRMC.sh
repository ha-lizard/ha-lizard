#!/bin/bash

##################################################################################################
#
# HA-Lizard - Open Source High Availability Framework for Xen Cloud Platform and XenServer
#
# This script performs fencing operations via the IRMC interface.
#
##################################################################################################

# shellcheck source=/dev/null

# Redirect errors to null to suppress output
exec 2>/dev/null

# Source HA-Lizard configuration and functions
source /etc/ha-lizard/ha-lizard.init
source /usr/lib64/ha-lizard/ha-lizard.func

# Log the initial operation
log "fence_host: IRMC Searching for IP address for host: $1"

# Retrieve the host IP address from the configuration file
# TODO: exclude commented lines on the files
HOST_IP=$(grep "$1" "/etc/ha-lizard/$FENCE_METHOD/$FENCE_METHOD.hosts" | awk -F ":" '{print $2}')

# Check if the host IP was found
if [[ -n $HOST_IP ]]; then
  log "fence_host: IRMC IP Address for host $1 found: $HOST_IP"
  log "fence_host: IRMC Checking if fencing interface can be reached"

  # Test connectivity to the host via ping
  if ping -c 1 "$HOST_IP" >/dev/null; then
    log "fence_host: IRMC Host fence port on $HOST_IP response = OK"
    log "fence_host: IRMC Fence $HOST_IP - TCL/SSH connection start"

    # Remove any previous output file
    rm -f "$FENCE_LOG/irmc_fence.out"

    # Perform the requested action
    case $2 in
    start)
      MSG=$("$FENCE_FILE_LOC/$FENCE_METHOD/irmc_start.tcl" "$HOST_IP" admin "$FENCE_PASSWD")
      ;;
    stop)
      MSG=$("$FENCE_FILE_LOC/$FENCE_METHOD/irmc_stop.tcl" "$HOST_IP" admin "$FENCE_PASSWD")
      ;;
    reset)
      MSG=$("$FENCE_FILE_LOC/$FENCE_METHOD/irmc_reset.tcl" "$HOST_IP" admin "$FENCE_PASSWD")
      ;;
    *)
      log "fence_host: IRMC Invalid action specified: $2"
      exit 1
      ;;
    esac

    # Log the output message from the TCL session
    log "fence_host: IRMC TCL Session exit message: $MSG"

    # Check the power state of the server
    log "fence_host: IRMC Checking power state of $1, IRMC: $HOST_IP"
    POWER_STATE=$("$FENCE_FILE_LOC/$FENCE_METHOD/irmc_powerstate.tcl" "$HOST_IP" admin "$FENCE_PASSWD")
    log "fence_host: IRMC Server Power = $POWER_STATE"

    # Handle power state responses
    case $POWER_STATE in
    Off)
      exit 0
      ;;
    On)
      exit 1
      ;;
    *)
      log "fence_host: IRMC error checking power state msg=$POWER_STATE"
      exit 1
      ;;
    esac
  else
    log "fence_host: IRMC interface not responding to ping request. Server is down!"
    exit 0
  fi
else
  log "fence_host: IRMC interface IP address check failed."
  exit 1
fi
