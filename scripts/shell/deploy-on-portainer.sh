#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 [-n STACK_NAME] [-u PORTAINER_URL] [-U USUARIO] [-p SENHA] [-h]"
    echo "  -n STACK_NAME      Name of the Docker stack to deploy"
    echo "  -d DOCKER_COMPOSE_PATH Path to the Docker Compose file"
    echo "  -u PORTAINER_URL   Domain or IP of the Portainer instance"
    echo "  -U USUARIO         Username for the Portainer instance"
    echo "  -p SENHA           Password for the Portainer instance"
    echo "  -h                 Display this help message"
    exit 1
}

# Parse command-line options using getopt
OPTS=$(getopt -o n:d:u:U:p:h --long stack-name:,docker-compose-path:,portainer-url:,username:,password:,help -n "$0" -- "$@")
if [ $? != 0 ]; then
    usage
fi

eval set -- "$OPTS"

# Default values
STACK_NAME=""
DOCKER_COMPOSE_PATH=""
PORTAINER_URL=""
USUARIO=""
SENHA=""

# Extract options and their arguments into variables
while true; do
    case "$1" in
        -n | --stack-name)
            STACK_NAME="$2"
            shift 2
            ;;
        -d | --docker-compose-path)
            DOCKER_COMPOSE_PATH="$2"
            shift 2
            ;;
        -u | --portainer-url)
            PORTAINER_URL="$2"
            shift 2
            ;;
        -U | --username)
            USUARIO="$2"
            shift 2
            ;;
        -p | --password)
            SENHA="$2"
            shift 2
            ;;
        -h | --help)
            usage
            ;;
        --)
            shift
            break
            ;;
        *)
            usage
            ;;
    esac
done

# Ensure that required arguments are provided
if [ -z "$STACK_NAME" ] || [ -z "$DOCKER_COMPOSE_PATH" ] || [ -z "$PORTAINER_URL" ] || [ -z "$USUARIO" ] || [ -z "$SENHA" ]; then
    echo "Error: Missing required arguments."
    usage
fi

# Check if jq is already installed, otherwise install it
install_jq() {
    if ! command -v jq &> /dev/null; then
        sudo apt-get install -y jq > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "2/10 - [ OK ] - Installed jq"
        else
            echo "2/10 - [ OFF ] - Error installing jq"
            exit 1
        fi
    else
        echo "2/10 - [ OK ] - jq is already installed"
    fi
}

# Function to check command success and variable presence
check_command_success() {
    local variable_value="$1"
    local success_message="$2"
    local failure_message="$3"
    local step_number="$4"
    local total_steps="$5"

    if [ $? -eq 0 ] && [ -n "$variable_value" ]; then
        echo "$step_number/$total_steps - [ OK ] - $success_message: $variable_value"
    else
        echo "$step_number/$total_steps - [ OFF ] - $failure_message"
        exit 1
    fi
}

# Function to attempt an API request with retries
attempt_api_request() {
    local url="$1"
    local data="$2"
    local token_key="$3"
    local attempt=1
    local max_attempts=5
    local response=""

    while [ -z "$response" ] || [ "$response" == "null" ]; do
        echo "Attempting to connect to $url (Attempt $attempt/$max_attempts)..."

        response=$(curl --fail -k -s -X POST \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$url" | jq -r "$token_key")

        if [ -n "$response" ] && [ "$response" != "null" ]; then
            break
        fi

        if [ $attempt -ge $max_attempts ]; then
            echo "Error: Failed to connect to $url after $attempt attempts."
            exit 1
        fi

        attempt=$((attempt + 1))
        sleep 5
    done

    echo "$response"
}

# Function to get Portainer token
get_portainer_token() {
    local url="https://$PORTAINER_URL/api/auth"
    local data="{\"username\":\"$USUARIO\",\"password\":\"$SENHA\"}"
    local token_key=".jwt"

    local token=$(attempt_api_request "$url" "$data" "$token_key")
    echo "7/10 - [ OK ] - Obtained Portainer token"
    echo "$token"
}

# Example usage inside a function
get_portainer_endpoint_id() {
    local endpoint_id=$(curl --fail -k -s -X GET -H "Authorization: Bearer $1" \
        "https://$PORTAINER_URL/api/endpoints" | jq -r '.[] | select(.Name == "primary") | .Id')

    check_command_success "$endpoint_id" "Obtained Portainer ID" "Error obtaining Portainer ID" 8 10

    echo "$endpoint_id"
}

# Get Swarm ID
get_portainer_endpoint_id() {
    local endpoint_id=$(curl --fail -k -s -X GET -H "Authorization: Bearer $1" \
        "https://$PORTAINER_URL/api/endpoints" | jq -r '.[] | select(.Name == "primary") | .Id')

    check_command_success "$endpoint_id" "Obtained Portainer ID" "Error obtaining Portainer ID" 8 10

    echo "$endpoint_id"
}

# Deploy stack
deploy_stack() {
    install_jq

    TOKEN=$(get_portainer_token)
    ENDPOINT_ID=$(get_portainer_endpoint_id "$TOKEN")
    SWARM_ID=$(get_swarm_id "$TOKEN" "$ENDPOINT_ID")

    SWARM_DEPLOY_URL="https://$PORTAINER_URL/api/stacks/create/swarm/file"
    error_output=$(mktemp)
    response_output=$(mktemp)

    trap 'rm -f "$error_output" "$response_output"' EXIT

    http_code=$(curl -s -o "$response_output" -w "%{http_code}" -k -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -F "Name=$STACK_NAME" \
        -F "file=@$DOCKER_COMPOSE_PATH" \
        -F "SwarmID=$SWARM_ID" \
        -F "endpointId=$ENDPOINT_ID" \
        "$SWARM_DEPLOY_URL" 2> "$error_output")

    response_body=$(cat "$response_output")

    if [ "$http_code" -eq 200 ]; then
        if echo "$response_body" | grep -q "\"Id\""; then
            echo "10/10 - [ OK ] - Successfully deployed stack $STACK_NAME"
        else
            echo "10/10 - [ OFF ] - Error: Unexpected server response during stack deployment."
            echo "Server response: $(echo "$response_body" | jq .)"
        fi
    else
        echo "10/10 - [ OFF ] - Error during deployment. HTTP response: $http_code"
        echo "Error message: $(cat "$error_output")"
        echo "Details: $(echo "$response_body" | jq .)"
    fi
}

# Call the deploy function
deploy_stack