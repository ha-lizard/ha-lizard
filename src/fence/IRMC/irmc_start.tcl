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

# Wait for the Power Management menu and check if the server is powered on
expect {
    timeout { puts "Error: Timeout waiting for Power Management menu"; exit 1 }
    eof { puts "Error: SSH connection failed"; exit 1 }
    "Power Status : On" {
      puts "Info: Server is already powered on";
      exit 0
    }
    "(4) Power On" { send "4" }
}

# Wait for the confirmation prompt to confirm power-on action
expect {
    timeout { puts "Error: Timeout waiting for power-on confirmation"; exit 1 }
    eof { puts "Error: SSH connection failed"; exit 1 }
    "Do you really want to power" { send "yes\r" }
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
puts "Info: Server has been powered ON successfully."
exit 0
