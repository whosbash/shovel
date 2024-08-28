#!/bin/bash
# Countdown timer
count=10
while [ $count -gt 0 ]; do
    echo "$count seconds remaining..."
    sleep 1
    ((count--))
done
echo "Time's up! 🎉"