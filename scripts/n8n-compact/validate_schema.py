import json
import jsonschema
import argparse
from jsonschema import validate, exceptions

# Function to validate JSON data against the schema and collect all errors
def validate_json(data, schema):
    validation_errors = []

    try:
        validate(instance=data, schema=schema)
        print("JSON is valid!")
    except exceptions.ValidationError as ve:
        validation_errors.append(f"Validation error: {ve.message}")
    except exceptions.SchemaError as se:
        validation_errors.append(f"Schema error: {se.message}")

    # If there are errors, print all of them
    if validation_errors:
        print("\nValidation errors:")
        for error in validation_errors:
            print(error)
    else:
        print("No validation errors found.")

# Load JSON data from a file
def load_json_file(filename):
    try:
        with open(filename, 'r') as file:
            return json.load(file)
    except FileNotFoundError:
        print(f"Error: The file '{filename}' was not found.")
        return None
    except json.JSONDecodeError:
        print(f"Error: The file '{filename}' is not a valid JSON.")
        return None

# Command-line argument parsing
def parse_args():
    parser = argparse.ArgumentParser(description="Validate a JSON file against a given schema.")
    parser.add_argument("json_file", help="Path to the JSON configuration file.")
    parser.add_argument("--schema", help="Schema as a JSON string (instead of a file).")
    parser.add_argument("schema_file", nargs='?', help="Path to the JSON schema file (optional if schema string is provided).")
    return parser.parse_args()

# Main function to load and validate the JSON configuration
def main():
    # Parse command-line arguments
    args = parse_args()

    # Load the JSON data from the file
    data = load_json_file(args.json_file)

    # Load the schema from string or file
    if args.schema:
        try:
            schema = json.loads(args.schema)  # Parse the schema string
        except json.JSONDecodeError:
            print("Error: The schema string is not a valid JSON.")
            return
    elif args.schema_file:
        schema = load_json_file(args.schema_file)
    else:
        print("Error: No schema provided.")
        return

    if data and schema:
        # Validate the loaded JSON data against the schema
        validate_json(data, schema)

# Run the main function
if __name__ == '__main__':
    main()
