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


HAS_TIMESTAMP=true


# Function to strip existing ANSI escape sequences (colors and styles) from a string
strip_ansi() {
    echo -e "$1" | sed 's/\x1b\[[0-9;]*[mK]//g'
}


# Function to decode Base64 to JSON
decode_base64_to_json() {
    local base64_data="$1"
    echo -n "$base64_data" | base64 --decode
}


# Function to convert each element of a JSON array to base64
convert_json_array_to_base64_array() {
    local json_array="$1"
    # Convert each element of the JSON array to base64 using jq
    echo "$json_array" | jq -r '.[] | @base64'
}


# Function to convert JSON to Base64
convert_json_array_to_base64() {
    local json_array="$1"
    echo "$json_array" | jq -c '.[]' | while read -r line; do
        echo "$line" | base64
    done
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
        "success") echo "bold" ;;                           # Bold for success to indicate positivity
        "info") echo "italic" ;;                            # Italic for informational messages
        "error") echo "bold,italic" ;;                      # Bold and italic for errors to emphasize importance
        "critical") echo "bold,underline" ;;                # Bold and underline for critical to highlight severity
        "warning") echo "underline" ;;                      # Underline for warnings to draw attention
        "highlight") echo "bold,underline" ;;               # Bold and underline for highlights to emphasize key points
        "wait") echo "dim,italic" ;;                        # Dim and italic for wait to indicate pending status
        "important") echo "bold,underline,overline" ;;      # Bold, underline, and overline for important messages
        "question") echo "italic,underline" ;;              # Italic and underline for questions to prompt input
        *) echo "normal" ;;                                 # Default to normal style for unknown types
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


query_64json() {
    local item="$1"
    local field="$2"
    echo "$item" | base64 --decode | jq -r "$field"
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
    if ! "$validator" "$value"; then
        error_message="The value '$value' is invalid for '$name'."
        error_obj=$(create_error_object "$name" "$error_message" "$LINENO" "${FUNCNAME[0]}")
        error_array+=("$error_obj")
        return 1  # Validation failed
    fi

    return 0  # Validation passed
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


# Function to validate a name
validate_variable_name() {
    local name="$1"

    # Regex pattern:
    if [[ "$name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9_.-]*[a-zA-Z0-9])?$ ]] && \
        ! [[ "$name" =~ (--|\.\.|__) ]]; then
        return 0  # Valid name
    else
        # Display the error message in a list format
        echo -e "Error: Invalid name '$name'."
        echo -e "Naming rules:"
        echo -e "\t1. Only letters, numbers, hyphens (-), underscores (_), and dots (.) are allowed."
        echo -e "\t2. The name must start and end with a letter or number."
        echo -e "\t3. Consecutive special characters (__, --, ..) are not allowed."
        echo -e "\t4. Names cannot exceed 255 characters."
        return 1  # Invalid name
    fi
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
convert_json_to_base64() {
    local json_array="$1"
    # Convert each element of the JSON array to base64 using jq
    echo "$json_array" | jq -r '.[] | @base64'
}


# Function to create an error object with traceback
# Function to create an error object with traceback
create_error_object() {
    local name="$1"
    local message="$2"
    local line_number="$3"
    local func_name="$4"
    
    # Create a JSON object representing the error with traceback information
    error_object=$(echo "
    {
        \"name\": \"$name\",
        \"message\": \"$message\",
        \"line\": \"$line_number\",
        \"function\": \"$func_name\"
    }" | jq .)

    echo "$error_object"
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


# Function to create a collection item
create_collection_item() {
    local name="$1"
    local label="$2"
    local description="$3"
    local value="$4"
    local required="$5"
    local validate_fn="$6"  # Optional: Validation function name

    # Initialize an empty error array
    error_array=()

    # Check if the item is required and the value is empty
    if [[ "$required" == "yes" && -z "$value" ]]; then
        error_message="The value for '$name' is required but is empty."
        error_obj=$(create_error_object "$name" "$error_message" "$LINENO" "${FUNCNAME[0]}")
        error_array+=("$error_obj")
    fi

    # Validate the value using the provided validation function
    if ! validate_value "$value" "$validate_fn" "$name"; then
        return 1  # Return an error code if validation fails
    fi

    # If there are any errors, return them as a JSON array
    if [[ ${#error_array[@]} -gt 0 ]]; then
        echo "[ ${error_array[@]} ]"
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

# Example validation function for a specific pattern
validate_name_value() {
    local value="$1"

    # Validate that the value contains only letters and numbers (no spaces allowed)
    if [[ "$value" =~ ^[a-zA-Z0-9]+$ ]]; then
        return 0  # Valid
    else
        echo "Error: '$value' is invalid. It must contain only letters and numbers."
        return 1  # Invalid
    fi
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


# Collect and validate the prompt information with error tracking
collect_prompt_info() {
    # Initialize an empty JSON array and error tracking array
    json_array="[]"
    validation_errors=""

    # Loop through each item in the JSON array using jq
    for item in $(convert_json_array_to_base64_array "$1"); do
        # Decode the base64 item to extract necessary fields
        decoded_item=$(echo "$item" | base64 --decode)
        name=$(echo "$decoded_item" | jq -r '.name')
        label=$(echo "$decoded_item" | jq -r '.label')
        description=$(echo "$decoded_item" | jq -r '.description')
        required=$(echo "$decoded_item" | jq -r '.required')
        validate_fn=$(echo "$decoded_item" | jq -r '.validate_fn')  # Assume validation function is stored in JSON
        
        # Collect input based on the item
        value=$(prompt_for_input "$item")

        # If the user typed "exit", return an empty JSON array and exit
        if [[ "$value" == "q" ]]; then
            echo "[]"
            return 0  # Exit function immediately with empty array
        fi

        # Validate the value
        if ! validate_value "$value" "$validate_fn" "$name"; then
            validation_errors="$validation_errors$name: $message\n"
            continue  # Skip this field for now, we'll modify it later
        fi

        # Create a JSON object with name, description, required, and the user input value
        json_object=$(create_collection_item "$name" "$label" "$description" "$value" "$required" "$validate_fn")

        # Add the new object to the JSON array
        json_array=$(echo "$json_array" | jq ". += [$json_object]")
    done

    # Output the final JSON array with all items and any validation errors
    if [[ -n "$validation_errors" ]]; then
        echo "Validation Errors: $validation_errors"
    fi
    echo "$json_array"
}


# Confirmation and modification function with error tracking
confirm_and_modify_prompt_info() {
    local json_array="$1"
    local validation_errors="$2"

    while true; do
        # Display collected information to stderr (for terminal)
        info "Provided values: "
        echo "$json_array" | jq -r '.[] | "\(.name): \(.value)"' | while IFS= read -r line; do
            info "\t$line"
        done

        # Display validation errors, if any
        if [[ -n "$validation_errors" ]]; then
            echo "Validation Errors: $validation_errors"
        fi

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

    collected_info_and_errors=$(collect_prompt_info "$items")

    # If no values were collected, exit early
    if [[ "$collected_info_and_errors" == "[]" ]]; then
        echo "[]"
        exit 0
    fi

    # Separate collected JSON and validation errors
    collected_info=$(echo "$collected_info_and_errors" | jq 'select(type == "array")')
    validation_errors=$(echo "$collected_info_and_errors" | jq 'select(type == "string")')

    confirm_and_modify_prompt_info "$collected_info" "$validation_errors"
}

# Mock a validation function that will simulate invalid or valid input
mock_validation_fn() {
    local value="$1"
    local name="$2"
    
    # Simulate a validation rule: if the value contains 'error', it's invalid
    if [[ "$value" == *"error"* ]]; then
        message="Invalid input: $name contains 'error'."
        return 1
    fi
    
    return 0
}

# Function to base64-encode JSON (simulating input items)
base64_encode_item() {
    local name="$1"
    local label="$2"
    local description="$3"
    local required="$4"
    local validate_fn="$5"
    
    # Construct the JSON item
    json_item=$(jq -n \
        --arg name "$name" \
        --arg label "$label" \
        --arg description "$description" \
        --arg required "$required" \
        --arg validate_fn "$validate_fn" \
        '{
            name: $name,
            label: $label,
            description: $description,
            required: $required,
            validate_fn: $validate_fn
        }')

    # Base64 encode the JSON item
    echo "$json_item" | base64
}

# Simulate the collection process
items='[
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

# Run the function
run_collection_process "$items"
