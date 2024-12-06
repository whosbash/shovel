#!/bin/bash

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


readonly HAS_TIMESTAMP=true
readonly PADDING=3

# Enable strict error handling and trap ERR to capture errors
set -o errexit
set -o pipefail
set -o nounset
trap 'handle_error $? $LINENO' ERR


# Function to print a traceback (simulating stack trace)
print_traceback() {
    local i=0
    while caller $i; do
        ((i++))
    done | awk '{print "  at " $2 " (line "$1")"}'
}


# Function to handle errors and generate error objects
handle_error() {
    local exit_code="$1"  # The exit code of the last command
    local line_number="$2"  # The line number where the error occurred

    # Get the command that caused the error
    local last_command=$(history | tail -n 1 | sed 's/^ *[0-9]* *//')

    # Generate a JSON error object
    local error_object
    error_object=$(jq -nc \
        --arg cmd "$last_command" \
        --arg line "$line_number" \
        --arg exit_code "$exit_code" \
        --arg script_name "$0" \
        '{
            script: $script_name,
            command: $cmd,
            line_number: $line,
            exit_code: $exit_code,
            timestamp: (now | todate)
        }')

    # Log the error object to a file
    echo "$error_object" >> "error_log.json"

    # Display a formatted error message
    error "Error in script at line $line_number: '$last_command' (exit code: $exit_code)"
    critical "Traceback (most recent call):"
    print_traceback 
    exit "$exit_code"
}


# Function to filter items based on the given filter function
filter_items() {
    local items="$1"   # The JSON array of items to filter
    local filter_fn="$2"  # The jq filter to apply

    # Apply the jq filter and return the filtered result as an array
    filtered_items=$(echo "$items" | jq "[ $filter_fn ]")
    echo "$filtered_items"
}


# Function to strip existing ANSI escape sequences (colors and styles) from a string
strip_ansi() {
    echo -e "$1" | sed 's/\x1b\[[0-9;]*[mK]//g'
}


# Function to convert each element of a JSON array to base64
convert_json_array_to_base64_array() {
    local json_array="$1"
    # Convert each element of the JSON array to base64 using jq
    echo "$json_array" | jq -r '.[] | @base64'
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
    local type="$1"                             # Message type (success, error, etc.)
    local text="$2"                             # Message text
    local has_timestamp="${3:-$HAS_TIMESTAMP}"  # Option to display timestamp (default is false)

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


# Function to trim leading/trailing spaces
trim() {
    echo "$1" | sed 's/^ *//;s/ *$//'
}


# Example of safe input usage
query_json64() {
    local item="$1"
    local field="$2"
    echo "$item" | base64 --decode | jq -r "$field" || {
        error "Invalid JSON or base64 input!"
        return 1
    }
}


# Function to add JSON objects or arrays
add_json_objects() {
    local json1="$1"  # First JSON input
    local json2="$2"  # Second JSON input

    # Get the types of the input JSON values
    local type1
    local type2
    type1=$(echo "$json1" | jq -e type 2>/dev/null | tr -d '"')
    type2=$(echo "$json2" | jq -e type 2>/dev/null | tr -d '"')

    # Check if both types were captured successfully
    if [ -z "$type1" ] || [ -z "$type2" ]; then
        echo "Error: One or both inputs are invalid JSON."
        return 1
    fi

    # Perform different operations based on the types of inputs
    local merged
    case "$type1-$type2" in
        object-object)
            # Merge the two JSON objects
            merged=$(jq -sc '.[0] * .[1]' <<<"$json1"$'\n'"$json2")
            ;;
        object-array)
            # Append the object to the array
            merged=$(jq -c '. + [$json1]' --argjson json1 "$json1" <<<"$json2")
            ;;
        array-object)
            # Append the object to the array
            merged=$(jq -c '. + [$json2]' --argjson json2 "$json2" <<<"$json1")
            ;;
        array-array)
            # Concatenate the two arrays
            merged=$(jq -sc '.[0] + .[1]' <<<"$json1"$'\n'"$json2")
            ;;
        *)
            # Unsupported combination
            error "Unsupported JSON types. Please provide valid JSON objects or arrays."
            return 1
            ;;
    esac

    # Output the merged result
    echo "$merged"
}


# Example validation function for a specific pattern
validate_name_value() {
    local value="$1"

    # Example: Validate that the value contains only letters and numbers
    if [[ "$value" =~ ^[a-zA-Z0-9]+$ ]]; then
        return 0  # Valid
    else
        return 1  # Invalid
    fi
}


# Function to validate the input and return errors for invalid fields
validate_value() {
    local value="$1"
    local validate_fn="$2"
    local name="$3"

    # Assume validate_fn is a function name and execute it
    $validate_fn "$value"
    if [[ $? -ne 0 ]]; then
        message="Invalid value for '$name'"
        return 1
    fi
    return 0
}


# Function to display each error item with custom formatting
display_error_items() {
    local error_items="$1"  # JSON array of error objects

    # Parse and iterate over each error item in the JSON array
    echo "$error_items" | \
    jq -r '.[] | "\(.name): \(.message) (Function: \(.function))"' | \
    while IFS= read -r error_item; do
        # Display the error item using the existing error function
        error "$error_item"
    done
}


# Function to create an error object with traceback
create_error_item() {
    local name="$1"
    local message="$2"
    local func_name="$3"
    
    # Create a JSON object representing the error with traceback information
    error_object=$(echo "
    {
        \"name\": \"$name\",
        \"message\": \"$message\",
        \"function\": \"$func_name\"
    }" | jq .)

    echo "$error_object"
}


# Function to create a collection item
create_prompt_item() {
    local name="$1"
    local label="$2"
    local description="$3"
    local value="$4"
    local required="$5"
    local validate_fn="$6"

    # Check if the item is required and the value is empty
    if [[ "$required" == "yes" && -z "$value" ]]; then
        error_message="The value for '$name' is required but is empty."
        error_obj=$(create_error_item "$name" "$error_message" "${FUNCNAME[0]}")
        echo "$error_obj"
        return 1
    fi

    # Validate the value using the provided validation function
    if ! validate_value "$value" "$validate_fn" "$name"; then
        # Capture the message returned by the validator
        error_message="$message"
        error_obj=$(create_error_item "$name" "$error_message" "$LINENO" "$validate_fn")
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


# Function to prompt for user input
prompt_for_input() {
    local item="$1"

    name=$(query_json64 "$item" '.name')
    label=$(query_json64 "$item" '.label')
    description=$(query_json64 "$item" '.description')
    required=$(query_json64 "$item" '.required')

    # Assign the 'required' label based on the 'required' field value
    if [[ "$required" == "yes" ]]; then
        required_label="required"
    else
        required_label="optional"
    fi

    local general_info="Prompting $required_label variable $name: $description"
    local explanation="Enter a value or type 'q' to quit"
    local prompt="$general_info\n$explanation: "
    fmt_prompt=$(format_message 'question' "$prompt")

    while true; do
        read -rp "$fmt_prompt" value
        if [[ "$value" == "q" ]]; then
            echo "q"
            return
        fi

        if [[ -n "$value" || "$required" == "no" ]]; then
            echo "$value"
            return
        else
            warning "$label is a required field. Please enter a value."
        fi
    done
}


# Function to collect and validate information
collect_prompt_info() {
    local items="$1"
    json_array="[]"

    for item in $(convert_json_array_to_base64_array "$items"); do
        value=$(prompt_for_input "$item")
        if [[ "$value" == "q" ]]; then
            echo "[]"
            return 0
        fi

        json_object=$(create_prompt_item \
            "$(query_json64 "$item" '.name')" \
            "$(query_json64 "$item" '.label')" \
            "$(query_json64 "$item" '.description')" \
            "$value" \
            "$(query_json64 "$item" '.required')" \
            "$(query_json64 "$item" '.validate_fn')"
        )

        json_array=$(echo "$json_array" | jq ". += [$json_object]")
    done

    echo "$json_array"
}


confirm_and_modify_prompt_info() {
    local json_array="$1"

    while true; do
        # Display collected information to stderr (for terminal)
        info "Provided values: "
        # Calculate the maximum length of the '.name' field and add padding
        max_length=$(\
            echo "$json_array" | \
            jq -r '.[] | .name' | \
            awk '{ print length }' | \
            sort -nr | head -n1 \
        )

        formatted_length=$((max_length + PADDING))

        # Display the collected information with normalized name length
        echo "$json_array" | \
        jq -r '.[] | "\(.name): \(.value)"' | \
        while IFS=: read -r name value; do
            printf "  %-*s: %s\n" "$formatted_length" "$name" "$value"
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




# Function to collect and validate information, then re-trigger collection for errors
run_collection_process() {
    local items="$1"
    local all_collected_info="[]"
    local has_errors=true

    # Keep collecting and re-requesting info for errors
    while [[ "$has_errors" == true ]]; do
        collected_info="$(collect_prompt_info "$items")"

        # If no values were collected, exit early
        if [[ "$collected_info" == "[]" ]]; then
            exit 0
        fi

        # Define the filter functions in jq format
        labels='.name and .label and .description and .value and .required'
        collection_item_filter=".[] | select($labels)"
        error_item_filter='.[] | select(.message and .function)'

        # Separate valid collection items and error objects
        valid_items=$(filter_items "$collected_info" "$collection_item_filter")
        error_items=$(filter_items "$collected_info" "$error_item_filter")

        # Ensure valid JSON formatting by stripping any unwanted characters
        valid_items_json=$(echo "$valid_items" | jq -c .)
        all_collected_info_json=$(echo "$all_collected_info" | jq -c .)

        # Merge valid items with previously collected information
        all_collected_info=$(add_json_objects "$all_collected_info" "$valid_items")

        # Step 1: Extract the names of items with errors from error_items
        error_names=$(echo "$error_items" | jq -r '.[].name' | jq -R . | jq -s .)

        # Step 2: Filter the original items to keep only those whose names match the error items
        items_with_errors=$(\
            echo "$items" | \
            jq --argjson error_names "$error_names" \
            '[.[] | select(.name as $item_name | $error_names | index($item_name))]'
        )

        # Check if there are still errors left
        if [[ "$(echo "$error_items" | jq 'length')" -eq 0 ]]; then
            has_errors=false
        else
            # If there are still errors, re-trigger the collection process for error items only
            warning "Re-collecting information for items with errors..."
            display_error_items "$error_items"

            items="$items_with_errors"
        fi
    done

    # Return all collected and validated information
    confirm_and_modify_prompt_info "$all_collected_info"
}


# Simulate the collection process
items='[
    { 
        "name": "server_name",
        "label": "Server Name",
        "description": "The name of the server", 
        "required": "yes",
        "validate_fn": "validate_name_value"
    },
    { 
        "name": "network_name", 
        "label": "Network Name", 
        "description": "The name of the network for Docker stack", 
        "required": "yes",
        "validate_fn": "validate_name_value"
    }
]'

# Run the function
run_collection_process "$items"
