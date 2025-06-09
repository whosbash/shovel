#!/bin/bash
# shellcheck shell=bash

set -euo pipefail
umask 077

#===============================#
#   TEMP FILE CLEANUP           #
#===============================#
TMPFILES=()
cleanup() {
  for f in "${TMPFILES[@]:-}"; do
    [[ -f "$f" ]] && rm -f "$f"
  done
}
trap cleanup EXIT

#===============================#
#   DEPENDENCY CHECK           #
#===============================#
missing_deps=()
for dep in curl jq getopt diff; do
  command -v "$dep" >/dev/null 2>&1 || missing_deps+=("$dep")
done
if (( ${#missing_deps[@]} > 0 )); then
  error_msg "Missing dependencies: ${missing_deps[*]}"
  exit 10
fi

#===============================#
#   CONFIGURABLE DEFAULTS      #
#===============================#
VERBOSE=false

#===============================#
#   COLOR CONSTANTS            #
#===============================#
yellow="\e[33m"
green="\e[32m"
white="\e[97m"
beige="\e[93m"
red="\e[91m"
reset="\e[0m"

#===============================#
#   UTILITY FUNCTIONS          #
#===============================#

error_msg() { echo -e "${red}Error:${reset} $1" >&2; }
warning_msg() { echo -e "${yellow}Warning:${reset} $1" >&2; }
success_msg() { echo -e "${green}$1${reset}" >&2; }
info_msg() { echo -e "${beige}$1${reset}" >&2; }
verbose_log() { [[ "$VERBOSE" == true ]] && echo -e "${white}[$(date '+%Y-%m-%d %H:%M:%S')] Verbose:${reset} $1"  >&2; }

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands (choose one):
  deploy     Deploy a new stack (default if no command is given)
  diff       Diff current vs new compose
  update     Update the stack
  delete     Delete the stack
  dry-run    Validate the compose file via the API, do not deploy/update (not supported)
  
Options:
  -r, --url           Portainer URL (e.g. portainer.example.com)
  -u, --username      Portainer username
  -p, --password      Portainer password (or set PORTAINER_PASSWORD env)
  -s, --stack-name    Name of the stack
  -f, --file-path     Path to docker-compose.yaml
  --wait              Wait for all stack services to be running after deploy/update
  -v, --verbose       Verbose output

Examples:
  $0 deploy   -r portainer.local -u admin -p secret -s mystack -f docker-compose.yaml --wait
  $0 update   -r portainer.local -u admin -p secret -s mystack -f docker-compose.yaml --wait
  $0 delete   -r portainer.local -u admin -s mystack

Notes:
  - This script requires valid SSL certificates on your Portainer instance.
  - Passwords are never echoed or logged.
  - 'dry-run' is not supported by the Portainer API and will always fail.
EOF
  exit 2
}

# Validate file and URL
validate_inputs() {
  [[ -z "${PORTAINER_URL:-}" || -z "${USERNAME:-}" || -z "${PASSWORD:-}" || -z "${STACK_NAME:-}" ]] && usage
  if [[ -z "${FILE_PATH:-}" && -z "${DO_DELETE:-}" && -z "${DO_LOGS:-}" && -z "${DO_DRYRUN:-}" ]]; then
    error_msg "Missing required argument: --file-path"
    usage
  fi
  if [[ -n "${FILE_PATH:-}" && ! -f "$FILE_PATH" ]]; then
    error_msg "Compose file '$FILE_PATH' does not exist."
    exit 3
  fi
  if ! [[ "$PORTAINER_URL" =~ ^[a-zA-Z0-9.-]+(:[0-9]+)?$ ]]; then
    error_msg "Invalid Portainer URL: $PORTAINER_URL"
    exit 4
  fi
}

# Curl with retry logic
curl_retry() {
  local max=3 delay=2 i=1
  while :; do
    curl "$@"
    local rc=$?
    if [[ $rc -eq 0 ]]; then return 0; fi
    if (( i >= max )); then return $rc; fi
    warning_msg "curl failed (attempt $i/$max), retrying in $delay seconds..."
    sleep $delay
    ((i++))
  done
}

#===============================#
#   AUTHENTICATION             #
#===============================#
authenticate() {
  local token
  token=$(curl_retry -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" \
    "https://$PORTAINER_URL/api/auth" | jq -r .jwt)
  if [[ -z "$token" || "$token" == "null" ]]; then
    error_msg "Failed to authenticate"
    exit 11
  fi
  echo "$token"
}

get_stack_id() {
  local resp
  resp=$(curl_retry -s -H "Authorization: Bearer $1" "https://$PORTAINER_URL/api/stacks")
  [[ $? -ne 0 ]] && error_msg "Failed to get stack list" && exit 12
  echo "$resp" | jq -r ".[] | select(.Name==\"$STACK_NAME\") | .Id"
}

get_endpoint_id() {
  local resp
  [[ -z "$PORTAINER_URL" ]] && error_msg "Portainer URL is not set." && exit 12
  [[ -z "$1" ]] && error_msg "Authentication token is not set." && exit 12

  resp=$(curl_retry -s -H "Authorization: Bearer $1" "https://$PORTAINER_URL/api/endpoints")
  [[ $? -ne 0 ]] && error_msg "Failed to get endpoints" && exit 13
  echo "$resp" | jq -r '.[0].Id'
}

get_swarm_id() {
  local resp
  resp=$(curl_retry -s -H "Authorization: Bearer $1" "https://$PORTAINER_URL/api/endpoints/$2/docker/swarm")
  [[ $? -ne 0 ]] && error_msg "Failed to get swarm ID" && exit 14
  echo "$resp" | jq -r .ID
}

fetch_remote_compose() {
  local tmpfile
  tmpfile=$(mktemp)
  TMPFILES+=("$tmpfile")
  curl_retry -s -H "Authorization: Bearer $1" "https://$PORTAINER_URL/api/stacks/$2/file" -o "$tmpfile"
  [[ $? -ne 0 ]] && error_msg "Failed to fetch remote compose file" && exit 15
  echo "$tmpfile"
}

#===============================#
#   STACK OPERATIONS           #
#===============================#
deploy_stack() {
  local swarm_id url http_code tmpfile
  swarm_id=$(get_swarm_id "$1" "$2")
  url="https://$PORTAINER_URL/api/stacks/create/swarm/file"
  tmpfile=$(mktemp)
  TMPFILES+=("$tmpfile")

  http_code=$(curl_retry -s -w "%{http_code}" -o "$tmpfile" \
    -X POST -H "Authorization: Bearer $1" \
    -F "Name=$STACK_NAME" -F "SwarmID=$swarm_id" -F "file=@$FILE_PATH" -F "endpointId=$2" "$url")
  if [[ "$http_code" == "200" ]]; then
    success_msg "Stack deployed successfully."
  else
    error_msg "Deploy failed. HTTP $http_code. Response:"
    cat "$tmpfile"
    exit 16
  fi
}

update_stack() {
  local compose_content
  compose_content=$(<"$FILE_PATH")
  curl_retry -s -X PUT "https://$PORTAINER_URL/api/stacks/$3?endpointId=$2" \
    -H "Authorization: Bearer $1" -H "Content-Type: application/json" \
    -d "{\"StackFileContent\":$(echo "$compose_content" | jq -Rs .)}"
  [[ $? -ne 0 ]] && error_msg "Failed to update stack" && exit 17
  success_msg "Stack updated successfully."
}

delete_stack() {
  curl_retry -s -X DELETE "https://$PORTAINER_URL/api/stacks/$2?endpointId=$3" \
    -H "Authorization: Bearer $1"
  [[ $? -ne 0 ]] && error_msg "Failed to delete stack" && exit 18
  info_msg "Stack deleted successfully."
}

diff_stack() {
  local remote_file
  remote_file=$(fetch_remote_compose "$1" "$2")
  if ! diff -u "$remote_file" "$FILE_PATH"; then
    :
  else
    info_msg "No diff or stack does not exist."
  fi
}

wait_for_stack_ready() {
  local token="$1" endpoint_id="$2" stack_id="$3" max_attempts=30 attempt=1
  while (( attempt <= max_attempts )); do
    local stack_info status
    stack_info=$(curl_retry -s -H "Authorization: Bearer $token" \
      "https://$PORTAINER_URL/api/stacks/$stack_id")
    if [[ $? -ne 0 || -z "$stack_info" ]]; then
      error_msg "Failed to fetch stack status (empty or error response)"
      exit 30
    fi
    status=$(echo "$stack_info" | jq -r '.Status // empty')
    if [[ "$status" == "1" ]]; then
      success_msg "Stack is ready (Status=1)."
      return 0
    fi
    
    sleep 3
    ((attempt++))
  done
  error_msg "Timeout waiting for stack to become ready."
  exit 31
}

#===============================#
#   ARGUMENT PARSING           #
#===============================#

# The first non-flag argument is the main command (diff, update, delete, dry-run, logs)
if [[ $# -eq 0 ]]; then
  usage
fi

MAIN_OP=""
case "$1" in
  deploy|diff|update|delete|dry-run|logs)
    MAIN_OP="$1"
    shift
    ;;
  *)
    MAIN_OP=""
    ;;
esac

# Now parse the rest as options
OPTS=$(getopt -o r:u:p:s:f:v --long url:,username:,password:,stack-name:,file-path:,wait,verbose -n 'parse-options' -- "$@")
eval set -- "$OPTS"

while true; do
  case "$1" in
    -r|--url)          PORTAINER_URL="$2"; shift 2;;
    -u|--username)     USERNAME="$2"; shift 2;;
    -p|--password)     PASSWORD="$2"; shift 2;;
    -s|--stack-name)   STACK_NAME="$2"; shift 2;;
    -f|--file-path)    FILE_PATH="$2"; shift 2;;
    --wait)            DO_WAIT=true; shift;;
    -v|--verbose)      VERBOSE=true; shift;;
    --) shift; break;;
    *) break;;
  esac
done

# Set the main operation variable based on MAIN_OP
DO_DIFF=; DO_UPDATE=; DO_DELETE=; DO_DRYRUN=; DO_LOGS=; DO_DEPLOY=
case "$MAIN_OP" in
  diff)    DO_DIFF=true ;;
  update)  DO_UPDATE=true ;;
  delete)  DO_DELETE=true ;;
  dry-run) DO_DRYRUN=true ;;
  logs)    DO_LOGS=true ;;
  deploy)  DO_DEPLOY=true ;;
  "")      DO_DEPLOY=true ;;  # Default to deploy if no command is given
  *) error_msg "Unknown main command: $MAIN_OP"; usage ;;
esac

#===============================#
#   VALIDATION                #
#===============================#
# Validate that at least one main operation is specified
if [[ -z "${DO_DIFF:-}" && -z "${DO_UPDATE:-}" && -z "${DO_DELETE:-}" && -z "${DO_DRYRUN:-}" && -z "${DO_LOGS:-}" && -z "${DO_DEPLOY:-}" ]]; then
  error_msg "No main operation specified. Use deploy, update, delete, diff, dry-run, or logs."
  exit 1
fi


# Secure password input
if [[ -z "${PASSWORD:-}" ]]; then
  if [[ -n "${PORTAINER_PASSWORD:-}" ]]; then
    PASSWORD="$PORTAINER_PASSWORD"
  else
    read -rsp "Portainer password: " PASSWORD
    echo
  fi
fi

validate_inputs

#===============================#
#   MAIN LOGIC                 #
#===============================#
TOKEN=$(authenticate)

ENDPOINT_ID=$(get_endpoint_id "$TOKEN")
STACK_ID=$(get_stack_id "$TOKEN")

if [[ -n "${DO_DELETE:-}" ]]; then
  [[ -z "$STACK_ID" ]] && info_msg "Stack does not exist." && exit 0
  delete_stack "$TOKEN" "$STACK_ID" "$ENDPOINT_ID"
elif [[ -n "${DO_UPDATE:-}" ]]; then
  if [[ -z "$STACK_ID" ]]; then
    error_msg "Cannot update: stack '$STACK_NAME' does not exist."
    exit 20
  fi
  update_stack "$TOKEN" "$ENDPOINT_ID" "$STACK_ID"
  [[ -n "${DO_WAIT:-}" ]] && wait_for_stack_ready "$TOKEN" "$ENDPOINT_ID" "$STACK_ID"
else
  # Default or explicit deploy
  if [[ -n "$STACK_ID" ]]; then
    error_msg "Stack already exists. Use update to update it."
    exit 22
  fi
  deploy_stack "$TOKEN" "$ENDPOINT_ID"
  [[ -n "${DO_WAIT:-}" ]] && STACK_ID=$(get_stack_id "$TOKEN") && wait_for_stack_ready "$TOKEN" "$ENDPOINT_ID" "$STACK_ID"
fi
