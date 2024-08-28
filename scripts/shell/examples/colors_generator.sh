#!/bin/bash
# Colorful text
for color in {31..36}; do
    echo -e "\033[${color}mThis is a colorful message!\033[0m"
done