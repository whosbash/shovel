#!/bin/bash

# Function to check if a Docker image exists in the registry
check_image_exists() {
    local image_name=$1
    local tag=${2:-latest} # Default to "latest" if no tag is provided
    local url="https://registry.hub.docker.com/v2/repositories/library/${image_name}/tags/${tag}/"

    # Make a request to the registry
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url")

    # Check the HTTP status code
    if [ "$response" -eq 200 ]; then
    elif [ "$response" -eq 404 ]; then
        exit 1  # Exit if the image doesn't exist
    else
        exit 1  # Exit in case of an error while checking
    fi
}

# Function to fetch stable tags from a given page
fetch_stable_tags_from_page() {
    local response=$1

    # Extract tags from the page response and filter only valid stable versions
    echo "$response" | jq -r '.results[].name' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$|^[0-9]+\.[0-9]+$'
}

# Main function to get the latest stable version
get_latest_stable_version() {
    local image_name=$1
    local base_url="https://registry.hub.docker.com/v2/repositories/library/${image_name}/tags?page_size=100"
    local current_url=$base_url
    local latest_version=""
    local total_count=0
    local stable_tags=()

    check_image_exists "$image_name" 2>&1 >/dev/null
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Fetch the first page to get the total count
    response=$(curl -s "$current_url")
    total_count=$(echo "$response" | jq -r '.count')
    total_pages=$(( (total_count + 99) / 100 )) # Calculate total pages (rounding up)
    
    # Fetch stable tags from the first page
    page_tags=$(fetch_stable_tags_from_page "$response")

    # If stable tags are found on the first page, stop and report
    if [ -n "$page_tags" ]; then
        latest_version=$(printf "%s\n" "${page_tags[@]}" | sort -V | uniq | tail -n 1)
        echo "${latest_version}"
        return  # Exit the function early since we found stable versions
    fi

    # Setting up binary search interval
    low=1         # Initial low page number
    high=$total_pages  # Start with the last page

    # Implementing binary search for stable versions
    while [ $low -le $high ]; do
        mid=$(((low + high) / 2))  # Find the middle page

        current_url="${base_url}&page=$mid"
        
        # Fetch the current page
        response=$(curl -s "$current_url")
        
        # Fetch stable tags from the current page
        page_tags=$(fetch_stable_tags_from_page "$response")

        # Add stable tags from this page to the list, ensuring uniqueness
        stable_tags+=($page_tags)

        # Check if stable tags were found
        if [ -n "$page_tags" ]; then            
            # Find the latest stable version from the tags found
            latest_version=$(printf "%s\n" "${stable_tags[@]}" | sort -V | uniq | tail -n 1)

            # If a stable tag is found, we need to narrow the search to the lower half
            high=$((mid - 1))
        else
            # No stable tags found, move forward to the next interval (upper half)
            low=$((mid + 1))
        fi
    done

    if [ -n "$latest_version" ]; then
        echo "${latest_version}"
    else
        echo "latest"
    fi
}

# Validate input
if [ -z "$1" ]; then
    echo "Usage: $0 <image_name>"
    exit 1
fi

# Call the function to check if the image exists in the registry
check_image_exists "$1"

# Call the function to get the latest stable version of the image
get_latest_stable_version "$1"
