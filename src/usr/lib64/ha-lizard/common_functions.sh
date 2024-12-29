#!/bin/bash
#
# common_functions.sh
#
# This file contains shared Bash functions used by both the ha-cfg and iscsi-cfg
# scripts. It includes utility functions that are common to both systems to
# avoid code duplication and facilitate maintainability.
#
# Author: Victor Hugo dos Santos
# Date: 2024-12-17
# License: GPL v3
#
# Description:
# This script provides common functions such as utility helpers for logging,
# error handling, file manipulation, etc. It is intended to be sourced in
# other configuration scripts, allowing the reuse of code across different
# components of the setup.
#
# Usage:
# Source this file in other scripts using:
#   source /path/to/common_functions.sh
#
# Notes:
# - All functions in this file should be POSIX compliant.
# - Functions should have proper error handling and logging where necessary.
# - Each function should include a description of its purpose.
# - Functions should include examples of input and expected output.
# - Include details about edge cases and error handling where relevant.
# - Ensure functions are modular and reusable across different scripts.
#
# Example function declaration:
# function example_function() {
#     # Function description: Briefly explain what the function does.
#     # Input: Describe the expected input parameters (type, example values).
#     # Output: Describe the expected output or return value.
#     # Edge cases: List any edge cases considered or error handling done.
#     # Example:
#     #   Input: file_name="test.txt"
#     #   Output: Returns 0 if file exists, 1 otherwise.
# }

###################################
# Environment and default values
###################################
# shellcheck disable=SC2034
declare -r LVM_CONF='/etc/lvm/lvm.conf /etc/lvm/master/lvm.conf'
declare -r DRBD_CONF_FILE='/etc/drbd.d/iscsi-cfg.res'
declare -r IPTABLES_RULES_FILE='/etc/sysconfig/iptables'

declare BACKUP_SUFFIX
BACKUP_SUFFIX="_halizard_bkp_$(date +"%Y%m%d_%H%M%S")"

# Define global read-only variables for key and SSH directory paths
declare -r SSH_AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
declare -r SSH_DIR="$HOME/.ssh"
declare -r SSH_KEY_COMMENT="HA-Lizard_SSH_keys"
declare -r SSH_KEY_NAME="ha-lizard"
declare -r SSH_KEY_TYPE="ed25519"
declare -r SSH_KNOW_HOSTS="$SSH_DIR/known_hosts"
declare -r SSH_PRIVATE_KEY="$SSH_DIR/$SSH_KEY_NAME"
declare -r SSH_PUBLIC_KEY="$SSH_PRIVATE_KEY.pub"
# Define global read-only SSH options (private key and timeout)
declare -r -a SSH_OPTIONS=(-i "$SSH_PRIVATE_KEY" -o ConnectTimeout=5)
# NOTE: recent versions of ssh has the option "StrictHostKeyChecking=accept-new" that we could use to replace the logic of the known_hosts file.

##############################################
# Function: get_pool_uuid
#
# Description:
#   Retrieves the UUID of the pool using the following fallback sequence:
#   1. XAPI (via $XE pool-list --minimal)
#   2. A local file (${STATE_PATH}/pool_uuid)
#
#   If neither source is successful, the function logs an error and exits.
#
# Usage:
#   POOL_UUID=$(get_pool_uuid)
#
# Globals:
#   POOL_UUID - Global variable to store the pool UUID
#   STATE_PATH - Path to the directory containing the pool_uuid file
#
# Returns:
#   - Outputs the pool UUID (echo)
#   - Returns 0 on success, exits with error code 1 on failure
#
# Dependencies:
#   - $XE (CLI for XAPI, assumed to be available in the environment)
#   - log (logging function, assumed to be defined elsewhere)
#   - ${STATE_PATH}/pool_uuid (optional file containing the pool UUID)
##############################################
function get_pool_uuid() {
  # Check if the global variable POOL_UUID is already set
  if [ -n "$POOL_UUID" ]; then
    echo "$POOL_UUID"
    return 0
  fi

  # Attempt to retrieve the pool UUID using XAPI
  local uuid
  uuid=$(timeout "${XE_TIMEOUT:-10s}" xe pool-list --minimal 2>/dev/null)

  if [ -n "$uuid" ]; then
    POOL_UUID=$uuid
    log "Pool UUID successfully retrieved from XAPI: $POOL_UUID"
    echo "$POOL_UUID"
    return 0
  fi

  # Fallback: Attempt to read the UUID from the local state file
  local state_file="${STATE_PATH}/pool_uuid"
  if [ -f "$state_file" ]; then
    uuid=$(<"$state_file")
    if [ -n "$uuid" ]; then
      POOL_UUID=$uuid
      log "Pool UUID retrieved from state file: $POOL_UUID"
      echo "$POOL_UUID"
      return 0
    else
      log "Error: State file $state_file exists but is empty."
    fi
  else
    log "State file $state_file does not exist."
  fi

  # If all methods fail, log an error and exit with status 1
  log "Error: Could not retrieve pool UUID from XAPI or state file."
  echo "Error: Could not retrieve pool UUID." >&2
  exit 1
}

##############################################
# Retrieve and store the pool UUID
# This ensures that POOL_UUID GLOBAL variable is set at the start of the script.
##############################################
POOL_UUID=$(get_pool_uuid)

# backup_file: Backup a file while preserving its attributes and ownership.
#
# Input: file_path - the path to the file to be backed up.
#
# Output: 0 if the file was successfully backed up, 1 if the file does not exist
#         or 2 if the backup operation failed.
#
# Edge cases:
#   - If the file does not exist, the function will return 1.
#   - If the file cannot be copied, the function will return 2.
#
# Example:
#   Input: file_path="/etc/ha-lizard.conf"
#   Output: Returns 0 if the file is successfully backed up, 1 or 2 otherwise.
backup_file() {
  # Get the file path from the function argument
  local file_path="$1"

  # Ensure the file exists
  if [[ ! -f $file_path ]]; then
    echo "Error: File '$file_path' does not exist."
    return 1
  fi

  # Extract the directory and file name
  local dir_path
  local file_name
  dir_path=$(dirname "$file_path")
  file_name=$(basename "$file_path")

  # Generate the backup file name with the current backup suffix
  local backup_file_path
  backup_file_path="${dir_path}/${file_name}${BACKUP_SUFFIX}"

  # Copy the file to the backup file while preserving attributes and ownership
  if cp --preserve=all "$file_path" "$backup_file_path"; then
    # Check if the copy operation was successful
    echo "Backup created: $backup_file_path"
  else
    echo "Error: Failed to create backup."
    return 2
  fi
}

# check_host_reachable: Checks if a host (IP address or hostname) is reachable via ping.
#
# Input:
#   - host_to_check: The IP address or hostname of the host to check.
#
# Output:
#   - Returns 0 if the host is reachable.
#   - Returns 1 if the host is unreachable and the user chooses to exit.
#   - Returns 2 if the host is unreachable and the user chooses to continue.
#
# Edge cases:
#   - If the host is unreachable, the user is prompted to decide whether to exit or continue.
#   - If the user chooses "no" or anything other than "yes", the function exits the script with status 1.
#   - If the user chooses "yes", the function will return 2 to indicate continuation despite the unreachable host.
# TODO: Merge check_ip_health here
check_host_reachable() {
  # Host to check is passed as the first argument
  local host_to_check=$1

  # Output message indicating that a ping test will be attempted
  echo "Pinging host $host_to_check..."

  # Try to ping the host once, suppressing output to determine if it's reachable
  if ! ping -c 1 "$host_to_check" >/dev/null 2>&1; then
    # If the ping command fails, output that the host is not reachable
    echo "The host $host_to_check is not reachable."

    # Prompt the user to decide whether to continue with the installation or exit
    echo "Would you like to continue anyway? (yes/no)"
    read -r user_choice

    # If the user answers anything other than "yes", exit with error code 1
    if [ "$user_choice" != "yes" ]; then
      echo "Exiting... Please check the host address and try again."
      exit 1 # Exit the script with status 1 (failure)
    else
      # If the user chooses to continue despite the unreachable host
      echo "Continuing despite the unreachable host."
      return 2 # Return 2 to indicate continuation despite the issue
    fi
  else
    # If the ping command succeeds, output that the host is reachable
    echo "Host $host_to_check is reachable. Continuing."
    return 0 # Return 0 to indicate the host is reachable and installation can continue
  fi
}

#######################################
# Description:
#   Validates whether a given string is a valid IPv4 address.
# Arguments:
#   - ip: A string representing an IPv4 address.
# Returns:
#   - 0 (true) if the address is valid
#   - 1 (false) if the address is invalid
# Example:
#   is_valid_ipv4 "192.168.1.1"  # returns 0
#   is_valid_ipv4 "999.999.999.999"  # returns 1
#   is_valid_ipv4 "abc.def.ghi.jkl"  # returns 1
#######################################
is_valid_ipv4() {
  local ip=$1
  local octet

  # Check if the input matches the IPv4 format: n.n.n.n, where n is 0-255
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then

    # Split the IP into its four octets
    IFS='.' read -r -a octets <<<"$ip"

    # Validate that there are exactly 4 octets
    if [[ ${#octets[@]} -ne 4 ]]; then
      return 1
    fi

    # Check each octet to ensure it is within the range of 0 to 255
    for octet in "${octets[@]}"; do
      if ((octet < 0 || octet > 255)); then
        return 1
      fi
    done

    # If all checks pass, the IP is valid
    return 0
  fi

  # Return 1 if the IP format is incorrect
  return 1
}

#######################################
# Description:
#   Print a box around the given input text with centering and paging.
#   The box is centered horizontally and vertically in the terminal.
#   If the text is too long, it is split into multiple pages with a
#   prompt to continue at the end of each page.
#
# Input:
#   $*: The input text to be printed in the box.
#
# Output:
#   Prints the input text in a centered box with paging.
#
# Edge cases:
#   - If the input text is too long, it is split into multiple pages.
#   - If the terminal is not a TTY, the box is not printed.
#######################################
make_box() {
  local input="$*"     # Capture input text as a single string
  local term_width=80  # Default terminal width
  local term_height=24 # Default terminal height

  # Detect terminal dimensions if running on a terminal
  if [ -t 1 ]; then
    term_width=$(tput cols)   # Get terminal width
    term_height=$(tput lines) # Get terminal height
  fi

  # Calculate available width for text (subtracting padding and borders)
  local available_width=$((term_width - 4))

  # Function to strip color escape sequences for length calculations
  strip_colors() {
    echo "$1" | sed -r 's/\x1B\[[0-9;]*m//g'
  }

  # Split input into individual lines
  IFS=$'\n' # Handle multi-line input correctly
  local lines=()
  while IFS= read -r line; do
    # Truncate lines (ignoring color codes) if they are too long
    local stripped_line
    stripped_line=$(strip_colors "$line")
    if [ ${#stripped_line} -gt $available_width ]; then
      stripped_line="${stripped_line:0:available_width}"
      # Retain color codes for display but truncate visible text
      line="${line:0:${#stripped_line}}"
    fi
    lines+=("$line")
  done <<<"$input"

  # Calculate the longest line length (ignoring color codes)
  local longest_line=0
  for line in "${lines[@]}"; do
    local stripped_line=
    stripped_line=$(strip_colors "$line")
    [ ${#stripped_line} -gt "$longest_line" ] && longest_line=${#stripped_line}
  done

  # Calculate box width and height
  local box_width=$((longest_line + 4))  # Box width: longest line + padding
  local box_height=$((${#lines[@]} + 2)) # Box height: lines + top/bottom borders

  # Calculate centering offsets
  local offset_x=$(((term_width - box_width) / 2))

  # Function to print a single page of the box
  function print_page() {
    local start_line=$1
    local end_line=$2

    # Clear the screen before printing each page
    clear

    # Print blank lines to center vertically
    local offset_y=$(((term_height - (end_line - start_line + 3)) / 2))
    for _ in $(seq 1 $offset_y); do echo; done

    # Print the top border
    printf "%${offset_x}s+%s+\n" "" "$(printf -- '-%.0s' $(seq 1 $((box_width - 2))))"

    # Print the lines in the box with padding and side borders
    for ((i = start_line; i < end_line; i++)); do
      local stripped_line
      stripped_line=$(strip_colors "${lines[i]}")
      local padding=$((longest_line - ${#stripped_line}))
      printf "%${offset_x}s| %s%*s |\n" "" "${lines[i]}" "$padding" ""
    done

    # Print the bottom border
    printf "%${offset_x}s+%s+\n" "" "$(printf -- '-%.0s' $(seq 1 $((box_width - 2))))"
  }

  # Split the lines into pages and display one at a time
  local page_size=$((term_height - 3))                                # Subtract 3 for top/bottom borders
  local total_pages=$(((box_height - 2 + page_size - 1) / page_size)) # Calculate total number of pages

  local current_page=0
  while [ $current_page -lt $total_pages ]; do
    local start_line=$((current_page * page_size))
    local end_line=$((start_line + page_size))
    [ $end_line -gt ${#lines[@]} ] && end_line=${#lines[@]}

    # Print the current page
    print_page "$start_line" "$end_line"

    # Wait for user input to show the next page
    if [ $current_page -lt $((total_pages - 1)) ]; then
      echo -n "Press Enter to continue..."
      read -r # Wait for user input
    fi

    # Move to the next page
    current_page=$((current_page + 1))
  done
}

# Description:
#   Sets the terminal text color based on the specified color name.
#
# Parameters:
#   $1: The name of the color to set. Valid options are:
#       - green: Sets the text color to green.
#       - red: Sets the text color to red.
#       - yellow: Sets the text color to yellow.
#       - normal: Resets the text color to the default.
#
# Edge cases:
#   - If an invalid color name is provided, an error message is printed.
set_color() {
  # Check if a color was specified

  # Change the terminal text color based on the input
  case $1 in
  green)
    echo -e -n "\E[32m" # Set text color to green
    ;;
  red)
    echo -e -n "\E[31m" # Set text color to red
    ;;
  yellow)
    echo -e -n "\E[33m" # Set text color to yellow
    ;;
  normal)
    echo -e -n '\E[0m' # Reset text color to default
    ;;
  *)
    echo "Invalid color" # Handle invalid color input
    ;;
  esac
}

# Description:
#   Performs actions (start, stop, restart, status) on specified services on a remote server
#   using SSH and systemctl.
#
# Parameters:
#   $1: The IP address or hostname of the remote server.
#   $2: The systemctl action to perform (start, stop, restart, status).
#   $3+: An array of services to be managed.
#
# Returns:
#   0 on success, 1 on failure.
service_execute_remote() {
  local server_ip_remote="$1"
  local action="$2"
  shift 2
  local services=("$@")
  local retval=0

  # Validate input parameters
  if [[ -z $server_ip_remote || -z $action || ${#services[@]} -eq 0 ]]; then
    echo "Usage: service_execute_remote <server_ip_remote> <action> <service1> <service2> ..."
    return 1
  fi

  # Validate the action parameter
  if ! [[ $action =~ ^(start|stop|restart|status)$ ]]; then
    echo "Error: Invalid action. Valid actions are start, stop, restart, status."
    return 1
  fi

  echo "Performing '$action' on services for remote server: $server_ip_remote"

  # Iterate over each service and perform the action
  for service in "${services[@]}"; do
    echo -n "$action $service: "

    # Perform the action using ssh and capture the status
    ssh -o BatchMode=yes "$server_ip_remote" "systemctl $action $service" >/dev/null 2>&1
    # Determine expected service state based on the action
    local expected_state
    case "$action" in
    start | restart | status)
      expected_state="active"
      ;;
    stop)
      expected_state="inactive"
      ;;
    esac

    # Check the service's current state
    local service_state
    service_state=$(ssh -o BatchMode=yes "$server_ip_remote" "systemctl is-active $service" 2>/dev/null)

    # Output status based on the command result
    if [[ $service_state == "$expected_state" ]]; then
      echo "Service Remote Execution action '$action' for $server_ip_remote $(set_color "green")[ OK ]$(set_color "normal")"
    else
      echo "Service Remote Execution action '$action' for $server_ip_remote $(set_color "red")[ FAIL/ERROR ]$(set_color "normal")"
      retval=1
    fi
  done

  # Return the overall status
  if [[ $retval -eq 0 ]]; then
    echo "All services were SUCCESSFULLY '$action' on the remote server: $server_ip_remote"
    return 0
  else
    echo "One or more services FAILED to '$action' on the remote server: $server_ip_remote"
    return 1
  fi

}

############################################
#
# SSH Key management functions
#
############################################

# Function: ssh_keys_create
# Purpose: Create or recreate SSH keys for HA-Lizard and configure authorized_keys
# Parameters:
#   None
# Returns:
#   0 on success, 1 on failure
ssh_keys_create() {

  # Ensure .ssh directory exists
  if [[ ! -d $SSH_DIR ]]; then
    # Create the .ssh directory if it does not exist
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
  fi

  # Check if SSH keys already exist
  if [[ -f $SSH_PRIVATE_KEY && -f $SSH_PUBLIC_KEY ]]; then
    # Check if the user wants to use existing SSH keys
    read -rp "Keys already exist. Use existing SSH keys? (y/n): " response
    case "$response" in
    [Yy]*)
      # Use existing SSH keys
      echo "Using existing SSH keys."
      return 0
      ;;
    [Nn]*)
      # Recreate the SSH keys
      echo "Recreating SSH keys."
      rm -f "$SSH_PRIVATE_KEY" "$SSH_PUBLIC_KEY"
      ;;
    *)
      # Invalid response
      echo "Invalid response. Exiting."
      return 1
      ;;
    esac
  fi

  # Generate new key pair
  if ! ssh-keygen -t "$SSH_KEY_TYPE" -C "$SSH_KEY_COMMENT" -f "$SSH_PRIVATE_KEY" -N ""; then
    # Error generating SSH keys
    echo "Error generating SSH keys."
    return 1
  fi

  # Add public key to authorized_keys
  if [[ -f $SSH_AUTHORIZED_KEYS ]]; then
    # Check if the public key is already in authorized_keys; if not, append it.
    grep -qFf "$SSH_PUBLIC_KEY" "$SSH_AUTHORIZED_KEYS" || cat "$SSH_PUBLIC_KEY" >>"$SSH_AUTHORIZED_KEYS"
  else
    # Create authorized_keys and add the public key
    cat "$SSH_PUBLIC_KEY" >>"$SSH_AUTHORIZED_KEYS"
    chmod 600 "$SSH_AUTHORIZED_KEYS"
  fi

  # Success
  echo "SSH Keys created and added to authorized_keys."
}

# Function: ssh_keys_sync
# Purpose: Synchronize SSH keys and configuration with a remote server
# Parameters:
#   server_ip_local - The hostname or IP address of the master server
#   server_ip_remote - The hostname or IP address of the slave server
# Returns:
#   0 on success, 1 on failure

ssh_keys_sync() {
  local server_ip_local="$1"
  local server_ip_remote="$2"

  # Check if both master and slave server IPs are provided
  if [[ -z $server_ip_local || -z $server_ip_remote ]]; then
    echo "Usage: ssh_keys_sync <server_ip_local> <server_ip_remote>"
    return 1
  fi

  # Check if SSH keys exist
  if [[ ! -f $SSH_PRIVATE_KEY || ! -f $SSH_PUBLIC_KEY ]]; then
    echo "Keys do not exist. Run ssh_keys_create first."
    return 1
  fi

  # Generate known_hosts for the master server
  if ! ssh-keyscan -H "$server_ip_local" >>"$SSH_KNOW_HOSTS"; then
    echo "Error generating known_hosts for $server_ip_local."
    return 1
  fi

  # Append the slave server to known_hosts
  if ! ssh-keyscan -H "$server_ip_remote" >>"$SSH_KNOW_HOSTS"; then
    echo "Error generating known_hosts for $server_ip_remote."
    return 1
  fi

  # Synchronize files to the slave server using the specified private key
  if ! rsync -avz --backup --suffix="${BACKUP_SUFFIX}" -e "ssh ${SSH_OPTIONS[*]}" "$SSH_PRIVATE_KEY" "$SSH_PUBLIC_KEY" "$SSH_AUTHORIZED_KEYS" "$SSH_KNOW_HOSTS" "$server_ip_remote:$SSH_DIR/"; then
    echo "Error synchronizing SSH keys and configuration with $server_ip_remote."
    return 1
  fi

  # Successful synchronization
  echo "Keys and configuration synchronized with $server_ip_remote."
}

# Function: ssh_keys_remove
# Purpose: Remove all HA-Lizard SSH keys and revert changes
# Parameters:
#   server_ip_remote - The hostname or IP address of the slave server
# Returns:
#   0 on success, 1 on failure
ssh_keys_remove() {
  local server_ip_remote="$1"
  local retval=0
  local remote_success=0
  local local_success=0

  if [[ -z $server_ip_remote ]]; then
    echo "Usage: ssh_keys_remove <server_ip_remote>"
    return 1
  fi

  # Revert changes on remote server
  if ssh "${SSH_OPTIONS[@]}" "$server_ip_remote" bash -c '
    if [[ -f ~/.ssh/authorized_keys ]]; then
      sed -i "/HA-Lizard_SSH_keys/d" ~/.ssh/authorized_keys
    fi
    rm -f ~/.ssh/ha-lizard ~/.ssh/ha-lizard.pub ~/.ssh/known_hosts
  '; then
    echo "Keys removed from remote server."
    remote_success=1
  else
    echo "Error: Failed to connect to remote server or execute commands."
    retval=2
  fi

  # Remove SSH keys from authorized_keys locally
  if [[ -f $SSH_AUTHORIZED_KEYS ]]; then
    if ! sed -i "/HA-Lizard_SSH_keys/d" "$SSH_AUTHORIZED_KEYS"; then
      echo "Error: Failed to remove SSH keys from local authorized_keys."
      retval=2
    fi
  fi

  # Remove local SSH keys and known_hosts entries
  if rm -f "$SSH_PRIVATE_KEY" "$SSH_PUBLIC_KEY" "$SSH_KNOW_HOSTS"; then
    local_success=1
  else
    echo "Error: Failed to remove local SSH keys or known_hosts."
    retval=1
  fi

  # Print success or partial success message
  if [[ $remote_success -eq 1 && $local_success -eq 1 ]]; then
    echo "Keys and configuration removed from local server and $server_ip_remote."
  elif [[ $local_success -eq 1 ]]; then
    echo "Keys and configuration were successfully removed locally, but there was an issue removing them from $server_ip_remote."
  elif [[ $remote_success -eq 1 ]]; then
    echo "Keys and configuration were successfully removed from $server_ip_remote, but there was an issue removing them locally."
  fi

  return $retval
}

# File Synchronization Function
# Synchronize local files with a remote server using rsync and SSH.
# Parameters:
#   server_ip_remote - The hostname or IP address of the remote server.
#   file_list - A space-separated list of files or directories to synchronize.
# Returns:
#   0 on success, 1 on failure, 2 if parameters are missing or invalid.
sync_files() {
  local server_ip_remote="$1" # Remote server's IP or hostname.
  shift                       # Remove the first argument (server_ip_remote) from the list.
  local file_list=("$@")      # Remaining arguments are treated as files to sync.

  # Check if the server IP and file list are provided.
  if [[ -z $server_ip_remote || ${#file_list[@]} -eq 0 ]]; then
    echo "Usage: sync_files <server_ip_remote> <file1> [file2 ... fileN]"
    return 2
  fi

  # Ensure SSH keys exist before proceeding.
  if [[ ! -f $SSH_PRIVATE_KEY || ! -f $SSH_PUBLIC_KEY ]]; then
    echo "SSH keys are missing. Run ssh_keys_create to generate them."
    return 1
  fi

  # Use rsync to synchronize the specified files or directories with the remote server.
  # The --relative option is used to preserve the directory structure, and --backup
  # is used to create backups of the files with the specified suffix.
  if ! rsync -avz --relative --backup --suffix="${BACKUP_SUFFIX}" -e "ssh ${SSH_OPTIONS[*]}" "${file_list[@]}" "$server_ip_remote:/"; then
    echo "Error synchronizing files with remote server $server_ip_remote."
    return 1
  fi

  # Successful synchronization.
  echo "Files synchronized successfully with remote server $server_ip_remote."
  return 0
}

# Updates or adds a configuration parameter in the specified configuration file.
#
# This function updates the parameter value if the parameter already exists in the
# configuration file. If the parameter does not exist, it adds the parameter with the
# specified value to the configuration file.
#
# Arguments:
#   conf_file (string): The path to the configuration file.
#   param_name (string): The name of the parameter to update or add.
#   param_value (string): The value to assign to the parameter.
#
# Returns:
#   int: Returns 0 on success, 1 on error.
#
# Errors:
#   - If the configuration file path is null or does not exist, returns an error.
#   - If the parameter name or value is not provided, returns an error.
#   - If updating or adding the parameter fails, returns an error.
update_local_conf() {

  local conf_file="$1"
  local param_name="$2"
  local param_value="$3"

  # Check for valid arguments
  if [[ -z $conf_file ]]; then
    echo "Error: Configuration file path is null."
    return 1
  elif [[ ! -f $conf_file ]]; then
    echo "Creating configuration file '$conf_file'."
    touch "$conf_file"
  elif [[ -z $param_name || -z $param_value ]]; then
    echo "Error: Both parameter name and value must be provided."
    return 1
  fi

  # Check if the parameter already exists in the configuration file
  if grep -q "^$param_name=" "$conf_file"; then
    # Replace the parameter value if it already exists
    sed -i "/^$param_name=/c\\$param_name=\"$param_value\"" "$conf_file" || return 1
  else
    # Add the parameter to the configuration file if it does not exist
    echo "$param_name=\"$param_value\"" >>"$conf_file" || return 1
  fi

  return 0
}

# Function to validate a UUID string format
# Takes one argument: the UUID to validate
# Returns 0 if valid, 1 if invalid
function validate_uuid() {
  local uuid="$1"

  # Regular expression for UUID format
  if [[ -n $uuid ]] && [[ $uuid =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
    return 0 # Valid UUID format
  else
    return 1 # Invalid UUID format
  fi
}

############################################
#
# xe wrapper command functions
#
############################################

# Function to execute an xe command and return the output as an array
# Execute an xe command and return the output as an array.
#
# Parameters:
#   subcommand (string): The xe subcommand to execute (e.g., "vm-list").
#   additional_args (string): Any additional arguments to pass to the xe command.
#
# Returns:
#   array: The output of the xe command as an array of UUIDs, separated by spaces.
#
# Errors:
#   - If no subcommand is provided, returns an error.
#   - If the xe command fails, returns an error.
xe_command() {
  # The subcommand to execute (e.g., "vm-list")
  local subcommand="$1"
  # Remove the subcommand from arguments
  shift

  # Validate that a subcommand is provided
  if [[ -z $subcommand ]]; then
    log "Error: No subcommand provided to xe_command."
    return 1
  fi

  # Execute the xe command with the provided arguments
  local output

  # Check if the command executed successfully
  if ! output=$(xe "$subcommand" "$@" --minimal 2>/dev/null); then
    log "Error: Failed to execute 'xe $subcommand'."
    return 1
  fi

  # If output is empty, return without error (no UUIDs is valid)
  if [[ -z $output ]]; then
    return 0
  fi

  # Convert comma-separated output into an array using IFS
  IFS=',' read -ra uuid_array <<<"$output"

  # Return the array as space-separated values
  echo "${uuid_array[@]}"
}

# Specific xe wrapper functions for common commands
#
# Description:
#   These functions are wrappers for various `xe` subcommands, making it easier to interact with XenServer.
#   Each function returns a list of UUIDs or other relevant data, depending on the subcommand.
#
# Parameters:
#   $@: Any additional arguments to pass to the `xe` command.
#
# Returns:
#   Array: The output of the `xe` command as an array of UUIDs, separated by spaces.

# Wrapper for host-list subcommand
xe_host_list() {
  xe_command "host-list" "$@"
}

# Wrapper for host-param-get subcommand
xe_host_param_get() {
  xe_command "host-param-get" "$@"
}

# Wrapper for message-list subcommand
xe_message_list() {
  xe_command "message-list" "$@"
}

# Wrapper for network-list subcommand
xe_network_list() {
  xe_command "network-list" "$@"
}

# Wrapper for pif-list subcommand
xe_pif_list() {
  xe_command "pif-list" "$@"
}

# Wrapper for pool-param-get subcommand
xe_pool_param_get() {
  xe_command "pool-param-get" "$@"
}

# Wrapper for vbd-list subcommand
xe_vbd_list() {
  xe_command "vbd-list" "$@"
}

# Wrapper for vdi-list subcommand
xe_vdi_list() {
  xe_command "vdi-list" "$@"
}

# Wrapper for vm-list subcommand
xe_vm_list() {
  xe_command "vm-list" "$@" "is-control-domain=false" "is-a-snapshot=false"
}

# Wrapper for vm-param-get subcommand
xe_vm_param_get() {
  xe_command "vm-param-get" "$@"
}

# Wrapper for pbd-list subcommand
xe_pbd_list() {
  xe_command "pbd-list" "$@"
}

# Wrapper for appliance-list subcommand
xe_appliance_list() {
  xe_command "appliance-list" "$@"
}

# Description:
#   Gets the master UUID for the specified pool.
#
# Use POOL_UUID (string) GLOBAL variables as parameter.
#
# Returns:
#   string: The master UUID for the pool, or an error if the pool UUID is not provided or if the command fails.
xe_pool_master_uuid() {

  # Validate that the pool UUID is provided
  if [[ -z $POOL_UUID ]]; then
    log "Error: No pool UUID provided to xe_pool_master_uuid."
    return 1
  fi

  # Get the master UUID for the pool
  pool_master_uuid=$(xe_pool_param_get uuid="$POOL_UUID" param-name=master)
  # If we get a result, return it, otherwise return an error
  if [[ -z $pool_master_uuid ]]; then
    log "Error: Failed to retrieve the master UUID for pool: $POOL_UUID"
    return 1
  fi

  # Return the pool master UUID
  echo "$pool_master_uuid"
}

############################################
# xe pool wrapper command functions
############################################
# Wrapper for pool-param commands: add, get, remove, set
# Execute the provided subcommand (e.g., "pool-param-add") with the pool UUID as the
# first argument and "param-name=other-config" as the second argument.
#
# Parameters:
#   subcommand (string): The pool-param subcommand to execute (e.g., "pool-param-add").
#   additional_args (string): Any additional arguments to pass to the pool-param command.
#
# Returns:
#   array: The output of the pool-param command as an array of UUIDs, separated by spaces.
#
# Errors:
#   - If no subcommand is provided, returns an error.
#   - If the pool-param command fails, returns an error.
xe_pool_command() {
  # The specific subcommand to execute (e.g., "pool-param-add")
  local subcommand="$1"
  # Remove the subcommand from the arguments
  shift

  # Validate that a subcommand is provided
  if [[ -z $subcommand ]]; then
    log "Error: No subcommand provided to xe_pool_command."
    return 1
  fi

  # Execute the command and capture the output
  local output
  # Check if the command executed successfully
  if ! output=$(xe "$subcommand" uuid="$POOL_UUID" "$@" 2>/dev/null); then
    # Log an error if the command fails
    log "Error: Failed to execute 'xe $subcommand $*'."
    return 1
  fi

  # Return the output if successful  (empty or not)
  echo "$output"
  return 0
}

# Retrieves all key-value pairs stored in the pool's "other-config" parameter.
#
# xe command output example:
# HA_FENCE_HEURISTICS_IPS: 192.168.10.1; HA_HOST_SELECT_METHOD: 0; HA_MGT_LINK_LOSS_TOLERANCE: 5;
#
# Parameters:
#   None
#
# Returns:
#   string: A space-separated list of key-value pairs retrieved from the "other-config" parameter.
#   If the command fails, logs an error and returns 1.
xe_pool_other_param_list() {
  # Execute the xe command to fetch "other-config"
  local output
  if ! output=$(xe pool-param-get uuid="$POOL_UUID" param-name=other-config 2>/dev/null); then
    # Log an error if the command fails
    log "Error: Failed to execute 'xe pool-param-get uuid=$POOL_UUID param-name=other-config'."
    return 1
  fi

  # Process the output: remove spaces, split on semicolons, filter by prefix, remove prefix and format as key-value pairs
  if [[ -n $output ]]; then
    echo "$output" | tr -d '[:space:]' | tr ';' '\n' | grep "^$PREFIX" | sed "s/^$PREFIX//; s/:/=/g"
  fi

  return 0
}

# Function to retrieve a specific key from the pool's "other-config" parameter
# Retrieve the value for a specific key from the pool's "other-config" parameter.
#
# Parameters:
#   param_key (string): The key to retrieve from the pool's "other-config" parameter.
#
# Returns:
#   string: The value associated with the given key in the pool's "other-config" parameter.
#
# Errors:
#   - If no key is provided, returns an error.
#   - If the key does not exist in the pool's "other-config" parameter, returns an error.
xe_pool_other_param_get() {
  local param_key="$1"

  # Validate input
  if [[ -z $param_key ]]; then
    log "Error: Missing parameter key for xe_pool_other_param_get."
    return 1
  fi

  # Retrieve the value for the given key
  local value
  value=$(xe_pool_command "pool-param-get" "param-name=other-config" "param-key=$param_key")

  # Check if the value is set
  if [[ -z $value ]]; then
    log "Error: Could not retrieve value for key '$param_key' from pool's 'other-config' parameter."
    return 1
  fi

  # Return the value
  echo "$value"
}

# Function to add a key-value pair to the pool's "other-config" parameter
#
# Function to add a key-value pair to the pool's "other-config" parameter.
#
# Parameters:
#   param_key (string): The key to add to the pool's "other-config" parameter.
#   param_value (string): The value associated with the key to be added.
#
# Returns:
#   0: If the key-value pair is successfully added.
#   1: If the key or value is missing, or if the command fails to add the key-value pair.
xe_pool_other_param_add() {
  local param_key="$1"
  local param_value="$2"

  # Validate inputs
  if [[ -z $param_key || -z $param_value ]]; then
    log "Error: Missing key or value for xe_pool_other_param_add."
    return 1
  fi

  if ! xe_pool_command "pool-param-add" "param-name=other-config" "$param_key=$param_value"; then
    log "Error: Unable to add key-value pair '$param_key=$param_value' to the pool's 'other-config' parameter."
    return 1
  fi
}

# Function to remove a key from the pool's "other-config" parameter
#
# Function to remove a key from the pool's "other-config" parameter.
#
# Parameters:
#   param_key (string): The key to remove from the pool's "other-config" parameter.
#
# Returns:
#   0: If the key is successfully removed.
#   1: If the parameter key is missing, or if the command fails to remove the key.
xe_pool_other_param_remove() {
  local param_key="$1"

  # Validate input
  if [[ -z $param_key ]]; then
    log "Error: Missing parameter key for xe_pool_other_param_remove."
    return 1
  fi

  # Execute the command
  if ! xe_pool_command "pool-param-remove" "param-name=other-config" "param-key=$param_key"; then
    log "Error: Unable to remove key '$param_key' from the pool's 'other-config' parameter."
    return 1
  fi
}

# Function to set a key-value pair in the pool's "other-config" parameter
#
# Description:
#   Sets a key-value pair in the pool's "other-config" parameter.
#
# Parameters:
#   param_key (string): The key to set in the parameter.
#   param_value (string): The value to set for the given key.
#
# Returns:
#   0: If the key-value pair was set successfully.
#   1: If the key-value pair could not be set.
xe_pool_other_param_set() {
  local param_key="$1"
  local param_value="$2"

  # Validate inputs
  if [[ -z $param_key || -z $param_value ]]; then
    log "Error: Missing key or value for xe_pool_other_param_add."
    return 1
  fi

  # Execute the command
  if ! xe_pool_command "pool-param-set" "other-config:$param_key=$param_value"; then
    log "Error: Unable to set key-value pair '$param_key=$param_value' in the pool's 'other-config' parameter."
    return 1
  fi
}
