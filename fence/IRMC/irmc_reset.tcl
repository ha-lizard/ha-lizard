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

# wait for main menu and select "Power Management"...
set timeout 5
expect  { 
    timeout 	{ puts "failed to get main menu"        ; exit 1 }
    eof		{ puts "SSH failure"			; exit 1 }
    "Permission denied" { puts "wrong password"         ; exit 1 }
    "Enter selection or (0) to quit:" { send "2" }
}

# wait for power management menu...
expect  { 
    timeout 	{ puts "failed to get PM menu" 		; exit 1 }
    eof		{ puts "SSH failure"			; exit 1 }
    "(2) Immediate Reset"      { send "2" }
}

# wait for confirm request..
expect  { 
    timeout 	{ puts "failed to get confirm request"  ; exit 1 }
    eof		{ puts "SSH failure"			; exit 1 }
    "Do you really want to power"  { send "yes\r"}
}

# wait for "press any key" request..
expect  { 
    timeout 	{ puts "failed to get press.. request"  ; exit 1 }
    eof		{ puts "SSH failure"			; exit 1 }
    "Press any key to continue"  { send " "}
}

# wait for Power Management menu and return to Manin menu...
expect  { 
    timeout 	{ puts "failed to get PM menu"  	; exit 1 }
    eof		{ puts "SSH failure"			; exit 1 }
    "Enter selection or (0) to quit:"  { send "0"}
}

# wait for main menu exit
expect  { 
    timeout 	{ puts "failed to get main menu"        ; exit 1 }
    eof		{ puts "SSH failure"			; exit 1 }
    "Enter selection or (0) to quit:" { send "0" }
}

puts "ok"
exit 0
