#!/bin/bash

# Function to fetch stable tags from a response
fetch_stable_tags_from_page() {
    echo "$1" | jq -r '.results[].name' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$|^[0-9]+\.[0-9]+$'
}

# Determine if an image is official
is_official_image() {
    # Measure execution time
    local image_name=$1
    local response=""

    # Try fetching the official image first
    response=$(curl -fsSL "https://hub.docker.com/v2/repositories/library/${image_name}" 2>/dev/null)
    
    # Check if the response contains 'name' indicating it's an official image
    if [ $? -eq 0 ] && echo "$response" | jq -e '.name' >/dev/null 2>&1; then
        echo "true"  # It's an official image
        return
    fi

    # If official image fails, try fetching the non-official image (user/organization image)
    response=$(curl -fsSL "https://hub.docker.com/v2/repositories/${image_name}")
    
    # If the response contains 'name', it's a valid (non-official) image
    if [ $? -eq 0 ] && echo "$response" | jq -e '.name' >/dev/null 2>&1; then
        echo "false"  # It's a non-official image
    else
        # If neither the official nor non-official image is found, return false
        echo "false"  # Image not found
    fi
}

# Get the latest stable version
get_latest_stable_version() {
    local image_name=$1
    local base_url=""
    local current_url=""
    local total_count=0
    local stable_tags=()
    local latest_version=""

    start_time=$(date +%s%N)

    # Set the correct base URL
    if [ "$(is_official_image "$image_name")" == "true" ]; then
        base_url="https://hub.docker.com/v2/repositories/library/${image_name}/tags?page_size=100"
    else
        base_url="https://hub.docker.com/v2/repositories/${image_name}/tags?page_size=100"
    fi

    # Fetch the first page to determine total pages
    response=$(curl -fsSL "$base_url" || echo "")
    if [ -z "$response" ] || [ "$(echo "$response" | jq -r '.count')" == "null" ]; then
        echo "Image '$image_name' not found or registry unavailable."
        return 1
    fi

    total_count=$(echo "$response" | jq -r '.count')
    total_pages=$(( (total_count + 99) / 100 ))

    # Perform binary search for latest stable version
    low=1
    high=$total_pages
    while [ $low -le $high ]; do
        mid=$(((low + high) / 2))
        current_url="${base_url}&page=$mid"

        # Fetch the page
        response=$(curl -fsSL "$current_url" || echo "")
        if [ -z "$response" ]; then
            low=$((mid + 1)) # Skip to upper half if the page is invalid
            continue
        fi

        # Extract stable tags
        page_tags=$(fetch_stable_tags_from_page "$response")
        if [ -n "$page_tags" ]; then
            stable_tags+=($page_tags)
            high=$((mid - 1)) # Search lower half for potentially newer tags
        else
            low=$((mid + 1)) # Search upper half
        fi
    done

    # Calculate elapsed time
    end_time=$(date +%s%N)
    elapsed_ns=$((end_time - start_time))
    elapsed_sec=$(echo "scale=3; $elapsed_ns / 1000000000" | bc)

    # Display time taken
    echo "⏱ Time taken: ${elapsed_sec} seconds"


    # Find the latest stable version
    if [ ${#stable_tags[@]} -gt 0 ]; then
        latest_version=$(printf "%s\n" "${stable_tags[@]}" | sort -V | uniq | tail -n 1)
        echo "Latest version for $image_name: $latest_version"
    else
        echo "No stable version found for $image_name."
    fi
}

# Validate input
if [ $# -eq 0 ]; then
    echo "Usage: $0 <image_name1> <image_name2> ..."
    exit 1
fi

# Measure execution time
start_time=$(date +%s%N)

# Run for each image in parallel
for image_name in "$@"; do
    get_latest_stable_version "$image_name" &  # Run in background
done

# Wait for all background jobs to complete
wait

end_time=$(date +%s%N)

# Calculate elapsed time
elapsed_ns=$((end_time - start_time))
elapsed_sec=$(echo "scale=3; $elapsed_ns / 1000000000" | bc)

# Display time taken
echo "⏱ Time taken: ${elapsed_sec} seconds"
