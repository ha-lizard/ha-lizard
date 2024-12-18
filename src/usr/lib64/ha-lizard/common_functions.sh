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

  # Generate the backup file name with the current timestamp
  local timestamp
  local backup_file_path
  timestamp=$(date +"%Y%m%d_%H%M%S")
  backup_file_path="${dir_path}/${file_name}_halizard_bkp_${timestamp}"

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
function make_box() {
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

  # Split input into individual lines
  IFS=$'\n' # Handle multi-line input correctly
  local lines=()
  while IFS= read -r line; do
    # Truncate lines that are too long to fit in the available width
    if [ ${#line} -gt $available_width ]; then
      line="${line:0:available_width}"
    fi
    lines+=("$line")
  done <<<"$input"

  # Calculate the longest line length
  local longest_line=0
  for line in "${lines[@]}"; do
    [ ${#line} -gt "$longest_line" ] && longest_line=${#line}
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
      local padding=$((longest_line - ${#lines[i]}))
      printf "%${offset_x}s| %s%*s |\n" "" "${lines[i]}" $padding ""
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
