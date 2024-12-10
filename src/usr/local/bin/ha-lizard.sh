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

########################################
# Certain system crashes can cause
# /etc/ha-lizard/ha-lizard.pool.conf to
# be empty. This will put some default
# params in to bootstrap execution
# Subsequent run will inherit real
# configuration params stored in xapi db
# and write to this file.
#######################################
if [ -s /etc/ha-lizard/ha-lizard.pool.conf ]; then
  # shellcheck source=/dev/null
  source /etc/ha-lizard/ha-lizard.pool.conf #global configuration parameters for all hosts in pool - dynamic for pool
else
  cat /etc/ha-lizard/install.params >/etc/ha-lizard/ha-lizard.pool.conf
fi

#######################################
# Read in environment, override params
# and function sources
#######################################
# shellcheck source=/dev/null
source /etc/ha-lizard/ha-lizard.init #override configuration settings for this host - static for this host
# shellcheck source=/dev/null
source /usr/lib64/ha-lizard/ha-lizard.func

#######################################
# Set any args passed in
#######################################
for input_param in "${@}"; do
  log "initializing passed in parameter [$input_param]"
  eval "$input_param"
done
LOG_TERMINAL=${log_terminal:-false}
log "LOG_TERMINAL = [$LOG_TERMINAL]"

###############################################
# Process any daily or hourly tasks here
###############################################
if [ ! -e /"$STATE_PATH"/time_day ]; then
  update_day
else
  DAY_CACHE=$(cat /"$STATE_PATH"/time_day)
  DAY_NOW=$(date +%e)
  if [ "${DAY_CACHE}" -ne "${DAY_NOW}" ]; then
    update_day
    #######################################
    ## Perform any daily tasks here
    #######################################
  fi
fi

if [ ! -e /"$STATE_PATH"/time_hour ]; then
  update_hour
else
  HOUR_CACHE=$(cat /"$STATE_PATH"/time_hour)
  HOUR_NOW=$(date +%k)
  if [ "${HOUR_CACHE}" -ne "${HOUR_NOW}" ]; then
    update_hour
    #######################################
    ## Perform any hourly tasks here
    #######################################
    if [ "${DISK_MONITOR}" -eq 1 ]; then
      DISK_HEALTH_RESULT=$(${CHECK_DISK})
      RETVAL=$?
      if [ $RETVAL -ne 0 ]; then
        log "Disk errors detected [${DISK_HEALTH_RESULT}]"
        email "[$HOUR_NOW] Disk errors detected [${DISK_HEALTH_RESULT}]"
      else
        log "Disk status OK [${DISK_HEALTH_RESULT}]"
      fi
    else
      log "[DISK_MONITOR] is disabled"
    fi
  fi
fi

###############################################
# Make sure the mail spool dir exists - if not
# create it here. Mail spool is stored in ram
# and will not survive a reboot.
# Mail spool dir is used here to store iteration
# counter - used to suppress email alerts
# while initializing at first run.
###############################################
if [ -d "$MAIL_SPOOL" ]; then
  log "Mail Spool Directory Found $MAIL_SPOOL"
else
  if mkdir "$MAIL_SPOOL"; then
    log "Successfully created mail spool directory $MAIL_SPOOL"
  else
    log "Failed to create mail spool - not suppressing duplicate notices"
  fi
fi

##############################################
# Check if count file exists - else create one
##############################################
if [ ! -f "$MAIL_SPOOL"/count ]; then
  touch "$MAIL_SPOOL"/count
  echo 0 >"$MAIL_SPOOL"/count
fi

CURRENT_COUNT=$(cat "$MAIL_SPOOL"/count)

if [ "$CURRENT_COUNT" -gt 10000 ]; then
  log "Resetting iteration counter"
  echo 1 >"$MAIL_SPOOL"/count
  CURRENT_COUNT=0
fi

NEW_COUNT=$((CURRENT_COUNT + 1))
log "This iteration is count $NEW_COUNT"
echo $NEW_COUNT >"$MAIL_SPOOL"/count

#######################################
# Check whether I am a master or a slave
#######################################
if [ -e /etc/xensource/pool.conf ]; then
  log "Checking if this host is a Pool Master or Slave"
  STATE=$(/bin/cat /etc/xensource/pool.conf)
  log "This host's pool status = $STATE"
else
  log "/etc/xensource/pool.conf missing. Cannot determine master/slave status."
  email "/etc/xensource/pool.conf missing. Cannot determine master/slave status."
  exit 1
fi

#######################################
# Check if ha-lizard is enabled for pool
#######################################

if [ "$STATE" = "master" ]; then
  log "Checking if ha-lizard is enabled for this pool"
  check_ha_enabled
  case $? in
  0)
    log "ha-lizard is enabled"
    ####################################
    # Added 1.7.8 - make sure XenServer
    # HA is not active before going
    # any further
    ####################################
    if ! check_xs_ha; then
      log "ERROR - Detected alternate HA configured for pool- disabling HA-Lizard"
      email "ERROR - Detected alternate HA configured for pool- disabling HA-Lizard"
      disable_ha_lizard
      if [ $? -eq 1 ]; then
        log "Conflicting High Availability detected - failed to disable HA-Lizard"
        email "Conflicting High Availability detected - failed to disable HA-Lizard"
      fi
      exit 1
    fi
    ;;
  1)
    log "ha-lizard is disabled"
    ##################################
    ## Version 2.2.1 - set autoselect_slave
    ## while ha-lizard is disabled
    ##################################
    log "Calling autoselect_slave with ha disabled"
    autoselect_slave
    ##################################
    # Update state files before exit
    ##################################
    log "Updating state information"
    write_pool_state
    #################################
    # Update local conf before exit
    #################################
    update_global_conf_params
    exit $?
    ;;
  2)
    log "ha-lizard-enabled state unknown - exiting"
    exit 2
    ;;
  3)
    log "ha-lizard is enabled but host is in maintenance mode"
    ##################################
    # Update state files before exit
    ##################################
    log "Updating state information"
    write_pool_state
    #################################
    # Update local conf before exit
    #################################
    update_global_conf_params
    exit $?
    ;;
  *)
    log "check_ha_enabled returned error: $? - exiting"
    exit $?
    ;;
  esac
fi

##############################################
# Update global pool configuration parameters
# for next run
# Version 1.8.8 moved update params to
# function update_global_conf_params
###########################################
update_global_conf_params

###############################################
# IF master - attempt to start any
# appliances or VMs (depending on OP_MODE)
# with HA enabled that are not running
###############################################

if [ "$STATE" = "master" ]; then
  ###########################
  ## Begin - Version 2.1
  ## added master management
  ## link tracking
  ###########################

  MASTER_UUID=$($XE host-list hostname="$(hostname)" --minimal)
  $XE host-param-set uuid="$MASTER_UUID" other-config:XenCenter.CustomFields."$XC_FIELD_NAME"="master"
  #####################################
  ## Check MGT link state
  #####################################
  check_master_mgt_link_state
  RETVAL=$?
  if [ $RETVAL -eq 0 ]; then
    log "Master management link OK - checking prior link state"
    if [ -e "$STATE_PATH"/master_mgt_down ]; then
      log "Management link transitioned from DOWN -> UP"
      #######################################
      ## MAke sure we give the slave enough
      ## time to takeover in case this was
      ## a brief master failure
      #######################################
      log "Master sleep for XAPI_COUNT [ $XAPI_COUNT ] [X] XAPI_DELAY [ $XAPI_DELAY ] + 10"
      MASTER_SLEEP=$((XAPI_COUNT * XAPI_DELAY + 10))
      log "Delaying master execution [ $MASTER_SLEEP ] seconds"
      sleep $MASTER_SLEEP
      rm -f "$STATE_PATH"/master_mgt_down
      service_execute xapi restart
      exit 0
    fi
  else
    NOW=$(date +"%s")
    log "Master management link = DOWN"
    echo "$NOW" >"$STATE_PATH"/master_mgt_down
  fi

  MGT_LINK_STATE=$RETVAL
  while :; do
    if [ $MGT_LINK_STATE -ne 0 ]; then
      if [ ! "$MGT_LINK_LOSS_TOLERANCE" ]; then
        log "MGT_LINK_LOSS_TOLERANCE not set - defaulting to [ 5 ] seconds"
        MGT_LINK_LOSS_TOLERANCE=5
      fi

      TIME_NOW=$(date +"%s")
      TIME_FAILED=$(cat "$STATE_PATH"/master_mgt_down)
      TIME_ELAPSED=$((TIME_NOW - TIME_FAILED))
      log "TIMENOW = $TIME_NOW"
      log "TIMEFAILED = $TIME_FAILED"
      log "TIMEELAPSED = $TIME_ELAPSED"
      log "MGT link failure duration = [ $TIME_ELAPSED ] Tolerance = [ $MGT_LINK_LOSS_TOLERANCE seconds ]"
      if [ $TIME_ELAPSED -gt "$MGT_LINK_LOSS_TOLERANCE" ]; then
        log "Management link outage tolerance [ ${MGT_LINK_LOSS_TOLERANCE} seconds ] reached - shutting down ALL VMs on Master [ $MASTER_UUID ]"
        check_replication_link_state
        RETVAL=$?
        if [ $RETVAL -eq 0 ]; then
          stop_vms_on_host "${MASTER_UUID}"
        elif [ $RETVAL -eq 1 ]; then
          log "ABORTING VM SHUTDOWN: Replication network is connected!!"
        fi

      fi

      log "MGT link is down - waiting for link to be restored"
      sleep 5

      check_master_mgt_link_state
      MGT_LINK_STATE=$?
      if [ $MGT_LINK_STATE -eq 0 ]; then
        log "MGT link has been restored"
        exit 0
      fi
    else
      break
    fi
  done
  #######################
  ## End addition of
  ## master management
  ## link tracking
  #######################

  log "This host detected as pool  Master"

  # Use 'grep -c' to directly count matching lines
  NUM_HOSTS=$($XE host-list | grep -c "uuid ( RO)")

  # Check if the command succeeded and show the result
  if [ "$NUM_HOSTS" -gt 0 ]; then
    log "Found $NUM_HOSTS hosts in pool"
  else
    log "Failed to find total number of hosts in pool"
  fi

  #############################
  # Added 2.1 - make sure
  # HA enabled state is valid
  # for ALL VMs else set false
  #############################
  validate_vm_ha_state

  log "Calling function write_pool_state"
  write_pool_state &
  log "Calling function autoselect_slave"
  autoselect_slave &
  log "Calling function check_slave_status"
  check_slave_status

  case "$?" in
  2)
    log "Function check_slave_status Host Power = Off, calling vm_mon"
    vm_mon
    ;;
  1)
    log "Function check_slave_status failed to fence failed host.. checking whether to attempt starting failed VMs"
    log "FENCE_HA_ONFAIL is set to: $FENCE_HA_ONFAIL"
    if [ "$FENCE_HA_ONFAIL" = "1" ]; then
      log "FENCE_HA_ONFAIL is set to: $FENCE_HA_ONFAIL, calling vm_mon"
      vm_mon
    else
      log "FENCE_HA_ONFAIL is set to: $FENCE_HA_ONFAIL, not attempting to start VMs"
    fi
    ;;
  0)
    log "Function check_slave_status reported no failures: calling vm_mon"
    vm_mon
    ##############################
    # 1.8.9 clear any possible
    # prev_boot flags on no slave
    # errors detected
    ##############################
    $ECHO "0" >"$STATE_PATH"/rebooted
    ;;
  *)
    log "Calling function vm_mon"
    vm_mon
    $ECHO "0" >"$STATE_PATH"/rebooted
    ;;
  esac
fi

################################################
# IF slave
# Find Master IP - Check Pool Master
# IF live - exit, else retry $XAPI_COUNT
# times with $XAPI_DELAY in between tries
# IF SLAVE_HA = ON, attempt to start appliances
# on slave after $XAPI_COUNT attempts
#################################################
if [[ $STATE == slave* ]]; then

  #####################################
  # Added 1.7.6 - slave self fencing
  # First - make sure this host has not
  # self fenced. if true - exit
  # else continue
  #####################################
  if [ -e "$STATE_PATH"/fenced_slave ]; then
    log "This host has self fenced - scheduling  host health check..."
    THIS_HOST_HAS_SELF_FENCED=true
  else
    THIS_HOST_HAS_SELF_FENCED=false
  fi

  #####################################
  # Get IP Address of Pool Master
  #####################################
  master_ip "$STATE"

  #####################################
  # Make sure the pool master is not a
  # slave - this is a rare condition
  # that must be captured
  #####################################
  log "Validating master is still a master"
  VALIDATE_MASTER_EXEC="${TIMEOUT} 1 ${HOST_IS_SLAVE} ${MASTER_IP}"
  log "[ $VALIDATE_MASTER_EXEC ]"
  VALIDATE_MASTER=$(${VALIDATE_MASTER_EXEC})
  RETVAL=$?
  if [ $RETVAL -eq 0 ]; then
    if [ "${VALIDATE_MASTER}" = "HOST_IS_SLAVE" ]; then
      log "MAJOR ERROR - pool master [ $MASTER_IP ] reports it is a slave"
      MY_HOST_UUID=$(cat "$STATE_PATH"/local_host_uuid)
      NEW_MASTER_UUID=$(head -n 1 "$STATE_PATH"/host_uuid_ip_list | awk -F ':' '{print $1}')
      for uuid in "${NEW_MASTER_UUID[@]}"; do
        if [ "$uuid" = "${MY_HOST_UUID}" ]; then
          log "Calling promote slave for UUID [ $uuid ]"
          promote_slave
        fi
      done
    fi
  fi

  #####################################
  # Check if this host is autoselect
  # for becoming master
  #####################################
  if [ -e "$STATE_PATH"/autopromote_uuid ]; then
    THIS_SLAVE_UUID=$($CAT "$STATE_PATH"/local_host_uuid)
    AUTOPROMOTE_UUID=$($CAT "$STATE_PATH"/autopromote_uuid)
    if [ "$THIS_SLAVE_UUID" = "$AUTOPROMOTE_UUID" ]; then
      log "This slave - $(hostname): $THIS_SLAVE_UUID selected as allowed to become master: setting ALLOW_PROMOTE_MASTER=1"
      ALLOW_PROMOTE_SLAVE=1
    else
      log "This slave- $(hostname): $THIS_SLAVE_UUID not permitted to become master"
    fi

  else
    log "Missing file - $STATE_PATH/autopromote_uuid - cannot validate autopromote_status"
    email "Missing file - $STATE_PATH/autopromote_uuid - cannot validate autopromote_status"
    THIS_SLAVE_UUID=
  fi

  ####################################
  # Check if Pool Master is responding
  ####################################
  if check_xapi "$MASTER_IP"; then

    #####################################
    # Version 2.1 - auto remove suspended
    # HA from slave if status = healthy
    #####################################
    if [ "$THIS_HOST_HAS_SELF_FENCED" = "true" ]; then
      log "Checking host health to clear suspended HA mode"
      THIS_SLAVE_HEALTH_STATUS=$($XE host-param-get uuid="$THIS_SLAVE_UUID" param-name=other-config param-key=XenCenter.CustomFields."$XC_FIELD_NAME")
      if [ "$THIS_SLAVE_HEALTH_STATUS" != "healthy" ]; then
        log "This host health status = [ $THIS_SLAVE_HEALTH_STATUS ] and host is in suspended HA mode. Exiting.."
        exit 0
      else
        log "This host health status = [ $THIS_SLAVE_HEALTH_STATUS ] - removing HA Suspension"
        rm -f "$STATE_PATH"/fenced_slave
      fi
    fi

    #####################################
    # Version 2.1 - validate VMs running
    # here. Make sure they are not
    # reported as running elsewhere
    #####################################
    validate_this_host_vm_states

    #######################################
    # Check if ha-lizard is enabled
    #######################################
    log "Pool Master is OK - calling function check_ha_enabled - updating local status"
    if check_ha_enabled; then
      $ECHO true >"$STATE_PATH"/ha_lizard_enabled
    else
      $ECHO false >"$STATE_PATH"/ha_lizard_enabled
    fi

    log "Checking state file for status if ha-lizard is enabled"
    if [ -e "$STATE_PATH/ha_lizard_enabled" ]; then
      log "Statefile $STATE_PATH/ha_lizard_enabled found: checking if ha-lizard is enabled"
      ha_lizard_STAT=$($CAT "$STATE_PATH"/ha_lizard_enabled)
      if [ "$ha_lizard_STAT" = "true" ]; then
        log "ha-lizard is enabled - continuing"
        ####################################
        # Added 1.7.8 - make sure XenServer
        # HA is not active before going
        # any further
        ####################################
        if ! check_xs_ha; then
          log "ERROR - Detected alternate HA configured for pool"
          exit 1
        fi
      else
        log "ha-lizard is disabled - exiting"
        ################################
        # Update state files before exit
        ################################
        log "Updating state information"
        write_pool_state
        exit 0
      fi
    fi

    ############################
    # Master is OK - XAPI is OK
    # safe to update state files
    ############################
    log "Calling Function write_pool_state - updating local state files"
    write_pool_state &

    if [ "$SLAVE_VM_STAT" -eq "1" ]; then
      log "Calling Function vm_mon - check if any VMs need to be started"
      vm_mon
    fi
  else
    if [ "$THIS_HOST_HAS_SELF_FENCED" = "true" ]; then
      log "Host has self fenced and cannot reach master - exiting"
    fi

    log "Pool Master NOT OK - Checking if ha-lizard is enabled in latest state file"
    #######################################
    # NO MASTER- Check local disk state
    # if ha-lizard is enabled
    #######################################
    log "Checking if ha-lizard is enabled"
    if [ -e "$STATE_PATH/ha_lizard_enabled" ]; then
      log "Statefile $STATE_PATH/ha_lizard_enabled found: checking if ha-lizard is enabled"
      ha_lizard_STAT=$($CAT "$STATE_PATH"/ha_lizard_enabled)
      if [ "$ha_lizard_STAT" = "true" ]; then
        log "ha-lizard is enabled - continuing"
      else
        log "ha-lizard is disabled - exiting"
        exit 0
      fi
    fi

    log "Pool Master Monitor = Failed"
    email "Server $HOSTNAME: Failed to contact pool master - manual intervention may be required"
    log "Retry Count set to $XAPI_COUNT. Retrying $XAPI_COUNT times in $XAPI_DELAY second intervals.."
    COUNT=0 #reset loop counter

    while [ $COUNT -lt "$XAPI_COUNT" ]; do
      log "Attempt $COUNT: Checking Pool Master Status"
      COUNT=$((COUNT + 1))
      sleep "$XAPI_DELAY"

      if check_xapi "$MASTER_IP"; then
        log "Pool Master Communication Restored"
        break
      else
        ####################################
        # IF max retries to reach master
        # IF PROMOTE_SLAVE is enabled
        # IF SLAVE_HA is enabled in config
        # try to start VMs on slave.
        ####################################
        if [ $COUNT = "$XAPI_COUNT" ]; then
          if [ -e "$STATE_PATH"/pool_num_hosts ]; then
            NUM_HOSTS=$($CAT "$STATE_PATH"/pool_num_hosts)
            log "Retrieving number of hosts in pool. Setting NUM_HOSTS = $NUM_HOSTS"
          else
            log "ERROR Retrieving number of hosts in pool. Setting NUM_HOSTS = UNKNOWN"
          fi

          log "Failed to reach Pool Master - Checking if this host promotes to Master.."

          if [[ $PROMOTE_SLAVE == "1" ]] && [[ $ALLOW_PROMOTE_SLAVE == "1" ]]; then
            MASTER_UUID=$($CAT "$STATE_PATH"/master_uuid)
            log "State file MASTER UUID = $MASTER_UUID"

            ###############################
            # Fence Master
            ###############################
            if [ "$FENCE_ENABLED" = "1" ]; then
              fence_host "$MASTER_UUID" stop
              RETVAL=$?
              log "Function fence_host returned status $RETVAL"
              case $RETVAL in
              0)
                log "Master: $MASTER_UUID successfully fenced, attempting to start any failed VMs"
                log "Promote Slave enabled for this host. Calling promote_slave - attempt to become pool master"
                promote_slave
                RETVAL=$?
                if [ $RETVAL -eq 0 ]; then
                  log "New Master ha_enabled check"
                  POOL_UUID=$(xe pool-list --minimal)
                  DB_HA_STATE=$(xe pool-param-get uuid="$POOL_UUID" param-name=other-config param-key=XenCenter.CustomFields."$XC_FIELD_NAME")
                  if [ "$DB_HA_STATE" = "false" ]; then
                    log "This host just became master - re-enabling HA"
                    xe pool-param-set uuid="$POOL_UUID" other-config:XenCenter.CustomFields."$XC_FIELD_NAME"=true
                    RETVAL=$?
                    if [ $RETVAL -eq 0 ]; then
                      log "HA returned to enabled state"
                    else
                      log "Error returning HA to enabled state"
                    fi
                  fi
                else
                  log "Failed to promote slave - Pool master must be manually recovered!"
                  email "Failed to promote slave - Pool master must be manually recovered!"
                  exit 1
                fi
                ;;
              1)
                log "Failed to fence Master: $MASTER_UUID. Checking whether FENCE_HA_ONFAIL is enabled"
                #######################################################################
                # Version 1.7.6 added self fence of slave if fencing fails
                # reboot host if failed fence attempt. In this case, any VMs that were
                # running will be in the off state after reboot. VMs will stay off unless
                # started by the master
                #########################################################################
                if [ "$NUM_HOSTS" -gt 1 ]; then
                  log "Marking this host as fenced, Rebooting this host now!"
                  log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!! SELF FENCING - REBOOT HERE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                  true >"$STATE_PATH"/fenced_slave
                  ########################################
                  # Sync before reboot to ensure buffered
                  # file system writes are written to disk
                  # before reboot - otherwise host may
                  # continuously reboot
                  ########################################
                  sync && $ECHO b >/proc/sysrq-trigger
                else
                  log "Pool number of hosts detected as: $NUM_HOSTS - no further action"
                fi

                #########################################################################################
                # Deprecate FENCE_HA_ONFAIL - it is dangerous to try to start VMs on failed fence attempt
                # Version 1.7.6
                ##########################################################################################
                #if [ $FENCE_HA_ONFAIL = "0" ]
                #then
                #	log "FENCE_HA_ONFAIL is disabled, failed to fence Master, exiting - Major Error!, no pool master"
                #	email "FENCE_HA_ONFAIL is disabled, failed to fence Master, exiting - Major Error!, no pool master"
                #	exit 1
                #elif [ $FENCE_HA_ONFAIL = "1" ]
                #then
                #	log "FENCE_HA_ONFAIL is enabled - attempted to recover any failed VMs"
                #fi
                ;;
              2)
                log "---------------------------- A L E R T -----------------------------"
                log "2 host noSAN pool validation has failed. This pool is a 2 node pool with hyperconverged"
                log "storage and the storage network between hosts is still connected. All fencing actions"
                log "will be blocked while the storage network remains connected."
                log "---------------------------- A L E R T -----------------------------"
                exit 101
                ;;
              esac
            fi

            ################################
            # Gather list of VMs on Master
            # being removed from pool
            ################################
            log "Retrieving list of VMs on failed master from local state file host.$MASTER_UUID.vmlist.uuid_array"
            # Use mapfile to read the output of the command directly into the array
            mapfile -t FAILED_VMLIST <"$STATE_PATH/host.$MASTER_UUID.vmlist.uuid_array"

            ################################
            # Clear possible hung power
            # states before attempting to
            # start VMs on new Master
            ###############################
            for c in "${FAILED_VMLIST[@]}"; do
              log "Resetting Power State for VM: $c"
              if $XE vm-reset-powerstate uuid="$c" --force; then
                log "Power State for uuid: $c set to: halted"
              else
                log "Error resetting power state for VM UUID: $c"
              fi
            done

            ##############################
            # Reset Attach State of  VDIs
            ##############################
            RESET_IFS=$IFS
            IFS=","
            for v in $($XE pbd-list host-uuid="$MASTER_UUID" --minimal); do
              log "Resetting VDI: $v on host: $MASTER_UUID"
              STORE=$($XE pbd-param-get uuid="$v" param-name=sr-uuid)
              if $RESET_VDI "$MASTER_UUID" "$STORE"; then
                log "Resetting VDI: $v Success!"
              else
                log "Resetting VDI: $v ERROR!"
              fi
            done
            IFS=$RESET_IFS

            if [ "$SLAVE_HA" = 1 ]; then
              log "Slave HA is ON, Master is unreachable  - Checking for VMs or appliances to start in this pool"
              sleep 5
              vm_mon
            else
              log "Slave HA is OFF, Master is unreachable  - Not Attempting Restore - Manual Intervention Needed"
            fi
          else
            log "PROMOTE_SLAVE = [$PROMOTE_SLAVE] and ALLOW_PROMOTE_SLAVE = [$ALLOW_PROMOTE_SLAVE] - Not Promoting this host - Manual Intervention Needed"
          fi
        fi
      fi
    done
  fi
fi
