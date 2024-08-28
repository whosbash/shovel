#!/bin/bash
# Funny system info
echo "Here's your system info with a twist:"
echo "Uptime: $(uptime -p)"
echo "CPU Usage: $(top -bn1 | grep 'Cpu(s)' | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')%"
echo "Available RAM: $(free -h | grep Mem | awk '{print $7}')"
echo "Current User: $(whoami)"
echo "Remember: You are a star!"
