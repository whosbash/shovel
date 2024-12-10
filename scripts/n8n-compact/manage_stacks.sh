#!/bin/bash

# Enable error handling
set -e

######################################### BEGIN OF CONSTANTS #######################################

# Define colors with consistent names
declare -A COLORS=(
    [yellow]="\e[33m"
    [light_yellow]="\e[93m"
    [green]="\e[32m"
    [light_green]="\e[92m"
    [white]="\e[97m"
    [beige]="\e[93m"
    [red]="\e[91m"
    [light_red]="\e[31m"
    [blue]="\e[34m"
    [light_blue]="\e[94m"
    [cyan]="\e[36m"
    [light_cyan]="\e[96m"
    [magenta]="\e[35m"
    [light_magenta]="\e[95m"
    [black]="\e[30m"
    [gray]="\e[90m"
    [dark_gray]="\e[37m"
    [light_gray]="\x1b[38;5;245m"
    [orange]="\x1b[38;5;214m"
    [purple]="\x1b[38;5;99m"
    [pink]="\x1b[38;5;200m"
    [brown]="\x1b[38;5;94m"
    [teal]="\x1b[38;5;80m"
    [gold]="\x1b[38;5;220m"
    [lime]="\x1b[38;5;154m"
    [reset]="\e[0m"
)


# Define text styles
declare -A STYLES=(
    [bold]="\e[1m"
    [dim]="\e[2m"
    [italic]="\e[3m"
    [underline]="\e[4m"
    [hidden]="\e[8m"
    [reverse]="\e[7m"
    [strikethrough]="\e[9m"
    [double_underline]="\e[21m"
    [overline]="\x1b[53m"
    [bold_italic]="\e[1m\e[3m"
    [underline_bold]="\e[4m\e[1m"
    [dim_italic]="\e[2m\e[3m"
    [reset]="\e[0m"
)


# Global variables
HAS_TIMESTAMP=true
DEFAULT_SERVER_NAME="default_server"
DEFAULT_NETWORK="swarm_network"
DEFAULT_TYPE='info'


########################################## END OF CONSTANTS ########################################

################################ BEGIN OF GENERAL UTILITARY FUNCTIONS ##############################

# Function to generate a random string
random_string() {
    local length="${1:-16}"

    local word="$(openssl rand -hex $length)"
    echo "$word"
}


# Function to validate a name
validate_variable_name() {
    local name="$1"

    # Regex pattern:
    if [[ "$name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9_.-]*[a-zA-Z0-9])?$ ]] && \
        ! [[ "$name" =~ (--|\.\.|__) ]]; then
        return 0  # Valid name
    else
        # Display the error message in a list format
        echo "Error: Invalid name '$name'."
        echo "Naming rules:"
        echo "1. Only letters, numbers, hyphens (-), underscores (_), and dots (.) are allowed."
        echo "2. The name must start and end with a letter or number."
        echo "3. Consecutive special characters (__, --, ..) are not allowed."
        echo "4. Names cannot exceed 255 characters."
        return 1  # Invalid name
    fi
}


# Function to retrieve the IP address
get_ip(){
    echo "$(hostname -I | awk '{print $1}')"
}


# Function to check if a package is already installed
is_package_installed() {
    local package="$1"
    dpkg -l | grep -q "$package"
}


# Function to wait for a specified number of seconds
wait_secs() {
    local seconds=$1
    sleep "$seconds"
}


# Function to extract values from the collection output
extract_value_from_json() {
    local json_data="$1"
    local key="$2"
    echo "$json_data" | jq -r ".[] | select(.name == \"$key\") | .value"
}


# Function to clear previous line
clear_line() {
    tput cuu1   # Move the cursor up one line
    tput el     # Clear the current line
}


# Function to clear multiple previous lines
clear_lines() {
    local lines=$1  # Number of lines to clear
    for i in $(seq 1 "$lines"); do
        clear_line
    done
}



# Function to install a package
install_package() {
    local package="$1"
    
    # Check if the package is already installed
    if is_package_installed "$package"; then
        warning "Package '$package' is already installed, skipping..."
    else
        info "Starting installation of package: $package"
        
        # Try to install the package and check for success
        if ! DEBIAN_FRONTEND=noninteractive apt install "$package" -yq \
        --no-install-recommends > /dev/null 2>&1; then
            error "Failed to install package: $package. Check logs for more details."
            exit 1
        else
            success "Successfully installed package: $package"
        fi
    fi
}


# Function to install all packages and track progress
install_all_packages() {
    local packages=("$@")  # The list of packages to install (passed as arguments)
    local total_packages=${#packages[@]}
    local installed_count=0

    # Install each package
    for package in "${packages[@]}"; do
        install_package "$package"
        installed_count=$((installed_count + 1))
    done
}


# Function to wait apt process lock to free 
wait_apt_lock(){
    local attempt_interval=${$1-5}
    local max_wait_time=${$2-60}

    # Wait for the lock to be released or forcefully remove it if needed
    wait_time=0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        if [ "$wait_time" -ge "$max_wait_time" ]; then
            error "APT lock held for too long. Attempting to kill process."
            lock_pid=$(lsof /var/lib/dpkg/lock-frontend | awk 'NR==2 {print $2}')
            if [[ -n "$lock_pid" ]]; then
                kill -9 "$lock_pid"
                info "Killed process $lock_pid holding APT lock."
            fi
        fi
        info "Waiting for APT lock to be released..."
        sleep $WAIT_INTERVAL
        wait_time=$((wait_time + attempt_interval))
    done
}


# Function to strip existing ANSI escape sequences (colors and styles) from a string
strip_ansi() {
    echo -e "$1" | sed 's/\x1b\[[0-9;]*[mK]//g'
}


# Function to trim leading/trailing spaces
trim() {
    echo "$1" | sed 's/^ *//;s/ *$//'
}


query_64json() {
    local item="$1"
    local field="$2"
    echo "$item" | base64 --decode | jq -r "$field"
}



# Function to apply color and style to a string, even if it contains existing color codes
colorize() {
    local text="$1"
    local color_name=$(echo "$2" | tr '[:upper:]' '[:lower:]')
    local style_name=$(echo "$3" | tr '[:upper:]' '[:lower:]')

    # Remove any existing ANSI escape sequences (colors or styles) from the text
    text=$(strip_ansi "$text")

    # Get color code, default to reset if not found
    local color_code="${COLORS[$color_name]:-${COLORS[reset]}}"
    
    # If no style name is provided, use "reset" style as default
    if [[ -z "$style_name" ]]; then
        local style_code="${STYLES[reset]}"
    else
        local style_code="${STYLES[$style_name]:-${STYLES[reset]}}"
    fi

    # Print the text with the chosen color and style
    echo -e "${style_code}${color_code}${text}${STYLES[reset]}${COLORS[reset]}"
}


# Function to display a step with improved formatting
get_status_icon() {
    local type="$1"

    case "$type" in
        "success") echo "✅" ;;         # Success icon
        "error") echo "❌" ;;           # Error icon
        "warning") echo "⚠️" ;;         # Warning icon
        "info") echo "📖" ;;            # Info icon
        "highlight") echo "✨" ;;       # Highlight icon
        "debug") echo "🐞" ;;           # Debug icon
        "critical") echo "🚨" ;;        # Critical icon
        "note") echo "📝" ;;            # Note icon
        "important") echo "⚡" ;;       # Important icon
        "wait") echo "⏳" ;;            # Highlight icon
        "question") echo "❓" ;;        # Question icon
        *) echo "🔵" ;;                 # Default icon (e.g., ongoing step)
    esac
}


# Function to get the color code based on the message type
get_status_color() {
    case "$type" in
        "success") echo "green" ;;
        "error") echo "red" ;;
        "warning") echo "yellow" ;;
        "info") echo "white" ;;
        "highlight") echo "cyan" ;;
        "debug") echo "blue" ;;
        "critical") echo "magenta" ;;
        "note") echo "gray" ;;
        "important") echo "orange" ;;
        "wait") echo "white" ;;
        "question") echo "purple" ;;
        *) echo "white" ;;  # Default to white for unknown types
    esac
}


# Function to get the style code based on the message type
get_status_style() {
    case "$type" in
        "success") echo "bold" ;;                      # Bold for success
        "info") echo "italic" ;;                       # Italic for informational messages
        "error") echo "bold,italic" ;;                 # Bold and italic to emphasize importance
        "critical") echo "bold,underline" ;;           # Bold and underline to highlight severity
        "warning") echo "underline" ;;                 # Underline for warnings to draw attention
        "highlight") echo "bold,underline" ;;          # Bold and underline to emphasize key points
        "wait") echo "dim,italic" ;;                   # Dim and italic to indicate pending status
        "important") echo "bold,underline,overline" ;; # Bold, underline, and overline to importance
        "question") echo "italic,underline" ;;         # Italic and underline to prompt input
        *) echo "normal" ;;                            # Default to normal style for unknown types
    esac
}


# Function to colorize a message based on its type
colorize_by_type() {
    local type="$1"
    local text="$2"

    colorize "$text" "$(get_status_color "$type")" "$(get_status_style "$type")"
}


# General function to format and display messages with optional timestamp, color, and icon
format_message() {
    local type="$1"              # Message type (success, error, etc.)
    local text="$2"              # Message text
    local has_timestamp="${3:-$HAS_TIMESTAMP}" # Option to display timestamp (default is false)

    # Get icon based on status
    local icon  
    icon=$(get_status_icon "$type")

    # Add timestamp if enabled
    local formatted_message="$text"
    if [ "$has_timestamp" = true ]; then
        formatted_message="[$(date '+%Y-%m-%d %H:%M:%S')] $formatted_message"
    fi

    colorized_message="$(colorize_by_type "$type" "$formatted_message")"

    # Display the message with icon, color, style, and timestamp (if enabled)
    echo -e "$icon $colorized_message"
}


# Function to display a message with improved formatting
echo_message() {
    local type="$1"
    local text="$2"
    local timestamp="${3:-$HAS_TIMESTAMP}"
    
    echo -e "$(format_message "$type" "$text" $timestamp)"
}


# Function to display a step with improved formatting
step() {
    local current_step="$1"         # Current step number
    local total_steps="$2"          # Total number of steps
    local message="$3"              # Step message
    local type="${4:-DEFAULT_TYPE}" # Status type (default to 'info')
    local timestamp="${5:-$HAS_TIMESTAMP}"          # Optional timestamp flag

    # If 'timestamp' is passed as an argument, prepend the timestamp to the message
    if [ -n "$timestamp" ]; then
        local formatted_message=$(format_message "$type" "$step_message" true)
    else
        local formatted_message=$(format_message "$type" "$step_message" false)
    fi

    # Format the step message with the specified color and style
    local message="Step $current_step/$total_steps: $message"
    formatted_message=$(format_message "$type" "$message" $timestamp)

    # Print the formatted message with the icon and message
    echo -e "$formatted_message" >&2
}


# Function to display step success message
step_info(){
    local current=$1
    local total=$2
    local message=$3
    local has_timestamp={$4:-$HAS_TIMESTAMP}
    
    step $current $total $message "info" $has_timestamp
}


# Function to display step success message
step_success(){
    local current=$1
    local total=$2
    local message=$3
    local has_timestamp={$4:-$HAS_TIMESTAMP}
    
    step $current $total $message "success" $has_timestamp
}


# Function to display step error message
step_error(){
    local current=$1
    local total=$2
    local message=$3
    local has_timestamp={$4:-$HAS_TIMESTAMP}
    
    step $current $total $message "error" $has_timestamp
}


# Function to display step success message
step_warning(){
    local current=$1
    local total=$2
    local message=$3
    local has_timestamp={$4:-$HAS_TIMESTAMP}
    
    step $current $total $message "warning" $has_timestamp
}


# Function to display step success message
step_info(){
    local current=$1
    local total=$2
    local message=$3
    local has_timestamp={$4:-$HAS_TIMESTAMP}
    
    step $current $total $message "info" $has_timestamp
}


# Function to display success formatted messages
success() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'success' "$message" $timestamp >&2
}


# Function to display error formatted messages
error() {
    local message="$1"          # Step message
    local timestamp=""${2:-$HAS_TIMESTAMP}""      # Optional timestamp flag
    echo_message 'error' "$message" $timestamp >&2
}


# Function to display warning formatted messages
warning() {
    local message="$1"                          # Step message
    local timestamp=""${2:-$HAS_TIMESTAMP}""    # Optional timestamp flag
    echo_message 'warning' "$message" $timestamp >&2
}


# Function to display info formatted messages
info() {
    local message="$1"                          # Step message
    local timestamp=""${2:-$HAS_TIMESTAMP}""    # Optional timestamp flag
    echo_message 'info' "$message" $timestamp >&2
}


# Function to display highlight formatted messages
highlight() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'highlight' "$message" $timestamp >&2
}


# Function to display debug formatted messages
debug() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'debug' "$message" $timestamp >&2
}


# Function to display critical formatted messages
critical() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'critical' "$message" $timestamp >&2
}


# Function to display note formatted messages
note() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'note' "$message" $timestamp >&2
}


# Function to display important formatted messages
important() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'important' "$message" $timestamp >&2
}


# Function to display wait formatted messages
wait() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'wait' "$message" $timestamp >&2
}


# Function to display wait formatted messages
question() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'question' "$message" $timestamp >&2
}


# Function to convert associative array to JSON format
convert_array_to_json() {
    # Use reference to the associative array
    local -n dict=$1  
    json_output="{"
    
    for key in "${!dict[@]}"; do
        value="${dict[$key]}"
        json_output+="\"$key\": \"$value\", "
    done
    
    # Remove trailing comma if present
    json_output="${json_output%, }"
    json_output+="}"
    
    echo "$json_output"
}


# Function to convert each element of a JSON array to base64
convert_json_array_to_base64_array() {
    local json_array="$1"
    # Convert each element of the JSON array to base64 using jq
    echo "$json_array" | jq -r '.[] | @base64'
}


# Function to validate the value (can be customized)
validate_value() {
    local value="$1"
    local validator="$2"
    local name="$3"
    
    # If no validator is provided, consider it valid
    if [[ -z "$validator" ]]; then
        return 0
    fi

    # Call the validation function dynamically
    message="$("$validator" "$value")"  # Capture the message returned by the validator
    if [[ $? -ne 0 ]]; then
        return 1  # Return 1 if the validation fails, indicating failure
    fi

    return 0  # Validation passed
}


# Function to create a collection item
create_collection_item() {
    local name="$1"
    local label="$2"
    local description="$3"
    local value="$4"
    local required="$5"
    local validate_fn="$6"

    # Check if the item is required and the value is empty
    if [[ "$required" == "yes" && -z "$value" ]]; then
        error_message="The value for '$name' is required but is empty."
        error_obj=$(create_error_object "$name" "$error_message" "$LINENO" "${FUNCNAME[0]}")
        echo "$error_obj"
        return 1
    fi

    # Validate the value using the provided validation function
    if ! validate_value "$value" "$validate_fn" "$name"; then
        # Capture the message returned by the validator
        error_message="$message"
        error_obj=$(create_error_object "$name" "$error_message" "$LINENO" "$validate_fn")
        echo "$error_obj"
        return 1
    fi

    # Build the JSON object by echoing the data and piping it to jq for proper escaping
    item_json=$(echo "
    {
        \"name\": \"$name\",
        \"label\": \"$label\",
        \"description\": \"$description\",
        \"value\": \"$value\",
        \"required\": \"$required\"
    }" | jq .)

    # Check if jq creation was successful
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create JSON object"
        return 1  # Return an error code
    fi

    # Return the JSON object
    echo "$item_json"
}


# Function to create a collection item
create_collection_item() {
    local name="$1"
    local label="$2"
    local description="$3"
    local value="$4"
    local required="$5"
    local validate_fn="$6"

    # Check if the item is required and the value is empty
    if [[ "$required" == "yes" && -z "$value" ]]; then
        error_message="The value for '$name' is required but is empty."
        error_obj=$(create_error_object "$name" "$error_message" "$LINENO" "${FUNCNAME[0]}")
        echo "$error_obj"
        return 1
    fi

    # Validate the value using the provided validation function
    if ! validate_value "$value" "$validate_fn" "$name"; then
        # Capture the message returned by the validator
        error_message="$message"
        error_obj=$(create_error_object "$name" "$error_message" "$LINENO" "$validate_fn")
        echo "$error_obj"
        return 1
    fi

    # Build the JSON object by echoing the data and piping it to jq for proper escaping
    item_json=$(echo "
    {
        \"name\": \"$name\",
        \"label\": \"$label\",
        \"description\": \"$description\",
        \"value\": \"$value\",
        \"required\": \"$required\"
    }" | jq .)

    # Check if jq creation was successful
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create JSON object"
        return 1  # Return an error code
    fi

    # Return the JSON object
    echo "$item_json"
}


# Function to prompt for user input and return the result
prompt_for_input() {
    local item="$1"      # Base64-encoded JSON item
    
    local value=""        # User input value
    local requirement=""  # Input requirement (required or optional)
    
    local name=""         # Name extracted from the item
    local description=""  # Description extracted from the item
    local required=""     # Whether the input is required or optional

    # Decode the base64-encoded item and extract fields using jq
    name=$(query_64json "$item" '.name')
    description=$(query_64json "$item" '.description')
    required=$(query_64json "$item" '.required')

    # Determine whether the input is required or optional
    if [[ "$required" == "yes" ]]; then
        requirement="required"
    else
        requirement="optional"
    fi

    # Generate the prompt message with formatting
    prompt="Prompting variable $name ($requirement): $description\nEnter a value or type 'q' to quit: "
    
    # Format the prompt message using your format_message function
    fmt_prompt="$(format_message 'question' "$prompt")"

    while true; do
        # Read the user input
        read -rp "$fmt_prompt" value

        # Return exit signal
        if [[ "$value" == "q" ]]; then
            echo "q"  # Return exit signal instead of terminating the script
            return
        fi

        # Validate input if required
        if [[ -n "$value" || "$required" == "no" ]]; then
            break  # User input is valid, break the loop
        else
            warning "$name is required. Please enter a value."
        fi
    done

    # Return only the user input, not the prompt message
    echo "$value"
}


collect_prompt_info() {
    # Initialize an empty JSON array
    json_array="[]"

    # Loop through each item in the JSON array using jq
    for item in $(convert_json_array_to_base64_array "$1"); do
        # Decode the base64 item to extract necessary fields
        decoded_item=$(echo "$item" | base64 --decode)
        name=$(echo "$decoded_item" | jq -r '.name')
        label=$(echo "$decoded_item" | jq -r '.label')
        description=$(echo "$decoded_item" | jq -r '.description')
        required=$(echo "$decoded_item" | jq -r '.required')

        # Set the prompt message
        prompt="\
            Prompting variable $name ($required): $description\n
            Enter a value or type 'q' to quit: \
        "
        
        # Collect input based on the item
        value=$(prompt_for_input "$item")

        # If the user typed "exit", return an empty JSON array and exit
        if [[ "$value" == "q" ]]; then
            echo "[]"
            return 0  # Exit function immediately with empty array
        fi

        # Create a JSON object with name, description, required, and the user input value
        json_object=$(\
            create_collection_item "$name" "$label" "$description" "$value" "$required"\
        )

        # Add the new object to the JSON array
        json_array=$(echo "$json_array" | jq ". += [$json_object]")
    done

    # Output the final JSON array with all items
    echo "$json_array"
}


confirm_and_modify_prompt_info() {
    local json_array="$1"

    while true; do
        # Display collected information to stderr (for terminal)
        info "Provided values: "
        echo "$json_array" | jq -r '.[] | "\(.name): \(.value)"' | while IFS= read -r line; do
            info "\t$line"
        done

        # Ask for confirmation (stderr)
        options="y to confirm, n to modify, or q to quit"
        confirmation_msg="$(
            format_message "question" "Is the information correct? ($options) "
        )"
        read -rp "$confirmation_msg" confirmation

        case "$confirmation" in
        y)
            # Output the final JSON to stdout (for file capture)
            echo "$json_array"
            break
            ;;
        n)
            # Ask for the field to modify (stderr)
            field_query="$(
                format_message "question" "Which field would you like to modify? "
            )"
            read -rp "$field_query" field_to_modify

            # Check if the field exists in the JSON and ask for modification
            current_value=$(\
                echo "$json_array" | \
                jq -r \
                    --arg field "$field_to_modify" \
                    '.[] | select(.name == $field) | .value'
            )

            if [[ -n "$current_value" ]]; then
                info "Current value for $field_to_modify: $current_value"
                
                new_value_query="$(format_message "question" "Enter new value: ")"
                read -rp "$new_value_query" new_value
                if [[ -n "$new_value" ]]; then
                    # Modify the JSON by updating the value of the specified field
                    json_array=$(
                        echo "$json_array" | 
                        jq --arg field "$field_to_modify" --arg value "$new_value" \
                        '(.[] | select(.name == $field) | .value) = $value | .'
                    )
                else
                    error "Value cannot be empty."
                fi
            else
                warning "Field '$field_to_modify' not found."
            fi
            ;;
        q)
            exit 0
            ;;
        *)
            error "Invalid input. Please enter 'y', 'n', or 'q'."
            ;;
        esac
    done
}


# New Function to Combine the Process
run_collection_process() {
    local items="$1"  # Accept items array as input

    collected_info="$(collect_prompt_info "$items")"

    # If no values were collected, exit early
    if [[ "$collected_info" == "[]" ]]; then
        echo "[]"
        exit 0
    fi

    # Confirm and modify information
    checked_values=$(confirm_and_modify_prompt_info "$collected_info")

    echo "$checked_values"
}


# Recursive function to validate JSON against a schema
validate_json_recursive() {
    local json="$1"
    local schema="$2"
    local parent_path="$3"  # Track the JSON path for better error reporting
    local valid=true
    local errors=()

    # Extract required keys, properties, and additionalProperties from the schema
    local required_keys=$(echo "$schema" | jq -r '.required[]? // empty')
    local properties=$(echo "$schema" | jq -r '.properties // empty')
    
    jq_query='if has("additionalProperties") then .additionalProperties else true end'
    local additional_properties=$(echo "$schema" | jq -r "$jq_query")

    # Check if required keys are present
    for key in $required_keys; do
        if ! echo "$json" | jq -e ". | has(\"$key\")" >/dev/null; then
            errors+=("Missing required key: ${parent_path}${key}")
            valid=false
        fi
    done

    # Validate each property
    for key in $(echo "$properties" | jq -r 'keys[]'); do
        local expected_type
        local actual_type
        local sub_schema
        local value

        expected_type=$(echo "$properties" | jq -r ".\"$key\".type // empty")
        sub_schema=$(echo "$properties" | jq -c ".\"$key\"")
        value=$(echo "$json" | jq -c ".\"$key\"")
        actual_type=$(echo "$json" | jq -r ".\"$key\" | type // empty")

        if [ "$expected_type" = "object" ]; then
            if [ "$actual_type" = "object" ]; then
                validate_json_recursive "$value" "$sub_schema" "${parent_path}${key}."
            else
                errors+=(
                    "Key '${parent_path}${key}' expected type 'object', but got '$actual_type'"
                )
                valid=false
            fi
        elif [ "$expected_type" = "array" ]; then
            if [ "$actual_type" = "array" ]; then
                items_schema=$(echo "$sub_schema" | jq -c '.items')
                array_length=$(echo "$value" | jq 'length')

                for ((i=0; i<array_length; i++)); do
                    element=$(echo "$value" | jq -c ".[$i]")
                    element_type=$(echo "$element" | jq -r 'type')  # Get type of element

                    # Check the expected type for the array items and match with element type
                    item_expected_type=$(echo "$items_schema" | jq -r '.type // empty')

                    # Handle type mismatch in array elements
                    if [ "$item_expected_type" != "$element_type" ]; then
                        preamble="Array element ${parent_path}${key}[$i]"
                        expected_message="expected type '$item_expected_type'"
                        errors+=(
                            "$preamble $expected_message, but got '$element_type'"
                        )
                        valid=false
                    else
                        # Continue validation for each array element recursively
                        validate_json_recursive \
                            "$element" "$items_schema" "${parent_path}${key}[$i]."
                    fi
                done
            else
                errors+=("Key '${parent_path}${key}' expected type 'array', but got '$actual_type'")
                valid=false
            fi
        else
            # Handle specific cases for 'integer', 'string', 'number', etc.
            if [[ "$expected_type" == "integer" && "$actual_type" == "number" ]]; then
                # Check if the value is not an integer (i.e., it has a fractional part)
                if [[ $(echo "$value" | jq '. % 1 != 0') == "true" ]]; then
                    errors+=("Key '${parent_path}${key}' expected type 'integer', but got 'number'")
                    valid=false
                fi
            elif [ "$expected_type" != "$actual_type" ] && [ "$actual_type" != "null" ]; then
                # Handle if expected type does not match the actual type
                # Check if expected_type is an array of types, and if the 
                # actual type matches any of them
                if [[ "$expected_type" =~ \[.*\] ]]; then
                    # Expected type is a list of types (e.g., ["string", "number"])
                    # Remove brackets and spaces
                    expected_types=$(echo "$expected_type" | sed 's/[\[\]" ]//g')  
                    for type in $(echo "$expected_types" | tr ',' '\n'); do
                        if [ "$type" == "$actual_type" ]; then
                            valid=true
                            break
                        fi
                    done
                    
                    key_value="Key '${parent_path}${key}'"
                    if [ "$valid" = false ]; then
                        expected_types="one of the types [${expected_types}]"
                        errors+=("$key_value expected $expected_types, but got '$actual_type'")
                        valid=false
                    fi
                else
                    errors+=("$key_value expected type '$expected_type', but got '$actual_type'")
                    valid=false
                fi
            fi

            # Handle 'null' type
            if [ "$expected_type" = "null" ] && [ "$actual_type" != "null" ]; then
                errors+=("Key '${parent_path}${key}' expected type 'null', but got '$actual_type'")
                valid=false
            fi

            # Handle additional constraints
            handle_constraints "$value" "$sub_schema" "${parent_path}${key}" errors valid
        fi

    done

    # Handle additional properties when additionalProperties is false
    if [ "$additional_properties" = "false" ]; then
        for key in $(echo "$json" | jq -r 'keys[]'); do
            # Check if the key is not present in the properties of the schema
            if ! echo "$properties" | jq -e ". | has(\"$key\")" >/dev/null; then
                key_msg="Key '${parent_path}${key}'"
                errors+=("$key_msg is an extra property, but additionalProperties is false.")
                valid=false
            fi
        done
    fi

    # Print errors if any
    if [ "$valid" = false ]; then
        for error in "${errors[@]}"; do
            echo "$error"
        done
    fi
}


# Function to handle additional constraints
handle_constraints() {
    local value="$1"
    local schema="$2"
    local key_path="$3"
    local -n errors_ref=$4
    local -n valid_ref=$5

    # Pattern (regex matching)
    local pattern=$(echo "$schema" | jq -r '.pattern // empty')
    if [ -n "$pattern" ]; then
        if ! [[ "$value" =~ $pattern ]]; then
            errors_ref+=("Key '${key_path}' does not match the pattern '$pattern'")
            valid_ref=false
        fi
    fi

    # Enum (fixed values)
    local enum_values=$(echo "$schema" | jq -r '.enum // empty')
    if [ "$enum_values" != "null" ]; then
        if ! echo "$enum_values" | jq -e ". | index($value)" >/dev/null; then
            errors_ref+=("Key '${key_path}' value '$value' is not in the enum list: $enum_values")
            valid_ref=false
        fi
    fi

    # MultipleOf (numerical constraint)
    local multiple_of=$(echo "$schema" | jq -r '.multipleOf // empty')
    if [ -n "$multiple_of" ]; then
        if ! (( $(echo "$value % $multiple_of" | bc) == 0 )); then
            errors_ref+=("Key '${key_path}' value '$value' is not a multiple of $multiple_of")
            valid_ref=false
        fi
    fi
}


# Main function to validate a JSON file against a schema
validate_json_from_schema() {
    local json="$1"
    local schema="$2"

    validate_json_recursive "$json" "$schema" ""
}


# Function to handle exit codes and display success or failure messages
handle_exit() {
    local exit_code="$1"
    local current_step="$2" # Current step index (e.g., 3)
    local total_steps="$3"  # Total number of steps (e.g., 4)
    local message="$4"      # Descriptive message for success or failure

    # Validate that current step is less than or equal to total steps
    if [ "$current_step" -gt "$total_steps" ]; then
        warning "Current step ($current_step) exceeds total steps ($total_steps)."
    fi

    local status="success"
    local status_message="$message succeeded"

    if [ "$exit_code" -ne 0 ]; then
        status="error"
        status_message="$message failed"
        error "Error Code: $exit_code"
    fi
    step "$current_step" "$total_steps"  "$status_message" "$status"

    # Exit with failure if there's an error
    if [ "$status" == "error" ]; then
        exit 1
    fi
}

################################# END OF GENERAL UTILITARY FUNCTIONS ###############################

############################### BEGIN OF GENERAL DEPLOYMENT FUNCTIONS ##############################

# Function to check if a stack exists by name
stack_exists() {
    local stack_name="$1"
    # Check if the stack exists by listing stacks and filtering by name
    if docker stack ls --format '{{.Name}}' | grep -q "^$stack_name$"; then
        return 0  # Stack exists
    else
        return 1  # Stack does not exist
    fi
}


# Function to list the services of a stack
list_stack_services() {
    local stack_name=$1
    declare -a services_array

    # Check if stack exists
    if ! docker stack ls --format '{{.Name}}' | grep -q "^$stack_name\$"; then
        error "Stack '$stack_name' does not exist."
        return 1
    fi

    info "Fetching services for stack: $stack_name"

    # Get the services associated with the specified stack and store them in an array
    services_array=($(docker stack services "$stack_name" --format '{{.Name}}'))

    # Optionally return the array as a result (useful if called from another script)
    echo "${services_array[@]}"
}


# Function to list the required fields on a stack docker-compose
list_stack_required_fields() {
    local stack_name="$1"
    local function_name="compose_${stack_name}"

    # Check if the function exists
    if declare -f "$function_name" > /dev/null; then
        # Call the function and extract mustache parameters
        $function_name | grep -oP '\{\{\K[^}]+(?=\}\})' | sort -u
    else
        error "Function $function_name does not exist."
        return 1
    fi
}


# Function to deploy a service using a Docker Compose file
deploy_stack_on_swarm() {
    local stack_name=$1
    local compose_path=$2

    # Ensure Python is installed
    if ! command -v python3 &> /dev/null; then
        error "Python3 is required but not installed. Please install it and try again."
        exit 1
    fi

    # Deploy the service using Docker stack
    docker stack deploy \
        --detach=false --prune --resolve-image always -c "$compose_path" "$stack_name"

    if [ $? -eq 0 ]; then
        success "Stack $stack_name deployed and running successfully."
    else
        error "Stack $stack_name failed to deploy or is not running correctly."
        exit 1
    fi
}


# Function to handle all API requests with enhanced error handling
request() {
    local method="$1"        # HTTP method (GET, POST, DELETE, etc.)
    local url="$2"           # Full API URL
    local token="$3"         # Bearer token
    local content_type="$4"  # Content-Type header (default: application/json)
    local data="$5"          # Optional JSON data for POST/PUT requests

    # Validate required parameters
    if [[ -z "$method" || -z "$url" || -z "$token" ]]; then
        echo "Error: Missing required parameters"
        return 1
    fi

    # Make the API request using curl, capturing both body and HTTP status code
    response=$(curl -k -s -w "%{http_code}" -X "$method" "$url" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: ${content_type:-application/json}" \
        ${data:+-d "$data"})

    # Extract HTTP response code from the response
    http_code="${response: -3}"

    # Extract response body (remove the last 3 characters, which are the HTTP status code)
    response_body="${response%???}"

    # Check if the request was successful (HTTP 2xx response)
    if [[ ! "$http_code" =~ ^2 ]]; then
        echo "Error: API request failed with status code $http_code"
        echo "Response: $response_body"
        return 1
    fi

    # Return the response body if successful
    echo "$response_body"
}


# Function to perform requests on portainer URL
filtered_request() {
    local method="$1"                               # HTTP method (GET, POST, DELETE, etc.)
    local url="$2"                                  # Full API URL or resource
    local token="$3"                                # Bearer token for authentication
    local content_type="${4:-'application/json'}"   # Content-Type (default: application/json)
    local data="${5:-'{}'}"                         # JSON data for POST/PUT requests (optional)
    local filter=${6:-''}                           # Optional jq filter to extract specific output

    # Make the API request
    response=$(request "$method" "$url" "$token" "$content_type" "$data")

    # Apply the jq filter if provided, otherwise return the raw response
    if [[ -n "$filter" ]]; then
        echo "$response" | jq -r "$filter"
    else
        echo "$response"
    fi
}


# Function to build api url
get_api_url(){
    protocol="$1"
    url="$2"
    resource="$3"
    echo "https://$url/api/$resource"
}


is_portainer_credentials_correct() {
    local portainer_url="$1"
    local username="$2"
    local password="$3"

    protocol="https"
    content_type="application/json"
    credentials="{\"username\":\"$username\",\"password\":\"$password\"}"
    resource='auth'

    url="$(get_api_url $protocol $portainer_url $resource)"

    response=$(curl -k -s -X POST -H "Content-Type: $content_type" -d "$credentials" "$url")

    # Check if the response contains a valid token
    token=$(echo "$response" | jq -r .jwt)

    if [[ "$token" == "null" || -z "$token" ]]; then
        echo "Invalid credentials"
        return 1  # Exit with status 1 for failure
    else
        echo "Valid credentials"
        return 0  # Exit with status 0 for success
    fi
}

# Function to retrieve a Portainer authentication token
get_portainer_auth_token() {
    local portainer_url="$1"
    local username="$2"
    local password="$3"

    local max_attempts=3
    local attempts=0

    local token=""

    protocol="https"
    method="POST"
    content_type="application/json"
    credentials="{\"username\":\"$username\",\"password\":\"$password\"}"
    resource='auth'
    jq_filter='.jwt'

    url="$(get_api_url $protocol $portainer_url $resource)"

    while [[ -z "$token" || "$token" == "null" ]]; do
        token=$(\
            curl -k -s \
            -X POST \
            -H "Content-Type: $content_type" \
            -d "$credentials" "$url" | \
            jq -r .jwt \
        )

        ((attempts++))
        if [[ "$attempts" -ge "$max_attempts" ]]; then
            exit 1
        fi
        wait_secs 5
    done

    echo "$token"
}


# Function to retrieve the endpoint ID from Portainer
get_portainer_endpoint_id() {
    local portainer_url="$1"
    local token="$2"

    local endpoint_id
    protocol='https'
    method="GET"
    resource="endpoints"
    content_type="application/json"
    data="{}"
    jq_filter='.[] | select(.Name == "primary") | .Id'

    url="$(get_api_url $protocol $portainer_url $resource)"
    
    endpoint_id=$(\
        filtered_request \
        "$method" "$portainer_url" \ 
        "$token" "$content_type" \
        "$resource" "$data" "$jq_filter" \
    )

    if [[ -z "$endpoint_id" ]]; then
        exit 1
    fi

    echo "$endpoint_id"
}

# Function to retrieve the Swarm ID (used during stack deployment)
get_portainer_swarm_id() {
    local portainer_url="$1"
    local token="$2"
    local endpoint_id="$3"

    protocol='https'
    method="GET"
    resource="endpoints/$endpoint_id/docker/swarm"
    content_type='application/json'
    jq_filter='.ID'

    url="$(get_api_url $protocol $portainer_url $resource)"

    local swarm_id
    swarm_id=$(filtered_request \
        "$method" "$url" \
        "$token" "$content_type" \
        "$resource" "$data" "$jq_filter" \
    )

    if [[ -z "$swarm_id" ]]; then
        error "Failed to retrieve Swarm ID."
        exit 1
    fi

    echo "$swarm_id"
}


# Function to get stacks 
get_portainer_swarm_stacks() {
    local portainer_url="$1"
    local token="$2"

    # Fetch the list of stack names from the Portainer API
    local stacks

    protocol='https'
    method="GET"
    resource="stacks"
    content_type='application/json'
    jq_filter='.ID'

    url="$(get_api_url $protocol $portainer_url $resource)"

    local swarm_id
    stacks=$(filtered_request \
        "$method" "$url" \
        "$token" "$content_type" \
        "$resource" "$data" \
    )

    # Check if any stacks were returned
    if [[ $stacks -eq 0 ]]; then
        echo "No stacks found or failed to retrieve stacks."
        return 1
    fi

    echo "$stacks"
}


# Function to get stacks and check if a specific stack exists
check_portainer_stack_exists() {
    local portainer_url="$1"
    local token="$2"
    local stack_name="$3"

    # Fetch stack names and check if the specified stack exists
    protocol='https'
    method="GET"
    resource="stacks"
    content_type='application/json'
    data='{}'
    jq_query=".[] | select(.Name == \"$stack_name\") | .Id"

    url="$(get_api_url $protocol $portainer_url $resource)"

    # Fetch the stack ID using filtered_request
    local stack_id
    stack_id=$(
        filtered_request \
            "GET" \
            "$(get_api_url 'https' $portainer_url "stacks")" \
            "$token" "application/json" "{}" \
            ".[] | select(.Name == \"$stack_name\") | .Id"
    )

    # Check if stack ID was retrieved
    if [[ -z "$stack_id" ]]; then
        echo ""
        return 1
    fi

    # If stack ID is found, return the ID
    echo "$stack_id"
    return 0
}


# Function to upload a stack
upload_stack_on_portainer() {
    local portainer_url="$1"
    local token="$2"
    local stack_name="$3"
    local compose_file="$4"

    highlight "Uploading stack $stack_name on Portainer $portainer_url"

    # Swarm ID and endpoint id is required for Swarm stack deployments
    local swarm_id

    resource="endpoints"
    jq_query='.[] | select(.Name == "primary") | .Id'
    endpoint_id=$(get_portainer_endpoint_id "$portainer_url" "$token")
    if [[ -z "$endpoint_id" ]]; then
        error "Failed to retrieve Endpoint ID."
        return 1
    fi

    resource="endpoints/$endpoint_id/docker/swarm"
    jq_filter='.ID'
    swarm_id=$(get_portainer_swarm_id "$portainer_url" "$token" "$endpoint_id")
    if [[ -z "$swarm_id" ]]; then
        error "Failed to retrieve Swarm ID."
        return 1
    fi

    # Upload the stack
    info "Uploading stack: ${stack_name}..."
    resource="stacks?type=1&method=string&endpointId=${endpoint_id}"
    
    content_type="application/json"
    data="{
        \"Name\": \"${stack_name}\",
        \"SwarmID\": \"${swarm_id}\",
        \"file\": \"$(<"$compose_file")\"
    }"

    filtered_request "POST" "$portainer_url" "$token" "$content_type" "$data" \
        && success "Stack '$stack_name' uploaded successfully." \
        || error "Failed to upload stack '$stack_name'."

}


# Function to delete a stack
delete_stack_on_portainer() {
    local portainer_url="$1"
    local token="$2"
    local stack_name="$3"

    highlight "Deleting stack '$stack_name' on Portainer $portainer_url"

    # Retrieve stack ID based on the stack name
    info "Retrieving stack ID for '${stack_name}'..."
    local protocol='https'
    local resource="stacks"
    local jq_filter=".[] | select(.Name == \"$stack_name\") | .Id"
    local stack_id

    stack_id=$(check_portainer_stack_exists "$portainer_url" "$token" "$stack_name")

    if [[ -z "$stack_id" ]]; then
        warning "Stack '${stack_name}' not found. Exiting without error."
        return 0
    fi

    # Retrieve Endpoint ID for the stack
    info "Retrieving endpoint ID for stack '${stack_name}'"
    resource="stacks/$stack_id"
    jq_filter=".EndpointId"
    local endpoint_id

    endpoint_id=$(get_portainer_endpoint_id "$portainer_url" "$token")

    if [[ -z "$endpoint_id" ]]; then
        error "Failed to retrieve Endpoint ID for stack '${stack_name}'."
        return 1
    fi

    # Delete the stack
    info "Deleting stack '${stack_name}'"
    resource="stacks/${stack_id}?endpointId=${endpoint_id}"
    url="$(get_api_url $protocol $portainer_url $resource)"

    if filtered_request "DELETE" "$portainer_url" "$token" "application/json"; then
        success "Stack '${stack_name}' deleted successfully."
    else
        error "Failed to delete stack '${stack_name}'."
    fi
}


# Function to display a deploy failed message
deploy_failed_message() {
    stack_name="$1"
    error "Failed to deploy service $stack_name!"
}


# Function to display a deploy success message
deploy_success_message() {
    stack_name="$1"
    success "Successfully deployed stack $stack_name!"
}


# Function to build config and compose files for a service
build_stack_info() {
    local service_name="$1"

    # Build config file
    local config_path="${service_name}_config.json"

    # Build compose file
    local compose_path="${service_name}.yaml"

    # Build compose func name
    local compose_func="compose_${service_name}"

    # Return files
    echo "$config_path $compose_path $compose_func"
}


# Function to replace variables in a template
replace_variables_in_template() {
    local template="$1"
    declare -n variables="$2"  # Associative array passed by reference

    # Use a safe delimiter and avoid external `sed` for portability
    for key in "${!variables[@]}"; do
        value="${variables[$key]}"

        # Replace instances of {{KEY}} in the template
        template="${template//\{\{$key\}\}/$value}"
    done

    # Output the substituted template
    echo "$template"
}


# Function to validate a Docker Compose file
validate_compose_file() {
    local compose_file="$1"

    # Check if the file exists
    if [ ! -f "$compose_file" ]; then
        error "File '$compose_file' not found."
        exit 1
    fi

    # Validate the syntax of the Docker Compose file
    docker compose -f "$compose_file" config > /dev/null 2>&1

    local EXIT_CODE=$?
    return $EXIT_CODE
}


# Function to write JSON content to a file atomically
write_json() {
    local file_path="$1"
    local json_content="$2"

    # Validate the JSON content
    echo "$json_content" | jq . >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Error: Invalid JSON content. Aborting save."
        return 1
    fi
    echo "$json_content"
    # Write the JSON content to the specified file using a temporary file for safety
    local temp_file=$(mktemp)
    echo "$json_content" >"$temp_file" && mv "$temp_file" "$file_path"

    return 0
}


# Function to check for cycles in service dependencies
check_dependency_cycles() {
    local service_config_file=$1

    # Validate that the configuration file exists
    if [[ ! -f "$service_config_file" ]]; then
        error "Configuration file '$service_config_file' not found." $HAS_TIMESTAMP
        exit 1
    fi

    # Extract service name and dependencies
    local service_name=$(jq -r '.service_name' "$service_config_file")
    local dependencies=$(jq -r '.dependencies // {} | keys | .[]' "$service_config_file")

    # If no dependencies exist, the service has no cycles
    if [[ -z "$dependencies" ]]; then
        success "No dependencies found for $service_name. No cycles detected." $HAS_TIMESTAMP
        return
    fi

    # Use an associative array (visited) to track visited nodes
    declare -A visited

    # Function to recursively check dependencies
    local cycle_detected=0
    detect_cycle() {
        local current_service=$1
        local current_config_file=$2

        # Check if the service is already being visited (cycle detected)
        if [[ ${visited["$current_service"]} == "in_progress" ]]; then
            error "Error: Cycle detected involving '$current_service'." $HAS_TIMESTAMP
            cycle_detected=1
            return
        elif [[ ${visited["$current_service"]} == "visited" ]]; then
            return
        fi

        # Mark the current service as in progress
        visited["$current_service"]="in_progress"

        # Get dependencies of the current service
        if [[ -f "$current_config_file" ]]; then
            local child_dependencies=$(\
                jq -r \
                '.dependencies // {} | keys | .[]' \
                "$current_config_file"
            )

            for dependency in $child_dependencies; do
                # Get the dependency's configuration file
                local dependency_config_file="${dependency}_config.json"

                # Check for the dependency config file existence
                if [[ ! -f "$dependency_config_file" ]]; then
                    message="Configuration file for dependency '$dependency' not found. Skipping."
                    warning $message $HAS_TIMESTAMP
                    continue
                fi

                detect_cycle "$dependency" "$dependency_config_file"
                if [[ $cycle_detected -eq 1 ]]; then
                    return
                fi
            done
        fi

        # Mark the current service as visited
        visited["$current_service"]="visited"
    }

    # Start cycle detection from the given service
    detect_cycle "$service_name" "$service_config_file"

    if [[ $cycle_detected -eq 0 ]]; then
        success "No cycles detected in the dependencies of $service_name." $HAS_TIMESTAMP
    else
        error "Cycles detected. Dependency structure is invalid." $HAS_TIMESTAMP
        exit 1
    fi
}


# Function to convert an associative array to JSON
convert_array_to_json() {
    local -n array_ref=$1  # Reference to the associative array
    local json="{"

    # Iterate over array keys and values
    for key in "${!array_ref[@]}"; do
        # Escape key and value and add them to the JSON object
        json+="\"$key\":\"${array_ref[$key]}\","
    done

    # Remove the trailing comma and close the JSON object
    json="${json%,}}"

    echo "$json"
}


# Save an associative array to a JSON file
save_array_to_json() {
    local file_path="$1"  # File path to save the JSON data
    shift                 # Remove the first argument, leaving only the associative array parameters

    # Declare the associative array and populate it
    declare -A input_array
    while [[ $# -gt 0 ]]; do
        key="$1"
        value="$2"
        input_array["$key"]="$value"
        shift 2  # Move to the next key-value pair
    done

    # Convert the associative array to JSON
    local json_content
    json_content=$(convert_array_to_json input_array)

    # Save the JSON content to the specified file
    write_json "$file_path" "$json_content"
}


# Function to retrieve a value from a JSON file
read_json_key() {
    local json_data="$1"
    local key="$2"
    local default_value="$3"

    # Extract the value using jq
    local value
    value=$(echo "$json_data" | jq -r "$key")

    # If the value is not null or empty, return it, otherwise return the default value
    if [ -n "$value" ] && [ "$value" != "null" ]; then
        echo "$value"
    else
        echo "$default_value"
    fi
}


# Function to clean docker environment
sanitize() {
  # Prune unused containers, networks, volumes, and build cache
  docker system prune --all --volumes -f

  # Remove any dangling (untagged) images
  docker images --filter "dangling=true" -q | xargs -r docker rmi -f

  # Optional: Remove stopped containers, if any remain (for extra cleanup)
  docker container prune -f

  # Optional: Remove unused Docker networks
  docker network prune -f

  # Optional: Remove orphaned volumes (if system prune misses any)
  docker volume prune -f
}


# Function to create a Docker network if it doesn't exist
create_network_if_not_exists() {
    local network_name="${1:-$DEFAULT_NETWORK}"

    # Check if the network already exists
    if ! docker network ls --format '{{.Name}}' | grep -wq "$network_name"; then
        echo "Creating network: $network_name"

        # Create the overlay network
        if docker network create --driver overlay "$network_name"; then
            echo "Network $network_name created successfully."
        else
            echo "Error: Failed to create network $network_name."
            return 1  # Exit with error status if network creation fails
        fi
    else
        echo "Network $network_name already exists."
    fi
}


# Function to execute a setUp action
execute_set_up_action() {
    local action="$1"  # JSON object representing the setUp action

    # Extract the name, command, and variables from the action
    local action_name
    action_name=$(echo "$action" | jq -r '.name')

    local action_command
    action_command=$(echo "$action" | jq -r '.command')

    # Extract variables if they exist (empty string if not defined)
    local action_variables
    action_variables=$(echo "$action" | jq -r '.variables // empty')

    # If there are variables, export them for the command execution
    if [ -n "$action_variables" ]; then
        # Export each variable safely, ensuring no unintended command execution
        for var in $(echo "$action_variables" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"'); do
            # Escape and export the variable
            local var_name=$(echo "$var" | cut -d'=' -f1)
            local var_value=$(echo "$var" | cut -d'=' -f2)
            export "$var_name"="$var_value"
        done
    fi

    # Safely format the command using printf to avoid eval
    # Substitute the variables in the command
    local formatted_command
    formatted_command=$(printf "%s" "$action_command")

    # Execute the formatted command
    bash -c "$formatted_command"

    # Check if the command executed successfully and handle exit
    local exit_code=$?
}


# Load service configuration from a Docker-Compose stack or a running container
load_stack_config() {
    local stack_name="$1"
    local config_file="${stack_name}_config.json"
    local service_ip
    local config_output

    # Check if configuration file exists first
    if [[ -f "$config_file" ]]; then
        config_output=$(cat "$config_file")
    else
        # Attempt to retrieve service information from docker-compose stack if defined
        service_ip=$(
            docker-compose ps -q "$stack_name" 2>/dev/null | \
            xargs docker inspect \
            --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null
        )

        if [[ -n "$service_ip" ]]; then
            debug "Retrieved IP from docker-compose for service '$stack_name': $service_ip"
            config_output=$(generate_service_config_json "$stack_name" "$service_ip")
        else
            # Fallback: Attempt to retrieve IP from running container if not part of stack
            service_ip=$(\
                docker inspect \
                --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
                "$stack_name" 2>/dev/null
            )

            if [[ -n "$service_ip" ]]; then
                debug "Retrieved IP from running container for service '$stack_name': $service_ip"
                config_output=$(generate_service_config_json "$stack_name" "$service_ip")
            else
                # If all methods fail, return an empty configuration
                warning "Unable to retrieve configuration for service '$stack_name'."
                config_output="{}"
            fi
        fi
    fi

    # Ensure valid JSON by passing it through jq
    if ! echo "$config_output" | jq . >/dev/null 2>&1; then
        warning "Invalid JSON in the service configuration for '$stack_name'. Returning empty JSON."
        echo "{}"
    else
        # Return the valid JSON
        echo "$config_output"
    fi
}


# Helper function to load service configuration and exit if missing
load_or_fail_stack_config() {
    local stack_name="$1"
    local config
    config=$(load_stack_config "$stack_name")

    if [[ "$config" == "{}" ]]; then
        critical "Missing configuration for stack '$stack_name'. Exiting."
        exit 1
    fi

    echo "$config"
}


generate_config_schema() {
    local required_fields="$1"
    
    # Start the JSON schema structure
    local schema="{\"variables\": {"
    
    # Generate properties for each required field
    local first=true
    for field in $required_fields; do
        if [ "$first" = true ]; then
            first=false
        else
            schema+=","
        fi
        schema+="\"$field\": {\"type\": \"string\"}"
    done

    # Add dependencies and setUp as always-present fields
    schema+='},
    "dependencies": {},
    "setUp": []}'

    echo "$schema"
}


# Example function to extract required fields and generate schema
validate_stack_config() {
    local config_json="$1"
    local stack_name="$2"  # Add stack_name as an argument to the function

    # Get required fields from the stack template
    required_fields=$(list_stack_required_fields "$stack_name")

    # Generate the JSON schema
    schema=$(generate_config_schema "$required_fields")

    # Step 5: Validate if the provided JSON has all required variables
    validate_json_from_schema "$config_json" "$schema"
}


# Function to deploy a service
build_and_deploy_stack() {
    # Arguments
    local stack_name="$1"   # Service name (e.g., redis, postgres)
    local stack_json="$2"   # JSON data with service variables

    total_steps=7

    # Declare an associative array to hold service variables
    declare -A stack_variables

    # Parse JSON data and populate associative array
    while IFS="=" read -r key value; do
        stack_variables["$key"]="$value"
    done < <(echo "$service_json" | jq -r '.variables | to_entries | .[] | "\(.key)=\(.value)"')

    highlight "Deploying stack $stack_variables" $HAS_TIMESTAMP

    # Step 1: Deploy Dependencies
    step 1 $total_steps \
        "[$stack_variables] Checking and deploying dependencies" "info"
    local dependencies
    dependencies=$(echo "$stack_json" | jq -r '.dependencies[]?')

    # Check if there are dependencies, and if none, display a message
    if [ -z "$dependencies" ]; then
        step 1 $total_steps "[$stack_variables] No dependencies to deploy" "warning"
    else
        for dep in $dependencies; do
            step 1 $total_steps "[$stack_variables] Deploying dependency: $dep" "info"

            # Fetch JSON for the dependency
            local dep_service_json
            dep_stack_json=$(fetch_service_json "$dep")

            deploy_stack "$dep" "$dep_stack_json"
            handle_exit "$?" 1 $total_steps "Deploying dependency $dep"
        done
    fi

    # Step 2: Execute setUp actions (if defined in the service JSON)
    step 2 7 "[$stack_variables] Executing setUp actions" "info"
    local setUp_actions
    setUp_actions=$(echo "$service_json" | jq -r '.setUp[]?')

    # Debug: Check if jq returned an error
    if [[ $? -ne 0 ]]; then
        step 2 $total_steps "[$service_name] Error parsing setUp actions: $setUp_actions" "error"
        exit 1
    fi

    if [ -n "$setUp_actions" ]; then
        # Iterate through each action, preserving newlines for better debugging
        IFS=$'\n' read -d '' -r -a actions_array <<< "$setUp_actions"
        
        for action in "${actions_array[@]}"; do
            # Perform the action (you can define custom functions to execute these steps)
            step 2 $total_steps "[$service_name] Running setUp action: $action" "info"
            
            # Call an appropriate function to handle this setUp action
            execute_set_up_action "$action"
            handle_exit $? 2 $total_steps "Executing setUp action $action"
        done
    else
        step 2 7 "[$stack_name] No setUp actions defined" "warning"
    fi

    # Step 3: Build service-related file paths and Docker Compose template
    step 3 7 "[$stack_name] Building file paths" "info"
    stack_info="$(build_stack_info "$stack_name")"
    local config_path=$(echo "$stack_info" | awk '{print $1}')
    local compose_filepath=$(echo "$stack_info" | awk '{print $2}')
    local compose_template_func=$(echo "$stack_info" | awk '{print $3}')

    step 3 $total_steps "[$stack_name] File paths built" "success"

    # Retrieve and substitute variables in Docker Compose template
    step 4 $total_steps "[$stack_name] Creating Docker Compose template" "info"
    local template=$($compose_template_func)
    local substituted_template
    substituted_template=$(replace_variables_in_template "$template" service_variables)

    step 3 $total_steps "[$stack_name] Docker Compose template created" "success"

    # Write the substituted template to the compose file
    step 4 $total_steps "[$stack_name] Writing Docker Compose template" "info"

    compose_path="$(pwd)/$compose_filepath"
    echo "$substituted_template" > "$compose_path"
    handle_exit $? 4 $total_steps "[$stack_name] Writing file $compose_filepath"

    # Step 5: Validate the Docker Compose file
    step 5 $total_steps "[$stack_name] Validating Docker Compose file" "info"
    validate_compose_file "$compose_path"
    handle_exit $? 5 $total_steps "[$stack_name] Validating Docker Compose file $compose_path"

    # Step 6: Deploy the service on Docker Swarm
    step 6 $total_steps "[$stack_name] Deploying service on Docker Swarm" "info"
    deploy_stack_on_swarm "$stack_name" "$compose_filepath"
    handle_exit $? 6 $total_steps "Deploying stack $stack_name"

    # Step 7: Save service-specific information to a configuration file
    step 7 $total_steps "[$service_name] Saving stack configuration" "info"
    write_json "$config_path" "$stack_json"
    handle_exit $? 7 $total_steps "Saving information for stack $service_name"

    # Final Success Message
    deploy_success_message "$stack_name"
}

################################ END OF GENERAL DEPLOYMENT FUNCTIONS ###############################


################################ BEGIN OF STACK DEPLOYMENT FUNCTIONS ###############################

# Function to get the password from a JSON file
get_postgres_password() {
    local config_file=$1
    password_postgres=$(jq -r '.password' $config_file)
    echo "$password_postgres"
}

# Function to create a PostgreSQL database
create_postgres_database() {
    local db_name="$1"
    local db_user="${2:-postgres}"
    local container_name="${3:-postgres_db}"

    local container_id
    local db_exists

    # Display a message about the database creation attempt
    info "Creating PostgreSQL database: $db_name in container: $container_name"

    # Check if the container is running
    container_id=$(docker ps -q --filter "name=^${container_name}$")
    if [ -z "$container_id" ]; then
        error "Container '${container_name}' is not running. Cannot create database."
        return 1
    fi

    # Check if the database already exists
    db_exists=$(docker exec \
    "$container_id" psql -U "$db_user" -lqt | cut -d \| -f 1 | grep -qw "$db_name")
    if [ "$db_exists" ]; then
        info "Database '$db_name' already exists. Skipping creation."
        return 0
    fi

    # Create the database if it doesn't exist
    info "Creating database '$db_name'..."
    if docker exec "$container_id" \
        psql -U "$db_user" -c "CREATE DATABASE \"$db_name\";" > /dev/null 2>&1; then
        success "Database '$db_name' created successfully."
        return 0
    else
        error "Failed to create database '$db_name'. Please check the logs for details."
        return 1
    fi
}


generate_set_up_actions_n8n() {
    local n8n_config_json=$1
    local n8n_instance_id=$2  # New parameter for the n8n instance identifier
    local postgres_db=$(echo "$n8n_config_json" | \
        jq -r '.variables.DB_NAME')
    local postgres_user=$(echo "$n8n_config_json" | \
        jq -r '.dependencies.postgres.variables.DB_USER')
    local postgres_container=$(echo "$n8n_config_json" | \
        jq -r '.dependencies.postgres.variables.CONTAINER_NAME')

    # Escape the variables to prevent issues with special characters
    local escaped_postgres_db
    local escaped_postgres_user
    local escaped_postgres_container

    escaped_postgres_db=$(printf '%q' "$postgres_db")
    escaped_postgres_user=$(printf '%q' "$postgres_user")
    escaped_postgres_container=$(printf '%q' "$postgres_container")

    # Ensure the database name is unique based on the instance ID to prevent conflicts
    local unique_postgres_db="${escaped_postgres_db}_${n8n_instance_id}"

    jq -n \
        --arg POSTGRES_DB "$unique_postgres_db" \
        --arg POSTGRES_USER "$escaped_postgres_user" \
        --arg POSTGRES_CONTAINER "$escaped_postgres_container" \
        --arg INSTANCE_ID "$n8n_instance_id" \
        '{
            "actions": [
                {
                    "name": "Create Postgres Database",
                    "command": "create_postgres_database \($POSTGRES_DB) \($POSTGRES_USER) \($POSTGRES_CONTAINER)",
                    "variables": {
                        "POSTGRES_DB": $POSTGRES_DB,
                        "POSTGRES_USER": $POSTGRES_USER,
                        "POSTGRES_CONTAINER": $POSTGRES_CONTAINER,
                        "INSTANCE_ID": $INSTANCE_ID
                    }
                }
            ]
        }'
}


################################## BEGIN OF CONFIGURATION VARIABLE #################################

# Function to generate configuration files for traefik
generate_config_traefik(){
    local stack_name="traefik" # Default service name

    # Ensure everything is quoted correctly
    jq -n \
        --arg STACK_NAME "$stack_name" \
        --arg EMAIL_SSL $email_ssl, \
        --arg VOLUME_NAME "${service_name}_data" \
        --arg NETWORK_NAME "$network_name" \
        '{
            "name": $STACK_NAME,
            "variables": {
                "EMAIL_SSL": $EMAIL_SSL,
                "VOLUME_NAME": $VOLUME_NAME,
                "NETWORK_NAME": $NETWORK_NAME,
            },
            "dependencies": {},
            "setUp": []
        }'
}


# Function to generate configuration files for portainer
generate_config_portainer(){
    local stack_name="portainer"                # Default service name
    local image_version="${1:-"latest"}"        # Accept image version or default to 14
    local network_name="${2:-DEFAULT_NETWORK}"
    
    # Ensure everything is quoted correctly
    jq -n \
        --arg STACK_NAME "$stack_name" \
        --arg IMAGE_NAME "${service_name}_$image_version" \
        --arg IMAGE_VERSION "$image_version" \
        --arg VOLUME_NAME "${service_name}_data" \
        --arg NETWORK_NAME "$network_name" \
        '{
            "variables": {
                "STACK_NAME": $STACK_NAME,
                "IMAGE_NAME": $IMAGE_NAME,
                "IMAGE_VERSION": $IMAGE_VERSION,
                "CONTAINER_NAME": $CONTAINER_NAME,
                "CONTAINER_PORT": $CONTAINER_PORT,
                "VOLUME_NAME": $VOLUME_NAME,
                "NETWORK_NAME": $NETWORK_NAME,
                "DB_USER": $DB_USER,
                "DB_PASSWORD": $DB_PASSWORD
            },
            "dependencies": {},
            "setUp": []
        }'
}

# Function to generate configuration files for redis
generate_config_redis() {
    local stack_name = 'redis'
    local image_version="${1:-"latest"}"   # Accept image version or default to 6.2.5
    local container_port="${2:-6379}"      # Accept container port or default to 6379
    local network_name="${3:-$DEFAULT_NETWORK}"  # Accept network or default to default_network

    jq -n \
        --arg STACK_NAME "$stack_name" \
        --arg IMAGE_NAME "$stack_name_$image_version" \
        --arg IMAGE_VERSION "$image_version" \
        --arg CONTAINER_NAME "$stack_name" \
        --arg CONTAINER_PORT "$container_port" \
        --arg SERVICE_URL "$stack_name://$stack_name:$container_port" \
        --arg VOLUME_NAME "$stack_name_data" \
        --arg NETWORK_NAME "$network_name" \
        '{
            "name": $STACK_NAME,
            "variables": {
                "IMAGE_NAME": $IMAGE_NAME,
                "IMAGE_VERSION": $IMAGE_VERSION,
                "CONTAINER_NAME": $CONTAINER_NAME,
                "CONTAINER_PORT": $CONTAINER_PORT,
                "SERVICE_URL": $SERVICE_URL,
                "VOLUME_NAME": $VOLUME_NAME,
                "NETWORK_NAME": $NETWORK_NAME
            },
            "dependencies": {},
            "setUp": []
        }'
}


# Function to generate Postgres service configuration JSON
generate_config_postgres() {
    local stack_name="postgres"                 # Default service name
    local image_version="${1:-"14"}"            # Accept image version or default to 14
    local container_port="${2:-5432}"           # Accept container port or default to 5432
    
    local postgres_user="postgres"
    local postgres_password="$(random_string)"

    # Ensure everything is quoted correctly
    jq -n \
        --arg STACK_NAME "$stack_name" \
        --arg IMAGE_NAME "${stack_name}_$image_version" \
        --arg IMAGE_VERSION "$image_version" \
        --arg CONTAINER_NAME "$service_name" \
        --arg CONTAINER_PORT "$container_port" \
        --arg DB_USER "$postgres_user" \
        --arg DB_PASSWORD "$postgres_password" \
        --arg VOLUME_NAME "${service_name}_data" \
        --arg NETWORK_NAME "$network_name" \
        '{
            "name": $STACK_NAME,
            "variables": {
                "STACK_NAME": $STACK_NAME,
                "IMAGE_NAME": $IMAGE_NAME,
                "IMAGE_VERSION": $IMAGE_VERSION,
                "CONTAINER_NAME": $CONTAINER_NAME,
                "CONTAINER_PORT": $CONTAINER_PORT,
                "VOLUME_NAME": $VOLUME_NAME,
                "NETWORK_NAME": $NETWORK_NAME,
                "DB_USER": $DB_USER,
                "DB_PASSWORD": $DB_PASSWORD
            },
            "dependencies": {},
            "setUp": []
        }'
}


# Function to generate n8n config
generate_config_n8n() {
    local identifier="$1"
    local stack_name="n8n"
    local instance_label="${stack_name}_${identifier}"
    local image_version="${2:-latest}"                   # Default to latest
    local container_port="${3:-5678}"                    # Default to 5678
    local protocol = "${4:-http}"                        # Default to http
    local editor_url = "$5"                              # Default to EDITOR_URL
    local webhook_url = "$6"                             # Default to WEBHOOK_URL
    local network_name="${7:-$DEFAULT_NETWORK}"          # Default to default_network

    # Load Redis and Postgres configs
    local redis_config
    redis_config=$(load_or_fail_stack_config "redis")
    redis_json=$(printf "%s" "$redis_config" | jq -e . 2>/dev/null || echo "{}")

    local postgres_config
    postgres_config=$(load_or_fail_service_config "postgres")    
    postgres_json=$(printf "%s" "$postgres_config" | jq -e . 2>/dev/null || echo "{}")

    # Generate the n8n configuration JSON
    local n8n_config_json
    n8n_config_json=$(jq -n \
        --arg INSTANCE_LABEL "$this_stack_name" \
        --arg IMAGE_NAME "${service_name}_$image_version" \
        --arg CONTAINER_PORT "$editor_port" \
        --arg EDITOR_URL "$protocol://$webhook_url" \
        --arg WEBHOOK_URL "$protocol://$editor_url" \
        --arg VOLUME_NAME "${service_name}_data" \
        --arg DB_NAME "${this_service_name}_queue" \
        --arg NETWORK_NAME "$network_name" \
        --argjson REDIS_CONFIG "$redis_json" \
        --argjson POSTGRES_CONFIG "$postgres_json" \
        '{
            "variables": {
                "STACK_LABEL": $SERVICE_NAME,
                "INSTANCE_ID": $INSTANCE_ID,
                "IMAGE_NAME": $IMAGE_NAME,
                "CONTAINER_PORT": $CONTAINER_PORT,
                "SERVICE_URL": $SERVICE_URL,
                "VOLUME_NAME": $VOLUME_NAME,
                "PROTOCOL": 'http',
                "NETWORK_NAME": $NETWORK_NAME,
                "DB_NAME": $DB_NAME,
            },
            "dependencies": {
                "redis": $REDIS_CONFIG,
                "postgres": $POSTGRES_CONFIG
            }
        }'  
    )

    # Generate and inject setUp actions dynamically
    local setUp_actions
    setUp_actions=$(generate_set_up_actions_n8n "$n8n_config_json")

    # Check if setUp_actions is valid JSON
    if ! echo "$setUp_actions" | jq empty >/dev/null 2>&1; then
        critical "Invalid setUp actions generated. Exiting."
        exit 1
    fi

    # Combine the main config with setUp actions
    local final_config
    final_config=$(\
        echo "$n8n_config_json" | \
        jq --argjson SETUP_ACTIONS "$setUp_actions" \
        '. + { "setUp": $SETUP_ACTIONS }'\
    )

    echo "$final_config"
}


################################### END OF CONFIGURATION VARIABLE ##################################


####################################### BEGIN OF COMPOSE FILES #####################################

compose_traefik() {
    cat <<EOL
services:

  traefik:
    image: traefik:v2.11.2
    command:
      - "--api.dashboard=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network={{NETWORK_NAME}}"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.transport.respondingTimeouts.idleTimeout=3600"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencryptresolver.acme.email={{EMAIL_SSL}}"
      - "--log.level=DEBUG"
      - "--log.format=common"
      - "--log.filePath=/var/log/traefik/traefik.log"
      - "--accesslog=true"
      - "--accesslog.filepath=/var/log/traefik/access-log"

    volumes:
      - "vol_certificates:/etc/traefik/letsencrypt"
      - "/var/run/docker.sock:/var/run/docker.sock:ro"

    networks:
      - {{NETWORK_NAME}}

    ports:
      - target: 80
        published: 80
        mode: host
      - target: 443
        published: 443
        mode: host

    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.middlewares.redirect-https.redirectscheme.scheme=https"
        - "traefik.http.middlewares.redirect-https.redirectscheme.permanent=true"
        - "traefik.http.routers.http-catchall.rule=Host(\`{host:.+}\`)"
        - "traefik.http.routers.http-catchall.entrypoints=web"
        - "traefik.http.routers.http-catchall.middlewares=redirect-https@docker"
        - "traefik.http.routers.http-catchall.priority=1"


volumes:
  vol_shared:
    external: true
    name: volume_swarm_shared
  vol_certificates:
    external: true
    name: volume_swarm_certificates

networks:
  {{NETWORK_NAME}}:
    external: true
    attachable: true
    name: {{NETWORK_NAME}}
EOL
}


compose_portainer() {
    cat <<EOL
services:

  agent:
    image: portainer/agent:{{AGENT_VERSION}} ## Versão Agent do Portainer

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes

    networks:
      - {{NETWORK_NAME}}

    deploy:
      mode: global
      placement:
        constraints: [node.platform.os == linux]

  portainer:
    image: portainer/portainer-ce:{{PORTAINER_VERSION}} 
    command: -H tcp://tasks.agent:9001 --tlsskipverify

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - {{VOLUME_NAME}}:/data

    networks:
      - {{NETWORK_NAME}} ## Nome da rede interna

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.portainer.rule=Host(\`{{PORTAINER_URL}}\`)"
        - "traefik.http.services.portainer.loadbalancer.server.port=9000"
        - "traefik.http.routers.portainer.tls.certresolver=letsencryptresolver"
        - "traefik.http.routers.portainer.service=portainer"
        - "traefik.docker.network={{NETWORK_NAME}}" ## Nome da rede interna
        - "traefik.http.routers.portainer.entrypoints=websecure"
        - "traefik.http.routers.portainer.priority=1"


volumes:
  {{VOLUME_NAME}}:
    external: true
    name: {{VOLUME_NAME}}
networks:
  {{NETWORK_NAME}}:
    external: true
    attachable: true
    name: {{NETWORK_NAME}}
EOL
}


# Function to create the Redis YAML file
compose_redis() {
    cat <<EOL
services:
  redis:
    image: redis:{{IMAGE_VERSION}}
    command: [
        "redis-server",
        "--appendonly",
        "yes",
        "--port",
        "{{CONTAINER_PORT}}"
    ]
    volumes:
      - {{VOLUME_NAME}}:/data
    networks:
      - {{NETWORK_NAME}}

volumes:
  {{VOLUME_NAME}}:
    external: true
    name: {{VOLUME_NAME}}

networks:
  {{NETWORK_NAME}}:
    external: true
    name: {{NETWORK_NAME}}
EOL
}


# Function to create the Postgres YAML file
compose_postgres() {
    cat <<EOL
services:
  postgres:
    image: postgres:{{IMAGE_VERSION}}
    environment:
      - POSTGRES_PASSWORD={{DB_PASSWORD}}
      - PG_MAX_CONNECTIONS=500
    ## Uncomment the following line to use a custom configuration file
    # ports:
    #   - {{CONTAINER_PORT}}:5432
    volumes:
      - {{VOLUME_NAME}}:/var/lib/postgresql/data
    networks:
      - {{NETWORK_NAME}}

volumes:
  {{VOLUME_NAME}}:
    external: true

networks:
  {{NETWORK_NAME}}:
    external: true
    name: {{NETWORK_NAME}}
EOL
}


# Function to create the N8N YAML file
compose_n8n() {
  cat <<EOL
version: '3.8'

# Common environment variables definition
x-common-env: &common-env
  DB_TYPE: postgresdb
  DB_POSTGRESDB_DATABASE: {{DB_NAME}}
  DB_POSTGRESDB_HOST: {{DB_HOST}}
  DB_POSTGRESDB_PORT: {{DB_PORT}}
  DB_POSTGRESDB_USER: {{DB_USER}}
  DB_POSTGRESDB_PASSWORD: {{DB_PASSWORD}}
  N8N_ENCRYPTION_KEY: {{ENCRYPTION_KEY}}
  N8N_HOST: {{EDITOR_HOST}}
  N8N_EDITOR_BASE_URL: {{PROTOCOL}}://{{EDITOR_HOST}}/
  WEBHOOK_URL: {{PROTOCOL}}://{{WEBHOOK_HOST}}/
  N8N_PROTOCOL: {{PROTOCOL}}
  NODE_ENV: production
  EXECUTIONS_MODE: queue

# Common service dependencies definition
x-common-depends-on: &common-depends-on
  redis:
    condition: service_healthy
  database:
    condition: service_healthy

# Global Deploy Configuration for All Services
x-common-deploy: &common-deploy
  mode: replicated
  replicas: {{REPLICAS}}
  placement:
    constraints:
      - node.role == manager
  resources:
    limits:
      cpus: "1"
      memory: 1024M

services:
  # Editor service
  {{INSTANCE_LABEL}}_editor:
    image: n8nio/n8n:{{IMAGE_VERSION}}
    command: start
    environment:
      <<: *common-env
      N8N_SMTP_SENDER: {{SMTP_SENDER}}
      N8N_SMTP_USER: {{SMTP_USER}}
    depends_on: *common-depends-on
    deploy: *common-deploy
    labels:
      - traefik.enable=true
      - traefik.http.routers.{{INSTANCE_LABEL}}_editor.rule=Host(\`{{EDITOR_HOST}}\`)
      - traefik.http.routers.{{INSTANCE_LABEL}}_editor.entrypoints=websecure
      - traefik.http.routers.{{INSTANCE_LABEL}}_editor.tls.certresolver=letsencryptresolver
      - traefik.http.services.{{INSTANCE_LABEL}}_editor.loadbalancer.server.port=5678

  # Webhook service
  webhook:
    image: n8nio/n8n:{{IMAGE_VERSION}}
    command: webhook
    environment: *common-env
    depends_on: *common-depends-on
    deploy: *common-deploy
    labels:
      - traefik.enable=true
      - traefik.http.routers.{{INSTANCE_LABEL}}_webhook.rule=Host(\`{{WEBHOOK_HOST}}\`)
      - traefik.http.routers.{{INSTANCE_LABEL}}_webhook.entrypoints=websecure
      - traefik.http.routers.{{INSTANCE_LABEL}}_webhook.tls.certresolver=letsencryptresolver
      - traefik.http.services.{{INSTANCE_LABEL}}_webhook.loadbalancer.server.port=5678

  # Worker service
  worker:
    image: n8nio/n8n:{{IMAGE_VERSION}}
    command: worker --concurrency=10
    environment: *common-env
    depends_on: *common-depends-on
    deploy: *common-deploy

networks:
  {{NETWORK_NAME}}:
    external: true
    name: {{NETWORK_NAME}}
EOL
}

######################################## END OF COMPOSE FILES ######################################

################################ BEGIN OF STACK DEPLOYMENT FUNCTIONS ###############################

# Function to deploy a traefik service
deploy_stack_traefik(){
    local stack_name='traefik'
    local network_name="${2:-$DEFAULT_NETWORK}"

    # Generate the n8n service JSON configuration using the helper function
    local config_json
    config_json=$(generate_config_traefik)

    # Check required fields
    validate_stack_config "$stack_name" "$config_json"

    # Deploy the n8n service using the JSON
    build_and_deploy_stack "$stack_name" "$config_json"
}


# Function to deploy a portainer service
deploy_stack_portainer(){
    local stack_name='portainer'
    local network_name="${2:-$DEFAULT_NETWORK}"

    # Generate the n8n service JSON configuration using the helper function
    local config_json
    config_json="$(generate_config_portainer)"

    # Check required fields
    validate_stack_config "$stack_name" "$config_json"

    # Deploy the n8n service using the JSON
    build_and_deploy_stack "$stack_name" "$config_json"
}


# Function to deploy a PostgreSQL stack
deploy_stack_postgres() {
    local stack_name='postgres'
    local image_version="${1:-"14"}"              # Accept image version or default to 14
    local container_port="${2:-5432}"             # Accept container port or default to 5432
    local network_name="${3:-$DEFAULT_NETWORK}"   # Accept network or default to DEFAULT_NETWORK

    # Create a JSON object to pass as an argument
    local config_json
    config_json=$(generate_config_postgres "$image_version" "$container_port" "$network_name")

    # Check required fields
    validate_stack_config "$stack_name" "$config_json"

    # Deploy the PostgreSQL service using the JSON
    build_and_deploy_stack "$stack_name" "$config_json"
}


# Function to deploy a Redis service
deploy_stack_redis() {
    local stack_name='redis'
    local image_version="${1:-"6.2.5"}"   # Accept image version or default to 6.2.5
    local container_port="${2:-6379}"      # Accept container port or default to 6379
    local network_name="${3:-$DEFAULT_NETWORK}"  # Accept network or default to DEFAULT_NETWORK

    # Generate the Redis service JSON configuration using the helper function
    local redis_config_json
    config_json=$(generate_config_redis "$image_version" "$container_port" "$network_name")

    # Check required fields
    validate_stack_config "$stack_name" "$config_json"

    # Deploy the Redis service using the JSON
    build_and_deploy_stack "$stack_name" "$config_json"    
}


# Function to deploy a n8n service
deploy_stack_n8n() {
    local stack_name='n8n'
    local network_name="${2:-$DEFAULT_NETWORK}"

    # Prompt the user to provide an identifier if not passed as an argument
    if [[ -z "$1" ]]; then
        read -p "Enter an identifier for the n8n service: " identifier
    else
        identifier="$1"
    fi

    local augmented_stack_name="${stack_name}_$identifier"

    # Generate the n8n service JSON configuration using the helper function
    local n8n_config_json
    n8n_config_json=$(generate_config_n8n "$identifier")

    # Check required fields
    validate_stack_config "$stack_name" "$config_json"

    # Deploy the n8n service using the JSON
    build_and_deploy_stack "$augmented_stack_name" "$n8n_config_json"

    important "You must create the login and password in the first access of the N8N"
}

######################################## END OF COMPOSE FILES ######################################

###################################### BEGIN OF SETUP FUNCTIONS ####################################

# Function to prepare the environment
update_and_install_packages() {
    # Function constants
    local total_steps = 2

    highlight "Preparing environment"

    # Check if the script is running as root
    if [ "$EUID" -ne 0 ]; then
        error "Please run this script as root or use sudo."
        exit 1
    fi
    
    step_message="Updating system and upgrading packages"
    step 1 $total_steps $step_message "info"

    # Update the system, fix broken installs, and upgrade packages, suppressing output
    DEBIAN_FRONTEND=noninteractive apt update -yq > /dev/null 2>&1
    update_status=$?
    DEBIAN_FRONTEND=noninteractive apt --fix-broken install -yq > /dev/null 2>&1
    fix_status=$?
    DEBIAN_FRONTEND=noninteractive apt upgrade -yq --allow-downgrades > /dev/null 2>&1
    upgrade_status=$?

    # Check if all steps were successful
    if [ $update_status -eq 0 ] && [ $fix_status -eq 0 ] && [ $upgrade_status -eq 0 ]; then
        step_success 1 $total_steps $step_message
    else
        step_error 1 $total_steps $step_message
        exit 1
    fi

    # Check for apt locks on installation
    wait_apt_lock 5 60 

    # Install required packages quietly
    packages=("sudo" "apt-utils" "apparmor-utils" "jq" "python3" "docker")
    step_message="Installing required packages"
    step_info 2 $total_steps $step_message

    # Install all packages
    install_all_packages "${packages[@]}"

    if [[ $? -eq 0 ]]; then
        step_success 2 $total_steps $step_message
    else
        step_error 2 $total_steps $step_message
        exit 1
    fi

    success "Packages installed successfully."
}


# Function to clean the local docker environment 
clean_docker_environment() {
    highlight "Cleaning local docker environment"
    sanitize
}


# Function to prompt for server information and process the response
prompt_server_info() {
    local items='[
        { 
            "name": "server_name",
            "label": "Server Name",
            "description": "The name of the server", 
            "required": "yes" 
        }, 
        { 
            "name": "network_name", 
            "label": "Network Name", 
            "description": "The name of the network for Docker stack", 
            "required": "yes"
        }
    ]'
    
    # Run collection process and capture server info JSON
    run_collection_process "$items"
}


# Function to retrieve the server IP address
get_server_ip() {
    local server_ip=$(hostname -I | awk '{print $1}')
    if [[ -z "$server_ip" ]]; then
        error "Unable to retrieve the server IP address."
        exit 1
    fi
    echo "$server_ip"
}


# Function to generate a collection item for the server IP
get_ip_collection_item() {

    # Get current machine IP
    machine_ip=$(get_ip)

    # Generate the collection item JSON (using the values from the prompt and the IP)
    collection_item=$(\
        create_collection_item \
            "server_ip" "Server IP" "IP string of the server" "$machine_ip" "yes"\
    )

    echo "$collection_item"
}


# Function to merge server, network, and IP information
get_server_info() {
    local server_array ip_object merged_result

    # Get the server and network information
    server_array="$(prompt_server_info)"
    if [[ "$server_array" == "[]" ]]; then
        echo "Error: Unable to retrieve server and network names."
        exit 1
    fi

    # Get the IP object
    ip_object="$(get_ip_collection_item)"

    # Merge the JSON objects
    merged_result=$(echo "$server_array" | jq --argjson ip "$ip_object" '. + [$ip]')

    # Check if the merge was successful
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to merge the server and IP information."
        exit 1
    fi

    # Print the merged result
    echo "$merged_result"
}


# Function to initialize the server information
initialize_server_info(){
    total_steps=5

    # Step 1: Check if server_info.json exists and is valid
    if [[ -f "server_info.json" ]]; then
        server_info_json=$(cat server_info.json 2>/dev/null)
        if jq -e . >/dev/null 2>&1 <<<"$server_info_json"; then
            info "Valid server_info.json found. Using existing information."
        else
            warning "server_info.json is invalid. Reinitializing..."
            server_info_json=$(get_server_info)
        fi
    else
        info "server_info.json not found. Retrieving server information..."
        server_info_json=$(get_server_info)

        # Save the server information to a JSON file
        cat "$server_info_json" > server_info.json
        info "Server information saved to server_info.json"
    fi

    # Extract server_name and network_name
    server_name=$(echo "$server_info_json" | jq -r '.[0].server_name')
    network_name=$(echo "$server_info_json" | jq -r '.[0].network_name')
    if [[ -z "$server_name" || -z "$network_name" ]]; then
        echo "Error: Missing server_name or network_name in server_info.json"
        exit 1
    fi

    # Set Hostname
    step_message="Set Hostname"
    step_info 1 $total_steps "$step_message"
    hostnamectl set-hostname "$server_name" > /dev/null 2>&1
    handle_exit $? 1 $total_steps "$step_message"
    
    # Step 6: Update /etc/hosts
    step_message="Add name to server in hosts file at path /etc/hosts"
    step_info 2 $total_steps "$step_message"
    sed -i "s/127.0.0.1[[:space:]]localhost/127.0.0.1 $server_name/g" /etc/hosts > /dev/null 2>&1
    handle_exit $? 2 $total_steps "$step_message"

    # Step 7: Initialize Docker Swarm
    step_message="Docker Swarm initialization"
    step_info 3 $total_steps "$step_message"
    if docker info 2>&1 | grep -q 'Swarm: active'; then
        step_warning 3 $total_steps "$step_message"
    else
        docker swarm init --advertise-addr "$(get_ip)" > /dev/null 2>&1
        handle_exit $? 3 $total_steps "$step_message"
    fi
}


# Function to deploy the selected stack based on input
deploy_stack() {
    local stack="$1"
    case "$stack" in
        redis)
            deploy_stack_redis
            ;;
        postgres)
            deploy_stack_postgres
            ;;
        n8n)
            deploy_stack_n8n
            ;;
        *)
            error "Invalid stack. Available options: ${stack_names[*]}. Provided stack: $stack"
            exit 1
            ;;
    esac
}


# Function to display a great farewell message
farewell_message() {
    highlight ""
    highlight "🌟 Thank you for using the Deployment Tool OpenStack! 🌟"
    highlight ""
    highlight "Your journey doesn't end here:it's just a new beginning."
    highlight "Remember: Success is the sum of small efforts, repeated day in and day out. 🚀"
    highlight ""
    highlight "We hope to see you again soon. Until then, happy coding and stay curious! ✨"
    highlight ""
}


# Function to choose which stack to install interactively
choose_stack_to_install() {
    # Declare arrays for stack labels (user-friendly) and stack names (internal)
    declare -a stack_labels=("Redis" "Postgres" "N8N")
    declare -a stack_names=("redis" "postgres" "n8n")
    declare -a stack_descriptions=(
        "A powerful in-memory data structure store used as a database, cache, and message broker."
        "A relational database management system emphasizing extensibility and SQL compliance."
        "A workflow automation tool that allows you to automate tasks and integrate various services."
    )


    highlight "Select the stack to install:"
    highlight ""

    # Determine the maximum length of stack labels for proper alignment
    max_label_length=0
    for label in "${stack_labels[@]}"; do
        label_length=${#label}
        if (( label_length > max_label_length )); then
            max_label_length=$label_length
        fi
    done

    # Loop through the stack labels and display both name and description, with normalized spacing
    local padding_length=2
    for i in "${!stack_labels[@]}"; do
        # Calculate padding based on the longest label
        padding=$((max_label_length - ${#stack_labels[i]}))
        
        # Use printf to format the stack label and description with consistent spacing
        label_with_padding=$(printf "%-${max_label_length}s" "${stack_labels[i]}")

        description="${stack_descriptions[i]}"
        stack_name="$label_with_padding$(printf "%-${padding_length}s" "")"
        option="$((i + 1)). $stack_name: $description"
        highlight 
    done

    # Add an option to exit
    highlight "$(( ${#stack_labels[@]} + 1 )). Exit"

    # Read user input
    highlight ""
    choice_message="$(format_message "highlight" "Enter your choice: ")"
    read -p "$choice_message" choice

    # Validate the choice and deploy the selected stack
    if [[ "$choice" -ge 1 && "$choice" -le "${#stack_labels[@]}" ]]; then
        local selected_stack_name="${stack_names[$((choice - 1))]}"
        deploy_stack "$selected_stack_name"
    elif [[ "$choice" -eq "$(( ${#stack_labels[@]} + 1 ))" ]]; then
        farewell_message
        exit 0
    else
        error "Invalid choice. Please try again."
        choose_stack_to_install  # Call the function recursively to retry
    fi
}


# Display help message
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -i, --install           Install required packages."
    echo "  -c, --clean             Clean docker environment."
    echo "  -u, --startup           Startup server information."
    echo "  -p, --prepare           Prepare the environment, same as '-i -c'."
    echo "  -s, --stack STACK       Specify which stack to install: redis, postgres, or n8n."
    echo "  -h, --help              Display this help message and exit."
    exit 0
}


# Parse command-line arguments
parse_args() {
    OPTIONS=$(getopt -o i,c,p,u,s:,h --long install,clean,prepare,startup,stack,stack:,help -- "$@")
    eval set -- "$OPTIONS"

    while true; do
        case "$1" in
            -i | --install)
                INSTALL=true
                shift
                ;;
            -c | --clean)
                CLEAN=true
                shift
                ;;
            -p | --prepare)
                PREPARE=true
                shift
                ;;
            -u | --startup)
                STARTUP=true
                shift
                ;;
            -s | --stack)
                STACK=$2
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
}


# Main script execution
main() {
    parse_args "$@"

    if [[ $INSTALL == true ]]; then
        update_and_install_packages
    fi

    if [[ $CLEAN == true ]]; then
        clean_docker_environment
    fi

    if [[ $STARTUP == true ]]; then
        initialize_server_info
    fi

    if [[ $PREPARE == true ]]; then
        update_and_install_packages
        clean_docker_environment
        initialize_server_info
    fi
    
    # Set or choose the stack
    if [[ -n $STACK ]]; then
        deploy_stack "$STACK"
    else
        while true; do
            choose_stack_to_install
        done
    fi
}

# Call the main function
main "$@"



# username="conexxohub_portainer" 
# password="ConexxoHub!54321" 
# portainer_url="portainer.conexxohub.com.br"
# 
# token="$(get_portainer_auth_token $portainer_url $username $password)"
# echo "$token"
# 
# stack_name='n8n'
# echo "$(check_portainer_stack_exists $portainer_url $token $stack_name)"
# 
# get_portainer_swarm_stacks $portainer_url $token
