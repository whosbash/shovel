#!/bin/bash
# Random fortune teller
fortunes=(
    "You will find a hidden treasure."
    "Beware of unexpected visitors."
    "Good things are coming your way."
    "A thrilling time is in your near future."
    "You will achieve your dreams."
)
echo "${fortunes[$RANDOM % ${#fortunes[@]}]}"