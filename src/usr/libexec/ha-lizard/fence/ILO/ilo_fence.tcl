#!/usr/bin/expect
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

###################################################################
# ha-lizard TCL ILO FENCING SCRIPT
# USAGE:
# ilo_fence <ILO IP Address> <ILO User> <ILO Password> <Command>
###################################################################

# Disable interactive output (don't display user passwords, etc.)
log_user 0

# Log all output to a file for diagnostics
log_file -a /var/log/ha-lizard/ilo_fence.out

# Set timeout for expect commands
set timeout 20

# Extract arguments from the command line
set ILO_IP    [lindex $argv 0]
set USER_NAME [lindex $argv 1]
set ILO_PASSWD [lindex $argv 2]
set ILO_CMD   [lindex $argv 3]

# Start an SSH connection to the ILO interface
spawn ssh -o "StrictHostKeyChecking no" $USER_NAME@$ILO_IP

# Expect the password prompt and send the password
expect "*assword:"
send "$ILO_PASSWD\r"

# Expect the "Server Power:" prompt and send the ILO command
expect "Server Power:"
send "$ILO_CMD\r\n"

# Wait for any prompt and then exit
expect "*"
send "exit\r"

# Allow interaction with the shell (if necessary for debugging)
interact
