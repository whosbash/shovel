#!/bin/bash

# Define the text to convert into ASCII art
TEXT="Hello"

# Get the list of all available fonts
FONTS=$(artii --list)

# Loop through each font and generate ASCII art
for FONT in $FONTS; do
    echo "Font: $FONT"
    artii -f "$FONT" "$TEXT"
    echo "-----------------------------"
done
