#!/bin/bash
#################################################################################################
#
# XenServer VM Backup Tool 
#
# Copyright 2016-2024 Salvatore Costantino
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

#######################################################
### CHANGE LOG
#######################################################
#
# VM Backup script for XenServer environments
# Utilizes commonly known method of backing up VMs:
# (1) Creates a snapshot* (briefly pauses running VM)
# (2) Converts snapshot to a template
# (3) Exports the VM to xva file
# (4) Deletes the snapshot
# * for halted VMs, snapshots are not required - script will simply export the VM
#
# Features:
# - backup running or halted VMs
# - backup pool database
# - uses convenient filters for selecting VMs:
#   - all
#   - running
#   - halted
#   - none (convenient for backing up only pool DB)
#   - UUID list of specific VMs
#   - omit list of VMs to exclude from any of the above filters
# - Can auto-mount a specified CIFS repository
# - Arguments can be passed in when calling on command line (or from a script)
# - Optionally use a config file for passing in arguments
# - Optionally send email summary report at job completion
#
# Version 1.0 2016
# - Initial Release
#
# Version 1.1 November 2016
# - Updated help content
# - Added backup summary on completion
# - Added pool database backup
# - Added email handling and email summary reports
# - added omit list
# - added ha-lizard detection and template HA state updating
#
# Version 1.2 October 2018
# - Update to hide CIFS password in logs
#
# Version 1.3 October 2020
# - Bugfix - failure to snapshot a VM now aborts subsequent
#   operations on errored VM
# - Improved file retention logic more explicitly matches file names
########################################################
### End CHANGE LOG
########################################################

EXEC_NAME=$(basename $0)
DATE_STAMP=$(date +%s)
LOG_CONTENT=""
SUMMARY_CONTENT="\r\nVM-UUID:RESULT:VM-NAME:INFO\r\n"
SUMMARY_DETAILS=""
ERRORS_COUNT=0
TIME_START_UNIX=$(date +%s)
TIME_START_DATE=$(date -d@${TIME_START_UNIX})
VERSION=1.3

INSTANCES=$(pgrep ${EXEC_NAME})
NUM_INSTANCES=$(echo "$INSTANCES" | wc -l)
if [ "${NUM_INSTANCES}" -gt 1 ]
then
	echo "Another instance is running"
	exit 1
fi


######################################
# Function for logging
######################################
function log () {
	if [ -p /dev/stdin ]
	then
		read LOG_LINE
	else
		LOG_LINE=$1
	fi

        logger -t $EXEC_NAME "$! $LOG_LINE"
	
	if [ "$STORE_LOG" = "true" ]
	then
		LOG_CONTENT+="$(date +"%D %T.%3N")   ${EXEC_NAME} $!  $LOG_LINE\r\n"
	fi

	if [ "$VERBOSE" = "true" ]
	then
		echo "$LOG_LINE"
	fi
}


#####################################
# Declare any params passed in
#####################################
for param in ${@}
do
	eval $param
done


#####################################
# Source external config if specified
#####################################
CONFIG_FILE=${config:-}
if [ -e "$CONFIG_FILE" ]
then
        log "Sourcing configuration file [ $CONFIG_FILE ]"
        source $CONFIG_FILE
fi


####################################
# Normalize args
####################################
CIFS_SERVER=${cifs_server:-}
CIFS_USER=${cifs_user:-}
CIFS_PASSWORD=${cifs_password:-}
MOUNT_POINT=${mount_point:-}
UNMOUNT=${unmount:-follow}
VM_SELECT=${select:-all}
OMIT_LIST=${omit:-}
MOUNT_TYPE=${mount_type:-local}
CONFIG_FILE=${config:-}
BACKUP_FILE_SUFFIX=xva
BACKUP_PATH=${backup_path:-}
NUM_COPIES_TO_KEEP=${retention:-"-1"}
STORE_LOG=${log:-true}
VERBOSE=${verbose:-false}
DUMP_DB=${dump_db:-true}
PRINT_SUMMARY="${print_summary:-true}"
PREV_MOUNT=""
EMAIL_ALERT=${email_alert:-false}
EMAIL_FROM=${email_from:-}
EMAIL_TO=${email_to:-}
EMAIL_SUBJECT=${email_subject:-"$EXEC_NAME Report"}
EMAIL_TIMESTAMP=$(date)
EMAIL_PROCESS=$EXEC_NAME
EMAIL_BODY=""
EMAIL_SERVER=${smtp_server:-127.0.0.1}
EMAIL_PORT=${smtp_port:-25}
EMAIL_USER=${smtp_user:-}
EMAIL_PASS=${smtp_pass:-}
DEBUG_SMTP=${debug_smtp:-false}
EMAIL_LOG_FILE=${email_log:-true}


#####################################
# Function insert_summary_row
#
# Arg1=VM UUID
# Arg2=Result (SUCCESS or ERROR)
# Arg3=VM name label
# Argi4=Addl. Details
#
#
######################################
function insert_summary_row () {
	if [ "$2" = "ERROR" ]
	then
		ERRORS_COUNT=$(($ERRORS_COUNT+1))
	fi

	if [ "$4" ]
	then
		SUMMARY_CONTENT+="$1:$2:$3:$4\n"
	else
		SUMMARY_CONTENT+="$1:$2:$3\n"
	fi
} #End function insert_summary_row

#########################################
# function send_email_alert
# optionally sends email alert message
# with summary of backup process results
#########################################
function send_email_alert () {

python - "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" <<END
import sys, socket, smtplib
from email.MIMEMultipart import MIMEMultipart
from email.MIMEText import MIMEText

###########################
# if network or DNS is down
# dont wait - exit 1
###########################
socket.setdefaulttimeout(2)

#############################
#Declare System Hostname
#############################
hostname = socket.gethostname()

#############################
# Declare passed in args
#############################
from_email = "$1"
to_email = "$2"
subject = "$3"
timestamp = "$4"
process_name = "$EXEC_NAME"
message_body = """$5"""
smtp_server = "$6"
smtp_port = "$7"
smtp_user = "$8"
smtp_pass = "$9"
debug_smtp = "$DEBUG_SMTP"

if debug_smtp == 'true':
	print "Sending email from: "+from_email
	print "Sending email to: "+to_email
	print "Email Alert Subject: "+subject
	print "Email Alert Timestamp: "+timestamp
	print "Email Alert Process: "+process_name
	print "Email Alert Message Hostname: "+hostname

###############################
# Create the message headers
###############################
msg = MIMEMultipart('alternative')
msg['Subject'] = subject
msg['From'] = from_email
msg['To'] = to_email

###############################
# Message body - Text
###############################
text = message_body

###############################
# Message body - HTML
###############################
message_body_html="<br />".join(message_body.split("\n"))
html = """\
<table height="100" cellspacing="1" cellpadding="1" border="1" width="800" style="">
    <tbody>
        <tr>
            <td width="160"><img height="111" width="150" src="http://www.halizard.com/images/ha_lizard_alert_logo.png" alt="" /></td>
            <td width="640"><span style="color: rgb(0, 102, 0);"><strong><span style="font-size: larger;"><span style="font-family: Arial;">HA-Lizard Alert Notification<br />
            <br />
            Process: %s <br />
            Host: %s <br />
            Time: %s </span></span></strong></span></td>
        </tr>
        <tr>
            <td width="600" colspan="2">
            <p><br />
            <span style="font-family: Arial;"><span style="font-size: smaller;"> %s <br />
            <br />
            </span></span></p>
            </td>
        </tr>
        <tr>
            <td bgcolor="#cccccc" width="800" colspan="2">
            <p style="text-align: left;"><strong><span style="font-size: smaller;"><span style="font-family: Arial;">website</span></span></strong><span style="font-size: smaller;"><span style="font-family: Arial;">: www.halizard.com&nbsp;&nbsp;&nbsp;&nbsp; <strong>forum</strong>: http://www.halizard.com/forum</span></span>&nbsp;&nbsp;&nbsp; <strong><span style="font-size: smaller;"><span style="font-family: Arial;">Sponsored by</span></span></strong><span style="font-size: smaller;"><span style="font-family: Arial;"> </span></span><a href="http://www.pulsesupply.com"><span style="font-size: smaller;"><span style="font-family: Arial;">Pulse Supply</span></span></a></p>
            </td>
        </tr>
    </tbody>
</table>
<p>&nbsp;</p>
""" % (process_name, hostname, timestamp, message_body_html)

#############################
# Construct the message
#############################
text_part = MIMEText(text, 'plain')
html_part = MIMEText(html, 'html')
msg.attach(text_part)
msg.attach(html_part)

###############################
# Send the message
###############################
if smtp_port == "587":
	message = smtplib.SMTP(smtp_server, smtp_port, hostname)
	message.starttls()
elif smtp_port == "465":
	message = smtplib.SMTP_SSL(smtp_server, smtp_port, hostname)
else:
	message = smtplib.SMTP(smtp_server, smtp_port, hostname)

if debug_smtp == 'true':
	message.set_debuglevel(9)
if len(smtp_user) > 1:
	message.login(smtp_user, smtp_pass)
message.sendmail(from_email, to_email, msg.as_string())
message.quit()
END
} #End function send_email_alert


PARAM_LIST="\
CIFS_SERVER \
CIFS_USER \
CIFS_PASSWORD \
MOUNT_POINT \
UNMOUNT \
VM_SELECT \
OMIT_LIST \
MOUNT_TYPE \
CONFIG_FILE \
BACKUP_FILE_SUFFIX \
BACKUP_PATH \
NUM_COPIES_TO_KEEP \
STORE_LOG \
VERBOSE \
DUMP_DB \
PRINT_SUMMARY \
PREV_MOUNT \
EMAIL_ALERT \
EMAIL_FROM \
EMAIL_TO \
EMAIL_SUBJECT \
EMAIL_TIMESTAMP \
EMAIL_PROCESS \
EMAIL_BODY \
EMAIL_SERVER \
EMAIL_PORT \
EMAIL_USER \
EMAIL_PASS \
DEBUG_SMTP \
EMAIL_LOG_FILE"

for param in ${PARAM_LIST[@]}
do
	if [ "$param" = "CIFS_PASSWORD" ]
	then
		log "$param = [ HIDDEN ]"
	else
        	log "$param = [ ${!param} ]"
	fi
done

function help () {
	clear
	echo "
-----------------------------------------------------------------------------------------
| VM Backup script for XenServer environments                                           |
| Utilizes commonly known method of backing up                                          |
| VMs:                                                                                  |
| (1) Creates a snapshot* (briefly pauses running VM)                                   |
| (2) Converts snapshot to a template                                                   |
| (3) Exports the VM to xva file                                                        |
| (4) Deletes the snapshot                                                              |
| * for halted VMs, snapshots are not required - script will simply export the VM       |
|                                                                                       |
| Features:                                                                             |
| - backup running or halted VMs                                                        |
| - backup pool database                                                                |
| - uses convenient filters for selecting VMs:                                          |
|   - all                                                                               |
|   - running                                                                           |
|   - halted                                                                            |
|   - none (convenient for backing up only pool DB)                                     |
|   - or UUID list of specific VMs                                                      |
| - Can auto-mount a specified CIFS share                                               |
| - Arguments can be passed in when calling on command line (or from a script)          |
| - Optionally use a config file for passing in arguments                               |
-----------------------------------------------------------------------------------------

Arguments are passed in as key=value pairs in any order. Supported arguments are:

select		<all, running, halted, none OR comma separated list of VM UUIDs>
		Usage: select=all, select=running, select=halted, select=none
		Usage: select=8265e0c0-7816-4c43-a138-3a159a470cc3,6e0ffb84-6bcc-41ce-8c5a-971d8d3dedd7
		Default=all
		Optional argument. Must be one of
		select=all <Default value if not specified. Back up all VMs in pool>
		select=running <back up only running VMs in pool>
		select=halted <back up only halted VMs in pool>
		select=none <for backing up pool database only>
		select-UUID1,UUID2,UUID3... <back up specified VM UUIDs in comma separated string>

omit		<list of comma separated VM UUIDs>
		Usage: omit="66d633d1-a59a-4f93-bed1-5c14066a22d1,2c140f3b-dbda-4594-8b9c-bdf13a71c93e"
		Optional argument. Omits listed VMs from the backup job. Can be used in conjunction with "select"
		to add an additional filter for selecting VMs.
		

dump_db		<true, false>
		Usage: dump_db=true, dump_db=false
		Optional argument. Select whether to backup the pool database
		Default=true

mount_type	<local,cifs>
		Usage: mount_type=local, mount_type=cifs
		Optional Argument. Specify the type of mount.
		Default mount_type=local when not specified
		mount_type=local 
		mount_type=cifs <script will mount a cifs share>

cifs_server	<//ipaddress/share_name>
		Usage: cifs_server='//192.168.1.11/share'
		Mandatory when mount_type=cifs
		Specify CIFS server address and path as: //IP_ADDRESS/share_name

cifs_user	<username>
		Usage: cifs_user=username
		Optional CIFS username

cifs_password	<password>
		Usage: cifs_password=password
		Optional CIFS password

mount_point	<path to local directory to mount>
		Usage: mount_point=/path/to/mount
		Mandatory local mount point when mount other than local is specified

unmount		<true,false,follow>
		Usage: unmount=true, umnount=false, unmount=follow
		Optional when an external mount point is specified.
		unmount=true <unmount at job completion>
		unmount=false <don't unmount when job is completed>
		unmount=follow <Default. If the mount was already mounted then don't unmount. Otherwise unmount at completion>


backup_path	<path to directory to store backup files>
		Usage: backup_path=/directory/location
		Mandatory argument. No trailing slash required. Target directory will be created if it does not exist already
		When mounting an external share, the local mount point must be passed in as the backup_path

retention	<integer>
		Usage: retention=10
		Optional argument. Specify the number of backup files to keep.
		When not specified, retention is disabled [ -1 ] and no backups will be purged
		Only purges exported VMs and pool database dumps. Log files are not purged.

verbose		<true,false>
		Usage: verbose=true, verbose=false
		Optional argument. Provides detailed backup operations progress to STDOUT.
		Useful when manually running. When not specified, defaults to verbose=false and will run quietly.

log		<true,false>
		Usage: log=true, log=false
		Optional argument. Stores log file in the backup location on each new backup job.
		Default log=true

print_summary	<true,false>
		Usage: print_summary=true, print_summary=false
		Optional argument. Prints concise error/success summary to stdout on completion.
		Default=true

config		<external configuration file>
		Usage: config=/path/to/config.conf
		Optional argument. Specify an external file to pass in arguments rather than passing arguments in when invoked.

email_alert	<true,false>
		Usage: email_alert=true, email_alert=false
		Optional argument. Sends an email alert with backup results summary on completion
		Required: email_from, email_to
		Additional required: smtp_server, smtp_port (when external SMTP server used)
		Additional required: smtp_user, smtp_pass (when SMTP server requires authentication)
		Default=false

email_from	<from email address>
		Usage: email_from=someone@somewhere.com
		Mandatory argument when email_alert=true

email_to	<to email address>
		Usage: email_to=someone@somewhere.com
		Mandatory argument when email_alert=true

email_log	<true,false>
		Usage: email_log=true, email_log=false
		Optional argument. When set to true, the log file contents are included in the body of the summary email alert
		Default=true

smtp_server	<SMTP server IP address or hostname>
		Usage: smtp_server=smtp.somewhere.com, smtp_server=[IP ADDRESS]
		Optional argument. Declares the SMTP server to be used for email alert
		Default=127.0.0.1

smtp_port	<SMTP server port number>
		Usage: smtp_port=587
		Optional argument. Declares the SMTP server port number
		Default=25

smtp_user	<username>
		Usage: smtp_user=username
		Optional argument. Declares the SMTP server authentication name when the server requires authentication

smtp_pass	<password>
		Usage: smtp_pass=password
		Optional argument. Declares the SMTP server authentication password when the server requires authentication

debug_smtp	<true,false>
		Usage: debug_smtp=true, debug_smtp-false
		Optional argument. Prints SMTP debugging information to stdout.
		Default=false

Example:	Backup ALL VMs to local path quietly
./vm_backup.sh backup_path=/my_directory dump_db=false

Example:	Backup ALL VMs and Pool Database to local path quietly
./vm_backup.sh backup_path=/my_directory

Example:	Backup only the pool database
./vm_backup.sh backup_path=/my_directory select=none

Example:	Backup all halted VMs to local path (local path could be an externally controlled mount like CIFS ISO SR)
./vm_backup.sh verbose=true backup_path=/var/run/sr-mount/e622e948-ae9f-9d6a-ebc1-bfee7eda31e7 select=halted 

Example: 	Backup all VMs and pool database to local path displaying progress on STDOUT
./vm_backup.sh verbose=true backup_path=/my_local_directory

Example: 	Backup 2 VMs to CIFS server and unmount when done
./vm_backup.sh verbose=true backup_path=/mnt/today select=aa4e337a-f22a-26f2-bf22-0be86a31e205,51ea84dc-a61e-f4ed-c126-27521e3a065a \
mount_type=cifs cifs_server="//192.168.1.18/test1" cifs_user=test1 cifs_password=test1 mount_point=/mnt/today unmount=true

Example:	Backup all running VMs to CIFS server and leave mounted when done
./vm_backup.sh verbose=true backup_path=/mnt/today select=running mount_type=cifs cifs_server="//192.168.1.18/test1" cifs_user=test1 \
cifs_password=test1 mount_point=/mnt unmount=false

" | less

	exit 0
} #End function help 

if [ ! $1 ]
then
	echo "$EXEC_NAME Version $VERSION"
	echo "Arguments:"
	echo "--help               help"
	echo "<select>             VM Selector"
	echo "<omit>               VM omit list"
	echo "<dump_db>            backup pool database"
	echo "<mount_type>         select mount type"
	echo "<cifs_server>        declare CIFS server"
	echo "<cifs_user>          declare CIFS username"
	echo "<cifs_password>      declare CIFS password"
	echo "<mount_point>        declare mount point"
	echo "<unmount>            unmount on copletion"
	echo "<backup_path>        backup directory"
	echo "<retention>          set retention copies"
	echo "<verbose>            display detailed progress"
	echo "<log>                store log file on completion"
	echo "<print_summary>      print consise summary on completion"
	echo "<config>             declare arguments in external file"
	echo "<email_alert>        enable sending of summary email on completion"
	echo "<email_from>         set the from email address"
	echo "<email_to>           set the to email address"
	echo "<email_log>          include log file in email alert message"
	echo "<smtp_server>        set the SMTP server for email alerts"
	echo "<smtp_port>          set the SMTP server port number"
	echo "<smtp_user>          set the SMTP account username"
	echo "<smtp_pass>          set the SMTP account password"
	echo "<debug_smtp>         print SMTP debug to stdout"
fi

if [ "$1" = "--help" ]
then
	help	
fi

#####################################
# Check for deps
#####################################
REQUIRED=(logger xe tr mount umount mountpoint)
for dep in ${REQUIRED[@]}
do
	which $dep 2>&1 | log
	RETVAL=$?
	if [ $RETVAL -eq 0 ]
	then
		log "[ $dep ] found ok.."
	else
		log "[ $dep ] missing - exiting.."
		exit 1
	fi
done

######################################
# Check if this is an HA-Lizard enviro
# restrict on incompatible modes
######################################
which ha-cfg &> /dev/null
RETVAL=$?
if [ $RETVAL -eq 0 ]
then
	eval $(ha-cfg get | grep XC_FIELD_NAME)
	eval $(ha-cfg get | grep OP_MODE)
	eval $(ha-cfg get | grep GLOBAL_VM_HA)
	log "XC_FIELD_NAME = [ $XC_FIELD_NAME ] OP_MODE = [ $OP_MODE ] GLOBAL_VM_HA = [ $GLOBAL_VM_HA ]"
	POOL_HAL_ENABLED=$(xe pool-param-get uuid=$(xe pool-list --minimal) param-name=other-config param-key=XenCenter.CustomFields.$XC_FIELD_NAME)
	if [ "${POOL_HAL_ENABLED}" = "true" ]
	then
		log "HA-Lizard High Availabiliy detected - checking for supported modes"
		if [ $OP_MODE -eq 1 -o $GLOBAL_VM_HA -eq 1 ]
		then
			echo "HA-Lizard is enabled and operting in mode [ $OP_MODE ] and global_vm_ha [ $GLOBAL_VM_HA ]"
			echo "Try disabling HA-Lizard before running this utility or change your settings to"
			echo "global_vm_ha=0 and op_mode=2"
			exit 1
		fi
	else
		log "HA-Lizard is disabled - continue"
 	fi
fi

######################################
# Generate list of VM UUIDs to Export
######################################
case $VM_SELECT in
	all)
		log "All VMs selected for backup"
		VMS_TO_BACKUP=$(xe vm-list is-control-domain=false is-a-snapshot=false --minimal | tr ',' '\n')
	;;

	running)
		log "Running VMs selected for backup"
		VMS_TO_BACKUP=$(xe vm-list is-control-domain=false is-a-snapshot=false power-state=running --minimal | tr ',' '\n')
	;;

	halted)
		log "Halted VMs selected for backup"
		VMS_TO_BACKUP=$(xe vm-list is-control-domain=false is-a-snapshot=false power-state=halted --minimal | tr ',' '\n')
	;;
	
	none)
		log "No VMs selected for backup"
		VMS_TO_BACKUP=''
	;;

	*)
		log "Backing up VM(s) [ $VM_SELECT ]"
		VM_SELECT=$(echo "$VM_SELECT" | tr ',' '\n')
		VMS_TO_BACKUP=()
		for vm_to_validate in ${VM_SELECT}
		do
			VALIDATE_UUID=$(xe vm-list uuid=$vm_to_validate --minimal)
			if [ "$vm_to_validate" = "$VALIDATE_UUID" ]
			then
				log "VM UUID [ $vm_to_validate ] Validated"
				VMS_TO_BACKUP+=($vm_to_validate)
			else
				log "Invalid VM UUID [ $vm_to_validate ]"
			fi
		done
	;; 
esac

#####################################
# Check the omit list if set
#####################################
VMS_TO_BACKUP_CLEAN=""
if [ -n $OMIT_LIST ]
then
	OMIT_LIST=$(echo "$OMIT_LIST" | tr ',' '\n') #replace commas with IFS friendly newline
	for check_vm in ${VMS_TO_BACKUP[@]}
	do
		MATCH=false
		for vm_to_omit in ${OMIT_LIST[@]}
		do
			if [ "$vm_to_omit" = "$check_vm" ]
			then
				log "Omitting [ $vm_to_omit ]"
				MATCH=true
			fi
		done
		if [ "$MATCH" = "false" ]
		then
			VMS_TO_BACKUP_CLEAN+="${check_vm} "
		fi
	done
else
	VMS_TO_BACKUP_CLEAN="$VMS_TO_BACKUP"
fi
	
#####################################
# Set some counters
#####################################
NUM_VMS_SELECTED=$(echo ${VMS_TO_BACKUP_CLEAN[@]} | wc -w)
NUM_VMS_PROCESSED=0

#####################################
# Log selected VMs to be backed up
#####################################
for i in ${VMS_TO_BACKUP_CLEAN[@]}
do
	log "VM UUID Selected [ $i ]"
done

####################################
# Make external mount if configured
####################################
if [ "$MOUNT_TYPE" = "cifs" ]
then
	log "Backup folder is a cifs mount"
	mountpoint -q ${MOUNT_POINT}
	RETVAL=$?
	if [ $RETVAL -eq 0 ]
	then
		log "Mountpoint [ ${MOUNT_POINT} ] already mounted"
		PREV_MOUNT=true
	else
		log "Mounting [ ${CIFS_SERVER} ] on [ ${MOUNT_POINT} ]"

		if [ -z ${CIFS_USER}  -a -z ${CIFS_PASSWORD} ]
		then
			log "mount exec [ mount -t cifs -o noperm ${CIFS_SERVER} ${MOUNT_POINT} ]"
			mount -t cifs -o noperm ${CIFS_SERVER} ${MOUNT_POINT}
			RETVAL=$?
		elif [ -n ${CIFS_USER} -a -z ${CIFS_PASSWORD} ]
		then
			log "mount exec [ mount -t cifs -o user=${CIFS_USER},noperm ${CIFS_SERVER} ${MOUNT_POINT} ]"
			mount -t cifs -o user=${CIFS_USER},noperm ${CIFS_SERVER} ${MOUNT_POINT}
			RETVAL=$?
		else
			log "mount exec [ mount -t cifs -o user=${CIFS_USER},password=${CIFS_PASSWORD},noperm ${CIFS_SERVER} ${MOUNT_POINT} ]"
			mount -t cifs -o user=${CIFS_USER},password=${CIFS_PASSWORD},noperm ${CIFS_SERVER} ${MOUNT_POINT}
			RETVAL=$?
		fi

		if [ $RETVAL -eq 0 ]
		then
			PREV_MOUNT=false
			log "[ ${CIFS_SERVER} ] mounted on [ ${MOUNT_POINT} ]"
		else
			log "Could not mount [ ${CIFS_SERVER} ]"
			exit 1
		fi
	fi
fi

###################################
# Any mounts should be in place now
# Validate the backup path
###################################
if [ -z ${BACKUP_PATH} ]
then
	log "backup_path must be specified"
	exit 1
fi

if [ ! -d ${BACKUP_PATH} ]
then
	log "Backup directory missing - attempting to create"
	mkdir -p ${BACKUP_PATH}
	RETVAL=$?
	if [ $RETVAL -eq 0 ]
	then
		log "Backup directory [ ${BACKUP_PATH} ] created"
	else
		log "Could not creare backup directory - aborting"
		exit 1
	fi
fi

#####################################
# Perform the pool DB backup
#####################################
if [ "$DUMP_DB" = "true" ]
then
	THIS_POOL_UUID=$(xe pool-list --minimal)
	THIS_POOL_NAME=$(xe pool-param-get uuid=$THIS_POOL_UUID param-name=name-label)
	BACKUP_BASE_FILENAME=$(echo "$THIS_POOL_NAME" | tr [:space:] _)
	BACKUP_FILENAME=${BACKUP_BASE_FILENAME}_${DATE_STAMP}.pooldb
	BACKUP_FILE="${BACKUP_PATH}/${BACKUP_FILENAME}"

	xe pool-dump-database file-name=${BACKUP_FILE}
	RETVAL=$?
	if [ $RETVAL -ne 0 ]
	then
		log "Error backing up pool database"
		insert_summary_row $THIS_POOL_UUID ERROR $THIS_POOL_NAME "[ Error backing up pool database ]"
	else
		log "Pool DB backed up to [ ${BACKUP_FILE} ]"
		insert_summary_row $THIS_POOL_UUID SUCCESS $THIS_POOL_NAME "[ Pool Database Dump ]"
	fi


	################################
	# Remove old backups per
	# retention policy
	################################
	log "Retention policy set for [ $NUM_COPIES_TO_KEEP ] backups"
	if [ "${NUM_COPIES_TO_KEEP}" -gt 0 ]
	then
		FILES_FOUND=$(ls ${BACKUP_PATH} | grep ${BACKUP_BASE_FILENAME} | grep pooldb | sort)
		NUM_FILES_FOUND=$(echo "${FILES_FOUND}" | wc -l)
		log "Found [ ${NUM_FILES_FOUND} ] files. Retention set to keep [ ${NUM_COPIES_TO_KEEP} ]"
		NUM_BACKUPS_TO_PURGE=$(( $NUM_FILES_FOUND - $NUM_COPIES_TO_KEEP ))
		if [ ${NUM_BACKUPS_TO_PURGE} -gt 0 ]
		then
			log "Purging [ ${NUM_BACKUPS_TO_PURGE} ] backups"
			COUNT=$NUM_BACKUPS_TO_PURGE
			for backup_file in ${FILES_FOUND[@]}
			do
				if [ $COUNT -eq 0 ]
				then
					log "Finished purging"
					break
				fi
				log "Purging [ ${BACKUP_PATH}/$backup_file ]"
				rm -f ${BACKUP_PATH}/$backup_file
				RETVAL=$?
				if [ $RETVAL -eq 0 ]
				then
					log "Successfully removed [ ${BACKUP_PATH}/$backup_file ]"
				else
					log "Error removing [ ${BACKUP_PATH}/$backup_file ]"
				fi
				COUNT=$(( $COUNT - 1 ))
			done
		else
			log "No backups to purge"
		fi
	fi
fi

#####################################
# Perform the VM backup
#####################################
for export_vm in ${VMS_TO_BACKUP_CLEAN[@]}
do
	NUM_VMS_PROCESSED=$(($NUM_VMS_PROCESSED+1))
	log "########################################################"
	log "#################### Begin Backup ######################"
	log "########################################################"
	log "Processing [ $NUM_VMS_PROCESSED ] of [ $NUM_VMS_SELECTED ] queued for backup"
	log "Processing VM [ $export_vm ]"
	###############################
	# Get the name
	###############################
	VM_NAME_LABEL=$(xe vm-param-get uuid=$export_vm param-name=name-label)
	RETVAL=$?
	if [ $RETVAL -eq 0 ]
	then
		log "VM Name [ $VM_NAME_LABEL ] found for VM UUID [ $export_vm ]"
	else
		log "Error retrieveing VM NAME for VM UUID [ $export_vm ] - skipping this VM"
		insert_summary_row $export_vm ERROR $VM_NAME_LABEL "[ Error retrieveing VM NAME ]"
		continue
	fi

	################################
	# Check VM power-state
	################################
	THIS_VM_POWER_STATE=$(xe vm-param-get uuid=$export_vm param-name=power-state)

	if [ "${THIS_VM_POWER_STATE}" = "halted" ]
	then
		log "VM [ $export_vm ] power-state = [ ${THIS_VM_POWER_STATE} ] - snapshot not required"
		################################
		# Export the VM
		################################
		BACKUP_BASE_FILENAME=$(echo "$VM_NAME_LABEL" | tr [:space:] _)
		BACKUP_FILENAME=${BACKUP_BASE_FILENAME}_${DATE_STAMP}.${BACKUP_FILE_SUFFIX}
		BACKUP_FILE="${BACKUP_PATH}/${BACKUP_FILENAME}"
		log "Exportng to [ ${BACKUP_FILE} ]"
		xe vm-export vm=$export_vm filename=${BACKUP_FILE} 2>&1 | log
		RETVAL=$?
		if [ $RETVAL -eq 0 ]
		then
			log "VM Successfully exported"
			insert_summary_row $export_vm SUCCESS $VM_NAME_LABEL
		else
			log "VM export failed"
			insert_summary_row $export_vm ERROR $VM_NAME_LABEL "[ VM export failed ]"
		fi

	else
		log "VM [ $export_vm ] power-state = [ ${THIS_VM_POWER_STATE} ] - creating snapshot"

		################################
		# Create the snapshot
		################################
		VM_SNAPSHOT=$(xe vm-snapshot uuid=$export_vm new-name-label="${VM_NAME_LABEL}-SS-${DATE_STAMP}")
		RETVAL=$?
		if [ $RETVAL -eq 0 ]
		then
			log "Successfully created snapshot UUID: [ ${VM_SNAPSHOT} ]"
			log "Snapshot name set: [ ${VM_NAME_LABEL}-SS-${DATE_STAMP} ]"
		else
			log "Error creating snapshot - skipping backup for VM [ $export_vm ]"
			insert_summary_row $export_vm ERROR $VM_NAME_LABEL "[ Error creating snapshot ]"
			continue
		fi

		#################################
		# If this pool has HA-Lizard HA
		# make sure HA=false before
		# converting snapshot to template
		#################################
		THIS_SNAPSHOT_HA_RESULT=$(xe snapshot-param-get uuid=${VM_SNAPSHOT} param-name=other-config param-key=XenCenter.CustomFields.$XC_FIELD_NAME)
		RETVAL=$?
		if [ $RETVAL -eq 0 ]
		then
			log "Checking HA status for snapshot"
			if [ "${THIS_SNAPSHOT_HA_RESULT}" = "true" ]
			then
				log "Setting HA=false"
				xe snapshot-param-set uuid=${VM_SNAPSHOT} other-config:XenCenter.CustomFields.$XC_FIELD_NAME=false
				RETVAL=$?
				if [ $RETVAL -eq 0 ]
				then
					log "Set snapshot HA status to [ false ]"
				else
					log "Error setting snapshot HA status to [ false ]"
				fi
			fi
		fi

		#################################
		# Make the snapshot a VM
		#################################
		xe template-param-set uuid=${VM_SNAPSHOT} is-a-template=false ha-always-run=false
		RETVAL=$?
		if [ $RETVAL -eq 0 ]
		then
			log "Snapshot [ ${VM_SNAPSHOT} ] template converted to VM"
		else
			log "Error converting snapshot [ ${VM_SNAPSHOT} ] - skipping this VM"
			insert_summary_row $export_vm ERROR $VM_NAME_LABEL "[ Error converting snapshot ]"
			################################
			# Error converting - cleanup SS
			################################
			xe vm-uninstall uuid=${VM_SNAPSHOT} force=true 2>&1 | log
			RETVAL=$?
			if [ $RETVAL -eq 0 ]
			then
				log "Removed snapshot [ $VM_SNAPSHOT ]"
			else
				log "Error removing snapshot [ $VM_UUID ]"
				continue
			fi
		fi
	
		################################
		# Export the VM
		################################
		BACKUP_BASE_FILENAME=$(echo "$VM_NAME_LABEL" | tr [:space:] _)
		BACKUP_FILENAME=${BACKUP_BASE_FILENAME}_${DATE_STAMP}.${BACKUP_FILE_SUFFIX}
		BACKUP_FILE="${BACKUP_PATH}/${BACKUP_FILENAME}"
		log "Exportng to [ ${BACKUP_FILE} ]"
		xe vm-export vm=${VM_SNAPSHOT} filename=${BACKUP_FILE} 2>&1 | log
		RETVAL=$?
		if [ $RETVAL -eq 0 ]
		then
			log "VM Successfully exported"
			insert_summary_row $export_vm SUCCESS $VM_NAME_LABEL
		else
			log "VM export failed"
			insert_summary_row $export_vm ERROR $VM_NAME_LABEL "[ VM export failed ]"
		fi

		################################
		# Cleanup - remove snapshot
		################################
		xe vm-uninstall uuid=${VM_SNAPSHOT} force=true 2>&1 | log
		RETVAL=$?
		if [ $RETVAL -eq 0 ]
		then
			log "Removed snapshot [ ${VM_SNAPSHOT} ]"
		else
			log "Error removing snapshot [ ${VM_SNAPSHOT} ]"
			insert_summary_row $export_vm ERROR $VM_NAME_LABEL "[ Error removing snapshot ]"
		fi

	fi

	################################
	# Remove old backups per
	# retention policy
	################################
	log "Retention policy set for [ $NUM_COPIES_TO_KEEP ] backups"
	if [ "${NUM_COPIES_TO_KEEP}" -gt 0 ]
	then
		FILES_FOUND=$(ls -rt ${BACKUP_PATH} | grep -E "^${BACKUP_BASE_FILENAME}_{1,2}[0-9]+\.${BACKUP_FILE_SUFFIX}$")
		NUM_FILES_FOUND=$(echo "${FILES_FOUND}" | wc -l)
		log "Found [ ${NUM_FILES_FOUND} ] files. Retention set to keep [ ${NUM_COPIES_TO_KEEP} ]"
		NUM_BACKUPS_TO_PURGE=$(( $NUM_FILES_FOUND - $NUM_COPIES_TO_KEEP ))
		if [ ${NUM_BACKUPS_TO_PURGE} -gt 0 ]
		then
			log "Purging [ ${NUM_BACKUPS_TO_PURGE} ] backups"
			COUNT=$NUM_BACKUPS_TO_PURGE
			for backup_file in ${FILES_FOUND[@]}
			do
				if [ $COUNT -eq 0 ]
				then
					log "Finished purging"
					break
				fi
				log "Purging [ ${BACKUP_PATH}/$backup_file ]"
				rm -f ${BACKUP_PATH}/$backup_file
				RETVAL=$?
				if [ $RETVAL -eq 0 ]
				then
					log "Successfully removed [ ${BACKUP_PATH}/$backup_file ]"
				else
					log "Error removing [ ${BACKUP_PATH}/$backup_file ]"
				fi
				COUNT=$(( $COUNT - 1 ))
			done
		else
			log "No backups to purge"
		fi
	fi
done

######################################
# Calculate script run time
######################################
TIME_END_UNIX=$(date +%s)
TIME_END_DATE=$(date -d @${TIME_END_UNIX})
TOTAL_TIME_SECONDS=$(( $TIME_END_UNIX - $TIME_START_UNIX ))
TOTAL_DURATION=$(date -d@${TOTAL_TIME_SECONDS} -u +%H:%M:%S)

log "Time Started: [ $TIME_START_DATE ]"
log "Time Ended: [ $TIME_END_DATE ]"
log "Total execution time: [ $TOTAL_DURATION ]"


	SUMMARY_DETAILS+="\r\nSummary\r\n"
	SUMMARY_DETAILS+="--------------------------------------------------------------------------------------------\n"
	SUMMARY_DETAILS+="Time Start: ${TIME_START_DATE}\r\n"
	SUMMARY_DETAILS+="Time End  : ${TIME_END_DATE}\r\n"
	SUMMARY_DETAILS+="Total Time: ${TOTAL_DURATION}\r\n"
	SUMMARY_DETAILS+="Errors encountered = [ $ERRORS_COUNT ]\r\n"
	SUMMARY_DETAILS+="VMs scheduled for backup = [ $NUM_VMS_SELECTED ]\r\n"
	SUMMARY_DETAILS+="${SUMMARY_CONTENT}"

if [ "$PRINT_SUMMARY" = "true" ]
then
	echo -e "${SUMMARY_DETAILS}"
	
fi

if [ "$STORE_LOG" = "true" ]
then
	echo -e "${LOG_CONTENT}" >> $BACKUP_PATH/${EXEC_NAME}.${DATE_STAMP}.log
fi

if [ "$EMAIL_ALERT" = "true" ]
then
	EMAIL_BODY+=$(echo -e ${SUMMARY_DETAILS})
	EMAIL_BODY+="\r\n\r\nLog\r\n"
	EMAIL_BODY+="--------------------------------------------------------------------------------------------\n"
	EMAIL_BODY+="${LOG_CONTENT}"

	log "Sending email alert to [ $EMAIL_TO ]"
	send_email_alert \
        "$EMAIL_FROM" \
        "$EMAIL_TO" \
        "$EMAIL_SUBJECT" \
        "$EMAIL_TIMESTAMP" \
        "$EMAIL_BODY" \
        "$EMAIL_SERVER" \
        "$EMAIL_PORT" \
        "$EMAIL_USER" \
        "$EMAIL_PASS"
fi

####################################
# Check if unmounting on completion
# is set or required
####################################
log "unmount set to [ ${UNMOUNT} ]"
if [ -z ${PREV_MOUNT} ]
then
	exit 0
elif [ "${UNMOUNT}" = "false" ]
then
	exit 0
elif [ "${UNMOUNT}" = "follow" ]
then
	if [ "${PREV_MOUNT}" = "false" ]
	then
		umount ${MOUNT_POINT} 2>&1 | log
		RETVAL=$?
	else
		exit 0
	fi
elif [ "${UNMOUNT}" = "true" ]
then
	umount ${MOUNT_POINT} 2>&1 | log
	RETVAL=$?
fi

if [ $RETVAL -eq 0 ]
then
	log "Unmounted [ ${MOUNT_POINT} ]"
else
	log "Error unmounting [ ${MOUNT_POINT} ]"
fi

log "Finished"
#########
## END ##
#########
