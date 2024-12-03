#!/usr/bin/env bats

# Define the path to the validate.sh script
JSON_VALIDATOR_SCRIPT="./validate.sh"

# Define test schema and JSON files
VALID_JSON="valid_test.json"
INVALID_JSON="invalid_test.json"
SCHEMA_FILE="test_schema.json"

# Setup and Teardown functions to manage temporary files
setup() {
    rm -f $VALID_JSON $INVALID_JSON $SCHEMA_FILE
}

teardown() {
    rm -f $VALID_JSON $INVALID_JSON $SCHEMA_FILE
}

# Test if the script validates a valid JSON against a schema
@test "validate valid JSON" {
    # Prepare the valid JSON and schema files
    echo '{"name": "Alice", "age": 30}' > $VALID_JSON
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "age": { "type": "integer" }
        },
        "required": ["name", "age"]
    }' > $SCHEMA_FILE

    # Run the validator and check if there are no errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $VALID_JSON)
    echo "Validation result: $result"  # Add this line to debug
    
    # No errors should be printed
    [ -z "$result" ]
}

# Test if the script returns an error for missing required keys
@test "validate invalid JSON with missing required key" {
    # Prepare the invalid JSON and schema files
    echo '{"name": "Alice"}' > $INVALID_JSON  # Missing "age"
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "age": { "type": "integer" }
        },
        "required": ["name", "age"]
    }' > $SCHEMA_FILE

    # Run the validator and check if there are errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $INVALID_JSON)
    
    # Should print error about missing key
    [[ "$result" == *"Missing required key"* ]]
}

# Test if the script detects an invalid type for a property
@test "validate invalid JSON with wrong type" {
    # Prepare the invalid JSON and schema files
    echo '{"name": "Alice", "age": "not_a_number"}' > $INVALID_JSON  # "age" should be integer
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "age": { "type": "integer" }
        },
        "required": ["name", "age"]
    }' > $SCHEMA_FILE

    # Run the validator and check if there are errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $INVALID_JSON)

    # Should print error about type mismatch
    [[ "$result" == *"expected type 'integer', but got 'string'"* ]] 
}

# Test if the script handles the case of extra properties
@test "validate JSON with extra properties" {
    # Prepare the JSON and schema files
    echo '{"name": "Alice", "age": 30, "extra_field": "value"}' > $VALID_JSON  # "extra_field" is not defined in the schema
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "age": { "type": "integer" }
        },
        "required": ["name", "age"]
    }' > $SCHEMA_FILE

    # Run the validator and check if there are no errors (extra properties are allowed in this case)
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $VALID_JSON)
    
    # No errors should be printed
    [ -z "$result" ] 

}

@test "validate JSON with correct array type" {
    # Prepare the valid JSON and schema files
    echo '{"name": "Alice", "hobbies": ["reading", "swimming"]}' > $VALID_JSON
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "hobbies": { "type": "array", "items": { "type": "string" } }
        },
        "required": ["name", "hobbies"]
    }' > $SCHEMA_FILE

    # Run the validator and check if there are no errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $VALID_JSON)
    
    # No errors should be printed
    [ -z "$result" ]

}


@test "validate JSON with null value for optional key" {
    # Prepare the valid JSON and schema files
    echo '{"name": "Alice", "age": null}' > $VALID_JSON  # "age" is allowed to be null
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "age": { "type": "integer" }
        },
        "required": ["name"]
    }' > $SCHEMA_FILE

    # Run the validator and check if there are no errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $VALID_JSON)
    
    # No errors should be printed
    [ -z "$result" ]

}


@test "validate JSON with array having incorrect type" {
    # Prepare the invalid JSON and schema files
    echo '{"name": "Alice", "hobbies": ["reading", 123]}' > $INVALID_JSON  # "123" is not a string
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "hobbies": { "type": "array", "items": { "type": "string" } }
        },
        "required": ["name", "hobbies"]
    }' > $SCHEMA_FILE

    # Run the validator and check if there are errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $INVALID_JSON)

    # Should print error about array element type mismatch
    [[ "$result" == *"expected type 'string', but got 'number'"* ]] 

}


@test "validate JSON with extra properties when additionalProperties is false" {
    # Prepare the invalid JSON and schema files
    echo '{"name": "Alice", "age": 30, "extra_field": "value"}' > $INVALID_JSON  # "extra_field" is not defined in the schema
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "age": { "type": "integer" }
        },
        "required": ["name", "age"],
        "additionalProperties": false
    }' > $SCHEMA_FILE

    # Run the validator and check if there are errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $INVALID_JSON)
    
    # Should print error about extra property
    [[ "$result" == *"extra property"* ]]

}


@test "validate JSON with nested object" {
    # Prepare the valid JSON and schema files
    echo '{"name": "Alice", "address": {"street": "123 Main St", "city": "Wonderland"}}' > $VALID_JSON
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "address": {
                "type": "object",
                "properties": {
                    "street": { "type": "string" },
                    "city": { "type": "string" }
                },
                "required": ["street", "city"]
            }
        },
        "required": ["name", "address"]
    }' > $SCHEMA_FILE

    # Run the validator and check if there are no errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $VALID_JSON)

}


@test "validate JSON with nested object having missing required key" {
    # Prepare the invalid JSON and schema files
    echo '{"name": "Alice", "address": {"street": "123 Main St"}}' > $INVALID_JSON  # Missing "city" in "address"
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "address": {
                "type": "object",
                "properties": {
                    "street": { "type": "string" },
                    "city": { "type": "string" }
                },
                "required": ["street", "city"]
            }
        },
        "required": ["name", "address"]
    }' > $SCHEMA_FILE

    # Run the validator and check if there are errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $INVALID_JSON)

    # Should print error about missing key in nested object
    [[ "$result" == *"Missing required key"* ]]

}


@test "validate JSON with boolean value" {
    # Prepare the valid JSON and schema files
    echo '{"is_active": true}' > $VALID_JSON
    echo '{
        "type": "object",
        "properties": {
            "is_active": { "type": "boolean" }
        },
        "required": ["is_active"]
    }' > $SCHEMA_FILE

    # Run the validator and check if there are no errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $VALID_JSON)

}


@test "validate JSON with empty array" {
    # Prepare the valid JSON and schema files
    echo '{"name": "Alice", "hobbies": []}' > $VALID_JSON
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "hobbies": { "type": "array", "items": { "type": "string" } }
        },
        "required": ["name", "hobbies"]
    }' > $SCHEMA_FILE

    # Run the validator and check if there are no errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $VALID_JSON)
    
    # No errors should be printed
    [ -z "$result" ]

}


@test "validate JSON with extra properties when additionalProperties is true" {
    # Prepare the valid JSON and schema files
    echo '{"name": "Alice", "age": 30, "extra_field": "value"}' > $VALID_JSON  # "extra_field" is not defined in the schema
    echo '{
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "age": { "type": "integer" }
        },
        "required": ["name", "age"],
        "additionalProperties": true
    }' > $SCHEMA_FILE

    # Run the validator and check if there are no errors
    result=$($JSON_VALIDATOR_SCRIPT $SCHEMA_FILE $VALID_JSON)

    # No errors should be printed
    [ -z "$result" ]
}
