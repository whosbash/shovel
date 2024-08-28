#!/bin/bash
# Random joke from API
joke=$(curl -s https://official-joke-api.appspot.com/random_joke | jq -r '"\(.setup) \n\(.punchline)"')
echo -e "Here's a joke for you:\n$joke"