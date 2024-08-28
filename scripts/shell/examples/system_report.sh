#!/bin/bash
# Generate system report
report_file="$HOME/system_report_$(date +%F).txt"
{
    echo "System Report - $(date)"
    echo "-----------------------"
    echo "Uptime:"
    uptime
    echo
    echo "CPU Info:"
    lscpu
    echo
    echo "Memory Info:"
    free -h
    echo
    echo "Disk Usage:"
    df -h
    echo
    echo "Top 10 Processes by Memory Usage:"
    ps aux --sort=-%mem | head -n 10
} > "$report_file"
echo "Report saved to $report_file"
