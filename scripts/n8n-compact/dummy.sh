#!/bin/bash

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
    }" | jq -c .)

    echo "$error_object"
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


# Example validator function
validate_name_value() {
    local value="$1"
    # Example: Validate that the value contains only letters and numbers (no spaces)
    if [[ "$value" =~ ^[a-zA-Z0-9]+$ ]]; then
        return 0  # Valid
    else
        # Return the custom error message if validation fails
        echo "The value '$value' is invalid for '$name'. It must contain only letters and numbers (no spaces)."
        return 1  # Invalid
    fi
}

name="server_name"
label="Server Name"
description="The name of the server"
value="my server123"  # Invalid value because of space
required="yes"
validate_fn="validate_name_value"

# Call the function and capture the output
result=$(create_collection_item "$name" "$label" "$description" "$value" "$required" "$validate_fn")

# Output the result
echo "$result"