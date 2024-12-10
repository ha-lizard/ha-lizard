#!/usr/bin/expect

# Log only to the specified file to capture session output
log_user 0
log_file -a /var/log/ha-lizard/irmc_fence.out

# Retrieve arguments: IP address, username, and password
set IP [lindex $argv 0]
set USERNAME [lindex $argv 1]
set PASSWORD [lindex $argv 2]

# Start SSH session with provided credentials
spawn ssh -o "StrictHostKeyChecking no" "$USERNAME@$IP"

# Wait for the password prompt and provide the password
set timeout 10
expect {
    timeout { puts "Error: Timeout waiting for password prompt"; exit 1 }
    eof { puts "Error: SSH connection failed"; exit 1 }
    "*assword:" { send "$PASSWORD\r" }
}

# Wait for the main menu and check the power status
set timeout 5
expect  {
    timeout 	{ puts "failed to get main menu"        ; exit 1 }
    eof		{ puts "SSH failure"			; exit 1 }
    "Permission denied"  { puts "wrong password"	; exit 1 }
    "Power Status : On"  { puts "On"  }
    "Power Status : Off" { puts "Off" }
}

# End the script after displaying the power status
exit 0
