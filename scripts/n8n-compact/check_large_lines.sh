#!/bin/bash

# Function to find lines larger than a certain character count
find_large_lines() {
    local file="$1"
    local max_length="$2"
    
    # Validate inputs
    if [[ ! -f "$file" ]]; then
        echo "Error: The file does not exist."
        exit 1
    fi

    if [[ ! "$max_length" =~ ^[0-9]+$ ]]; then
        echo "Error: The provided maximum length is not a valid number."
        exit 1
    fi

    # Loop through the lines and check their lengths
    line_number=1
    while IFS= read -r line; do
        line_length=${#line}

        # If line is longer than max_length, print the line number
        if [[ $line_length -gt $max_length ]]; then
            echo "$line_number"
        fi

        # Increment line number
        ((line_number++))
    done < "$file"
}

# Example usage
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <file_path> <max_length>"
    exit 1
fi

find_large_lines "$1" "$2"
