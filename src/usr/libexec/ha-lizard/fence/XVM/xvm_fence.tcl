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
# HA-Lizard TCL XVM FENCING SCRIPT
# USAGE:
# ./xvm_fence <HOST IP Address> <User> <Password> <Command>
###################################################################

# Disable user interaction logs
log_user 0

# Set log file to append session output for review
log_file -a /etc/ha-lizard/fence/XVM/xvm_fence.out

# Set script timeout (in seconds)
set timeout 20

# Read command-line arguments
set XVM_IP    [lindex $argv 0]   # Host IP address
set USER_NAME [lindex $argv 1]   # Username
set XVM_PASSWD [lindex $argv 2]  # Password
set XVM_CMD   [lindex $argv 3]   # Command to execute

# Check if all required arguments are provided
if {[llength $argv] != 4} {
    puts "Error: Incorrect number of arguments. Usage: ./xvm_fence <IP> <User> <Password> <Command>"
    exit 1
}

# Spawn an SSH session
spawn ssh -o "StrictHostKeyChecking no" $USER_NAME@$XVM_IP

# Handle SSH connection and authentication
expect {
    "password: " {
        send "$XVM_PASSWD\r"
    }
    timeout {
        puts "Error: SSH connection to $XVM_IP timed out."
        exit 1
    }
    eof {
        puts "Error: Unable to establish SSH connection to $XVM_IP."
        exit 1
    }
}

# Handle SSH session prompt
expect {
    "*#" {
        # Send the command to execute on the remote host
        send "$XVM_CMD\r"
    }
    timeout {
        puts "Error: Did not receive shell prompt after authentication."
        exit 1
    }
    eof {
        puts "Error: Connection closed unexpectedly after login."
        exit 1
    }
}

# Wait for command execution and retrieve the result
expect {
    "*#" {
        # Exit the SSH session gracefully
        send "exit\r"
    }
    timeout {
        puts "Error: Command execution timed out."
        exit 1
    }
    eof {
        puts "Error: Connection closed unexpectedly during command execution."
        exit 1
    }
}

# Allow the script to terminate cleanly
# The log file will contain all session outputs
exit 0
