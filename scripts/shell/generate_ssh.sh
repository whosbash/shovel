#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 [-d DIRECTORY] [-f FILENAME] [-p PASSPHRASE] [-t KEY_TYPE] [-b BITS] [-h]"
    echo "  -d DIRECTORY     Directory where the key should be saved (default: ~/.ssh)"
    echo "  -f FILENAME      Filename for the key (default: id_rsa)"
    echo "  -p PASSPHRASE    Passphrase for the key (optional)"
    echo "  -t KEY_TYPE      Type of key to create (default: rsa)"
    echo "  -b BITS          Number of bits for the key (default: 2048)"
    echo "  -h               Display this help message"
    exit 1
}

# Default values
DIRECTORY="$HOME/.ssh"
FILENAME="id_rsa"
PASSPHRASE=""
KEY_TYPE="rsa"
BITS=2048

# Parse command-line options using getopt
OPTS=$(getopt -o d:f:p:t:b:h --long directory:,filename:,passphrase:,key-type:,bits:,help -n "$0" -- "$@")
if [ $? != 0 ]; then
    usage
fi

eval set -- "$OPTS"

# Extract options and their arguments into variables
while true; do
    case "$1" in
        -d | --directory)
            DIRECTORY="$2"
            shift 2
            ;;
        -f | --filename)
            FILENAME="$2"
            shift 2
            ;;
        -p | --passphrase)
            PASSPHRASE="$2"
            shift 2
            ;;
        -t | --key-type)
            KEY_TYPE="$2"
            shift 2
            ;;
        -b | --bits)
            BITS="$2"
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

# Create the directory if it doesn't exist
mkdir -p "$DIRECTORY"

# Construct the full file path
FILEPATH="$DIRECTORY/$FILENAME"

# Generate the SSH key
if [ -n "$PASSPHRASE" ]; then
    ssh-keygen -t "$KEY_TYPE" -b "$BITS" -f "$FILEPATH" -N "$PASSPHRASE"
else
    ssh-keygen -t "$KEY_TYPE" -b "$BITS" -f "$FILEPATH" -N ""
fi

# Output the result
if [ $? -eq 0 ]; then
    echo "SSH key successfully generated!"
    echo "Private key: $FILEPATH"
    echo "Public key: $FILEPATH.pub"
else
    echo "Error generating SSH key."
fi