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

# Wait for the main menu and navigate to "Power Management"
set timeout 5
expect {
    timeout { puts "Error: Timeout waiting for main menu"; exit 1 }
    eof { puts "Error: SSH connection failed"; exit 1 }
    "Permission denied" { puts "Error: Incorrect password"; exit 1 }
    "Enter selection or (0) to quit:" { send "2" }
}

# Wait for the Power Management menu and select the reset option
expect {
    timeout { puts "Error: Timeout waiting for Power Management menu"; exit 1 }
    eof { puts "Error: SSH connection failed"; exit 1 }
    "(2) Immediate Reset" { send "2" }
}

# Wait for the confirmation prompt to confirm the reset action
expect {
    timeout { puts "Error: Timeout waiting for reset confirmation"; exit 1 }
    eof { puts "Error: SSH connection failed"; exit 1 }
    "Do you really want to reset" { send "yes\r" }
}

# Wait for the "Press any key to continue" prompt and send a key to continue
expect {
    timeout { puts "Error: Timeout waiting for 'Press any key' prompt"; exit 1 }
    eof { puts "Error: SSH connection failed"; exit 1 }
    "Press any key to continue" { send " " }
}

# Wait for the Power Management menu and return to the main menu
expect {
    timeout { puts "Error: Timeout returning to Power Management menu"; exit 1 }
    eof { puts "Error: SSH connection failed"; exit 1 }
    "Enter selection or (0) to quit:" { send "0" }
}

# Wait for the main menu and exit
expect {
    timeout { puts "Error: Timeout returning to the main menu"; exit 1 }
    eof { puts "Error: SSH connection failed"; exit 1 }
    "Enter selection or (0) to quit:" { send "0" }
}

# If all steps succeed, indicate success
puts "Info: Server has been reset successfully."
exit 0
