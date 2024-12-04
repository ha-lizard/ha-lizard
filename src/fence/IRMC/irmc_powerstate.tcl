#!/usr/bin/expect

log_user 0
log_file -a /etc/ha-lizard/fence/IRMC/irmc_fence.out

set IP		[lindex $argv 0]
set USERNAME	[lindex $argv 1]
set PASSWORD	[lindex $argv 2]

spawn ssh -o "StrictHostKeyChecking no" $USERNAME@$IP


# wait for password request...
set timeout 10
expect  { 
    timeout 	{ puts "failed to get password prompts" ; exit 1 }
    eof		{ puts "SSH failure"			; exit 1 }
    "*assword:" { send "$PASSWORD\r" }
}

# wait for main menu...
set timeout 5
expect  { 
    timeout 	{ puts "failed to get main menu"        ; exit 1 }
    eof		{ puts "SSH failure"			; exit 1 }
    "Permission denied"  { puts "wrong password"	; exit 1 }
    "Power Status : On"  { puts "On"  }
    "Power Status : Off" { puts "Off" }
}

exit 0
