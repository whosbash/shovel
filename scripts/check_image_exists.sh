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
        echo "✅ The image '${image_name}:${tag}' exists in the Docker registry."
    elif [ "$response" -eq 404 ]; then
        echo "❌ The image '${image_name}:${tag}' does not exist in the Docker registry."
    else
        echo "⚠️ Error checking the image '${image_name}:${tag}'. HTTP Status: $response"
    fi
}

# Validate input
if [ -z "$1" ]; then
    echo "Usage: $0 <image_name> [tag]"
    exit 1
fi

# Call the function with the provided image name and optional tag
check_image_exists "$1" "$2"
