#!/bin/bash


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
    local additional_properties=$(echo "$schema" | jq -r 'if has("additionalProperties") then .additionalProperties else true end')

    # Check if required keys are present
    for key in $required_keys; do
        if ! echo "$json" | jq -e ". | has(\"$key\")" >/dev/null; then
            errors+=("Missing required key: ${parent_path}${key}")
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
                errors+=("Key '${parent_path}${key}' expected type 'object', but got '$actual_type'")
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
                        errors+=("Array element ${parent_path}${key}[$i] expected type '$item_expected_type', but got '$element_type'")
                        valid=false
                    else
                        # Continue validation for each array element recursively
                        validate_json_recursive "$element" "$items_schema" "${parent_path}${key}[$i]."
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
                # Check if expected_type is an array of types, and if the actual type matches any of them
                if [[ "$expected_type" =~ \[.*\] ]]; then
                    # Expected type is a list of types (e.g., ["string", "number"])
                    expected_types=$(echo "$expected_type" | sed 's/[\[\]" ]//g')  # Remove brackets and spaces
                    for type in $(echo "$expected_types" | tr ',' '\n'); do
                        if [ "$type" == "$actual_type" ]; then
                            valid=true
                            break
                        fi
                    done
                    if [ "$valid" = false ]; then
                        errors+=("Key '${parent_path}${key}' expected one of the types [${expected_types}], but got '$actual_type'")
                        valid=false
                    fi
                else
                    errors+=("Key '${parent_path}${key}' expected type '$expected_type', but got '$actual_type'")
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
                errors+=("Key '${parent_path}${key}' is an extra property, but additionalProperties is false.")
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
validate_json() {
    local json_file="$1"
    local schema_file="$2"

    local json=$(cat "$json_file")
    local schema=$(cat "$schema_file")

    validate_json_recursive "$json" "$schema" ""
}

# Usage: ./json_validator.sh example.json schema.json
schema_file="$1"
json_file="$2"


if [[ -f "$json_file" && -f "$schema_file" ]]; then
    validate_json "$json_file" "$schema_file"
else
    echo "Usage: $0 <json_file> <schema_file>"
fi
