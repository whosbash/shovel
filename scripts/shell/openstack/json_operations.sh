#!/bin/bash

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
            echo "Error: Unsupported JSON types. Please provide valid JSON objects or arrays."
            return 1
            ;;
    esac

    # Output the merged result
    echo "$merged"
}

# Example usage
json1='{"name": "Alice", "age": 30}'
json2='{"city": "New York", "age": 35}'

json_array='[{"id": 1, "item": "apple"}, {"id": 2, "item": "orange"}]'
json_object='{"id": 3, "item": "banana"}'

echo "Merging JSON objects:"
add_json_objects "$json1" "$json2"

echo -e "\nAppending JSON object to JSON array:"
add_json_objects "$json_array" "$json_object"

echo -e "\nAppending JSON array to JSON object:"
add_json_objects "$json_object" "$json_array"

echo -e "\nConcatenating JSON arrays:"
add_json_objects "$json_array" '[{"id": 4, "item": "grape"}]'
