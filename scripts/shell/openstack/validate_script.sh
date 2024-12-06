#!/bin/bash

# Function to find large lines
find_large_lines() {
    local file="$1"
    local max_length="$2"
    local verbose="$3"

    if [[ ! -f "$file" ]]; then
        echo -e "\033[31mError: The file '$file' does not exist.\033[0m" >&2
        return 1
    fi

    if [[ ! "$max_length" =~ ^[0-9]+$ ]]; then
        echo -e "\033[31mError: The provided maximum length is not a valid number.\033[0m" >&2
        return 1
    fi

    echo -e "\033[34mChecking for lines longer than $max_length characters...\033[0m"

    # Track the number of lines longer than max_length
    local count=0
    local line_number=0

    # Process the file line by line
    while IFS= read -r line; do
        ((line_number++))  # Increment line number
        line_length=${#line}
        if [[ $line_length -gt $max_length ]]; then
            ((count++))
            if [[ "$verbose" == true ]]; then
                printf " %-6s Line %s has length %s\n" "" "$line_number" "$line_length"
            fi
        fi
    done < "$file"

    # Print summary
    if [[ "$verbose" != true ]]; then
        echo "  $count lines longer than $max_length characters."
    fi
}


# Function to check function definitions and usage
check_function_definitions() {
    local file="$1"
    local verbose="$2"

    echo -e "\033[34mChecking function definitions and usage...\033[0m"
    local functions
    functions=$(grep -oP '^\s*([a-zA-Z_][a-zA-Z_0-9]*)\s*\(\)' "$file" | sort | uniq)

    local total_warnings=0
    while IFS= read -r function; do
        local name="${function%%(*}"
        local line_numbers=($(grep -nP "^\s*${name}\s*\(\)" "$file" | cut -d: -f1))
        local definition_count="${#line_numbers[@]}"
        local usage_count

        # Check if function is defined multiple times
        if [[ "$definition_count" -gt 1 ]]; then
            ((total_warnings += definition_count))
            if [[ "$verbose" == true ]]; then
                printf "  %-6s Function '%s' defined %d times (lines: %s)\n" \
                "" "$name" "$definition_count" "${line_numbers[*]}"
            fi
        fi

        # Check if function is used (exclude the definition line)
        usage_count=$(grep -c "\\b$name\\b" "$file")
        if [[ "$usage_count" -le 1 ]]; then
            ((total_warnings++))
            if [[ "$verbose" == true ]]; then
                printf "  %-6s Function '%s' defined but not used (line: %d)\n" \
                "" "$name" "${line_numbers[0]}"
            fi
        fi
    done <<< "$functions"

    if [[ "$verbose" != true ]]; then
        echo "  Total warnings: $total_warnings"
    fi
}

# Function to check for deprecated commands
check_deprecated_commands() {
    local file="$1"
    local verbose="$2"
    local deprecated=("which" "expr" "let")

    echo -e "\033[34mChecking for deprecated commands...\033[0m"
    local deprecated_count=0
    for cmd in "${deprecated[@]}"; do
        local lines=($(grep -n "\b$cmd\b" "$file" | cut -d: -f1))
        if [[ ${#lines[@]} -gt 0 ]]; then
            ((deprecated_count += ${#lines[@]}))
            if [[ "$verbose" == true ]]; then
                printf " %-6s Deprecated command '%s' found on lines: %s\n" "" "$cmd" "${lines[*]}"
            fi
        fi
    done

    if [[ "$verbose" != true ]]; then
        echo "  Total deprecated commands: $deprecated_count"
    fi
}

# Function to check for inconsistent indentation
check_indentation() {
    local file="$1"
    local verbose="$2"
    local indentation_issues=0

    echo -e "\033[34mChecking for inconsistent indentation...\033[0m"
    if grep -qP "\t" "$file"; then
        ((indentation_issues++))
        [[ "$verbose" == true ]] && \
        echo -e "\033[33m  Warning: Tabs found instead of spaces.\033[0m"
    fi

    if ! grep -Pq '^\s{4}[^ ]' "$file"; then
        ((indentation_issues++))
        [[ "$verbose" == true ]] && \
        echo -e "\033[33m  Warning: Indentation may not be consistent (4 spaces expected).\033[0m"
    fi

    if [[ "$verbose" != true ]]; then
        echo "  Total indentation issues: $indentation_issues"
    fi
}

# Main function to validate the shell script
validate_script() {
    local file=""
    local max_length=100
    local verbose=false

    # Parse the command-line options using getopt
    options=$(getopt -o vl: --long verbose,length: -n "$0" -- "$@")
    eval set -- "$options"

    # Extract the arguments
    while true; do
        case "$1" in
            -v|--verbose)
                verbose=true
                shift
                ;;
            -l|--length)
                max_length="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Internal error!" >&2
                exit 1
                ;;
        esac
    done

    # Assign file argument
    file="$1"

    if [[ -z "$file" ]]; then
        echo -e "\033[31mUsage: $0 <file> [-v] [-l <max_line_length>]\033[0m" >&2
        return 1
    fi

    echo -e "\033[32mStarting shell script validation...\033[0m"
    find_large_lines "$file" "$max_length" "$verbose"
    check_function_definitions "$file" "$verbose"
    check_deprecated_commands "$file" "$verbose"
    check_indentation "$file" "$verbose"
    echo -e "\033[32mValidation completed.\033[0m"
}


# Example usage
if [[ $# -lt 2 ]]; then
    echo -e "\033[31mUsage: $0 <file_path> <max_length> [-v] [--max-length <length>]\033[0m" >&2
    exit 1
fi

validate_script "$@"
