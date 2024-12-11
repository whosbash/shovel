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


get_status_icon() {
    local type="$1"

    case "$type" in
        "success") echo "🌟" ;;         # Bright star for success
        "error") echo "🔥" ;;           # Fire icon for error
        "warning") echo "⚠️" ;;         # Lightning for warning
        "info") echo "💡" ;;            # Light bulb for info
        "highlight") echo "🌈" ;;       # Rainbow for highlight
        "debug") echo "🔍" ;;           # Magnifying glass for debug
        "critical") echo "💀" ;;        # Skull for critical
        "note") echo "📌" ;;            # Pushpin for note
        "important") echo "⚡" ;;       # Rocket for important
        "wait") echo "⌛" ;;            # Hourglass for waiting
        "question") echo "🤔" ;;        # Thinking face for question
        "celebrate") echo "🎉" ;;       # Party popper for celebration
        "progress") echo "📈" ;;        # Upwards chart for progress
        "failure") echo "💔" ;;         # Broken heart for failure
        "tip") echo "🍀" ;;             # Four-leaf clover for additional success
        *) echo "🌀" ;;                 # Cyclone for undefined type
    esac
}


# Function to get the color code based on the message type
get_status_color() {
    local type="$1"

    case "$type" in
        "success") echo "green" ;;       # Green for success
        "error") echo "light_red" ;;     # Light Red for error
        "warning") echo "yellow" ;;      # Yellow for warning
        "info") echo "teal" ;;          # White for info
        "highlight") echo "cyan" ;;      # Cyan for highlight
        "debug") echo "blue" ;;          # Blue for debug
        "critical") echo "light_magenta" ;;    # Light Magenta for critical
        "note") echo "pink" ;;           # Gray for note
        "important") echo "gold" ;;    # Orange for important
        "wait") echo "light_yellow" ;;   # Light Yellow for waiting
        "question") echo "purple" ;;     # Purple for question
        "celebrate") echo "green" ;;     # Green for celebration
        "progress") echo "lime" ;;       # Blue for progress
        "failure") echo "light_red" ;;         # Red for failure
        "tip") echo "light_cyan" ;;     # Light Green for tips
        *) echo "white" ;;               # Default to white for unknown types
    esac
}

# Function to get the style code based on the message type
get_status_style() {
    local type="$1"

    case "$type" in
        "success") echo "bold" ;;                      # Bold for success
        "info") echo "italic" ;;                       # Italic for info
        "error") echo "bold,italic" ;;                 # Bold and italic for errors
        "critical") echo "bold,underline" ;;           # Bold and underline for critical
        "warning") echo "underline" ;;                 # Underline for warnings
        "highlight") echo "bold,underline" ;;          # Bold and underline for highlights
        "wait") echo "dim,italic" ;;                   # Dim and italic for pending
        "important") echo "bold,underline,overline" ;; # Bold, underline, overline for important
        "question") echo "italic,underline" ;;         # Italic and underline for questions
        "celebrate") echo "bold" ;;                    # Bold for celebration
        "progress") echo "italic" ;;                   # Italic for progress
        "failure") echo "bold,italic" ;;               # Bold and italic for failure
        "tip") echo "bold,italic" ;;                   # Bold and italic for tips
        *) echo "normal" ;;                            # Default to normal style for unknown types
    esac
}


# Function to colorize a message based on its type
colorize_by_type() {
    local type="$1"
    local text="$2"

    colorize "$text" "$(get_status_color "$type")" "$(get_status_style "$type")"
}


format_message() {
    local type="$1"                             # Message type (success, error, etc.)
    local text="$2"                             # Message text
    local has_timestamp="${3:-$HAS_TIMESTAMP}"  # Option to display timestamp (default is false)

    # Get icon based on status
    local icon  
    icon=$(get_status_icon "$type")

    # Add timestamp if enabled
    local timestamp=""
    if [ "$has_timestamp" = true ]; then
        timestamp="[$(date '+%Y-%m-%d %H:%M:%S')] "
        # Only colorize the timestamp
        timestamp="$(colorize "$timestamp" "$(get_status_color "$type")" "normal")"
    fi

    # Colorize the main message
    local colorized_message
    colorized_message="$(colorize_by_type "$type" "$text")"

    # Display the message with icon, timestamp, and colorized message
    echo -e "$icon $timestamp$colorized_message"
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


# Function to display celebrate formatted messages
celebrate() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'celebrate' "$message" $timestamp >&2
}


# Function to display progress formatted messages
progress() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'progress' "$message" $timestamp >&2
}


# Function to display failure formatted messages
failure() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'failure' "$message" $timestamp >&2
}


# Function to display tip formatted messages
tip() {
    local message="$1"                      # Step message
    local timestamp="${2:-$HAS_TIMESTAMP}"  # Optional timestamp flag
    echo_message 'tip' "$message" $timestamp >&2
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


# Function to handle empty collections and avoid exiting prematurely
handle_empty_collection() {
    if [[ "$1" == "[]" ]]; then
        warning "No data collected. Exiting process."
        exit 0
    fi
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


# Function to sort array1 based on the order of names in array2 using a specified key
sort_array_by_order() {
    local array1="$1"
    local order="$2"
    local key="$3"

    echo "$array1" | jq --argjson order "$order" --arg key "$key" '
    map( .[$key] as $name | {item: ., index: ( $order | index($name) // length) } ) |
    sort_by(.index) | map(.item)
    '
}


# Function to extract values based on a key
extract_values(){
    echo "$1" | jq -r "map(.$2)"
}

# Function to extract a specific field from a JSON array
extract_field() {
    local json="$1"
    local field="$2"
    echo "$json" | jq -r ".[].$field"
}

# Function to filter items based on a field value match
filter_items_by_name() {
    local json="$1"
    local name="$2"
    echo "$json" | jq -c --arg name "$name" '[.[] | select(.name == $name)]'
}

# Function to add a JSON object to an array
append_to_json_array() {
    local json_array="$1"
    local json_object="$2"
    echo "$json_array" | jq ". += [$json_object]"
}


sort_array_according_to_other_array(){
    local array1="$1"
    local array2="$2"
    local key="$3"
    order="$(extract_values "$array2" "$key")"
    echo "$(sort_array_by_order "$array1" "$order" "$key")"
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


validate_name_value() {
    local value="$1"

    # Check if the name starts with a number
    if [[ "$value" =~ ^[0-9] ]]; then
        echo "The value '$value' should not start with a number."
        return 1
    fi

    # Check if the name contains invalid characters
    if [[ ! "$value" =~ ^[a-zA-Z0-9][a-zA-Z0-9@#\&*_-]*$ ]]; then
        criterium="Only letters, numbers, and '@', '#', '&', '*', '_', '-' are allowed."
        error_message="The value '$value' contains invalid characters."
        echo "$error_message $criterium"
        return 1
    fi

    return 0
}


validate_email_value() {
    local value="$1"

    # Check if the value matches an email pattern
    if [[ ! "$value" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "The value '$value' is not a valid email address."
        return 1
    fi

    return 0
}


validate_integer_value() {
    local value="$1"

    # Check if the value is an integer (allow negative and positive integers)
    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
        echo "The value '$value' is not a valid integer."
        return 1
    fi

    return 0
}


validate_port_availability() {
    local port="$1"

    # Check if the port is a valid number between 1 and 65535
    if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        echo "The value '$port' is not a valid port number. Port numbers must be between 1 and 65535."
        return 1
    fi

    # Use netcat (nc) to check if the port is open on localhost
    # The -z flag checks if the port is open (without sending data)
    # The -w1 flag specifies a timeout of 1 second
    nc -z -w1 127.0.0.1 "$port" 2>/dev/null

    # Check the result of the netcat command
    if [[ $? -eq 0 ]]; then
        echo "The port '$port' is already in use."
        return 1
    else
        echo "The port '$port' is available."
        return 0
    fi
}



# Function to validate the input and return errors for invalid fields
validate_value() {
    local value="$1"
    local validate_fn="$2"

    # Capture the output from the validation function
    error_message=$($validate_fn "$value")

    # Check the return code of the validation function
    if [[ $? -ne 0 ]]; then
        # If validation failed, capture and print the error message
        echo "$error_message"
        return 1
    fi
    return 0
}


# Function to create a error item
create_error_item() {
    local name="$1"
    local message="$2"
    local validate_fn="$3"

    # Escape the message for jq
    local escaped_message
    escaped_message=$(printf '%s' "$message" | jq -R .)

    # Create the error object using jq
    jq -n \
    --arg name "$name" \
    --arg value "$value" \
    --arg message "$escaped_message" \
    --arg validate_fn "$validate_fn" \
    '{
        name: $name,
        message: ($message | fromjson),
        value: $value,
        function: $validate_fn
    }'
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
    validation_output=$(validate_value "$value" "$validate_fn" 2>&1)

    # If validation failed, capture the validation message
    if [[ $? -ne 0 ]]; then
        # Validation failed, use the validation message captured in validation_output
        error_obj=$(create_error_item "$name" "$validation_output" "$validate_fn")
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
        \"required\": \"$required\",
        \"validate_fn\": \"$validate_fn\"
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

        json_array=$(append_to_json_array "$json_array" "$json_object")
    done

    echo "$json_array"
}


confirm_and_modify_prompt_info() {
    local json_array="$1"

    while true; do
        # Display collected information to stderr (for terminal)
        info "Provided values: "
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
            printf "  %-*s: %s\n" "$formatted_length" "$name" "$value" >&2
        done

        # Ask for confirmation (stderr)
        options="y to confirm, n to modify, or q to quit"
        confirmation_msg="$(
            format_message "question" "Is the information correct? ($options) "
        )"
        read -rp "$confirmation_msg" confirmation

        case "$confirmation" in
        y)
            # Validate the confirmed data before returning
            for item in $(echo "$json_array" | jq -r '.[] | @base64'); do
                _jq() {
                    echo "$item" | base64 --decode | jq -r "$1"
                }

                value=$(_jq '.value')
                validate_fn=$(_jq '.validate_fn')

                # Call validate_value function (ensure you have this function implemented)
                validation_output=$(validate_value "$value" "$validate_fn" 2>&1)

                if [[ $? -ne 0 ]]; then
                    warning "Validation failed for '$value': $validation_output"
                    echo "$json_array" | jq -r ".[] | select(.value == \"$value\")"
                    continue  # Continue looping to re-modify the invalid value
                fi
            done

            # If no validation failed, output the final JSON to stdout (for file capture)
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
                    # Validate new value
                    validate_fn=$(echo "$json_array" | jq -r ".[] | select(.name == \"$field_to_modify\") | .validate_fn")
                    validation_output=$(validate_value "$new_value" "$validate_fn" 2>&1)

                    if [[ $? -ne 0 ]]; then
                        warning "Validation failed for '$new_value': $validation_output"
                        continue
                    fi

                    # Modify the JSON by updating the value of the specified field
                    json_array=$(\
                        echo "$json_array" | \
                        jq \
                            --arg field "$field_to_modify" \
                            --arg value "$new_value" \
                            '(.[] | select(.name == $field) | .value) = $value')
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
        handle_empty_collection "$collected_info"

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
        error_names=$(echo "$error_items" | jq -r '.[].name' | jq -R -s .)

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

    # Step to sort the collected information by the original order (using 'name' for sorting)
    all_collected_info="$(sort_array_according_to_other_array "$all_collected_info" "$items" "name")"

    # Return all collected and validated information
    confirmed_info="$(confirm_and_modify_prompt_info "$all_collected_info")"

    echo "$confirmed_info"
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
name="server_name"
label="Server Name"
description="The name of the server"
value="a b"
required="yes"
validate_fn="validate_name_value"

#run_collection_process "$items"
success "Hello"
error "Hello"
warning "Hello"
info "Hello"
highlight "Hello"
debug "Hello"
critical "Hello"
note "Hello"
important "Hello"
wait "Hello"
question "Hello"
celebrate "Hello"
progress "Hello"
failure "Hello"
tip "Hello"

# # Test the validation function with invalid input
# echo "$(validate_value "a b" 'validate_name_value')"
