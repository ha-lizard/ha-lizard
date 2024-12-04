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

log_user 0
log_file -a /etc/ha-lizard/fence/ILO/ilo_fence.out
set timeout 20 

set ILO_IP	[lindex $argv 0]
set USER_NAME	[lindex $argv 1]
set ILO_PASSWD	[lindex $argv 2]
set ILO_CMD	[lindex $argv 3]

spawn ssh -o "StrictHostKeyChecking no" $USER_NAME@$ILO_IP

expect "*assword:"
send "$ILO_PASSWD\r"

expect "Server Power:"
send "$ILO_CMD\r\n"

expect "*" 
send "exit\r"
interact
