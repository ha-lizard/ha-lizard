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
