#!/bin/bash

# Variables for JSON schema and config files
SCHEMA_FILE="./n8n_config_schema.json"
CONFIG_FILE="./n8n_config.json"

n8n_json_schema='{
    "type": "object",
    "properties": {
        "webhook_url": {
            "type": "string",
            "format": "uri"
        },
        "domain_url": {
            "type": "string",
            "minLength": 1
        },
        "smtp": {
            "type": "object",
            "properties": {
                "email": {
                    "type": "string",
                    "format": "email"
                },
                "user": {
                    "type": "string"
                },
                "password": {
                    "type": "string"
                },
                "host": {
                    "type": "string"
                },
                "port": {
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 65535
                },
                "ssl": {
                    "type": "boolean"
                }
            },
            "required": ["email", "user", "password", "host", "port"]
        }
    },
    "required": ["webhook_url", "domain_url", "smtp"]
}'

# Check if Python is installed
if ! command -v python3 &> /dev/null
then
    echo "Python3 could not be found. Please install Python3 to continue."
    exit 1
fi

# Run the Python script for validation
echo "Validating configuration..."
python3 validate_schema.py "$CONFIG_FILE" --schema "$n8n_json_schema"

# Capture the exit code of the validation
EXIT_CODE=$?

# Provide feedback based on the result
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ JSON configuration is valid."
else
    echo "❌ JSON configuration validation failed."
fi

exit $EXIT_CODE
