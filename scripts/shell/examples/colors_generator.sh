#!/bin/bash

# Function to display a colorful message
display_colorful_message() {
    local message="$1"
    local color_code="$2"
    echo -ne "\033[${color_code}m${message}\033[0m"
}

# Function to create a delay
delay() {
    sleep "$1"
}

# Sliding animation with a reset point
animate_slide() {
    local message="$1"
    local screen_width=$(tput cols)  # Get the screen width
    local message_length=${#message}
    local slide_limit=$((screen_width + message_length))  # Slide until the entire message has passed

    for color in {31..36}; do  # Loop through the colors
        for ((i = 0; i < slide_limit; i++)); do
            printf "\r"  # Move the cursor to the beginning of the line

            # Create the sliding effect with wrapping
            local display_message="${message:($i % message_length)}${message:0:($i % message_length)}"

            # Display the colorful message
            display_colorful_message "$display_message" "$color"

            # Slow down the movement
            delay 0.05  # Adjust this delay for slower or faster movement
        done
    done

    printf "\r\033[K"  # Clear the line at the end
    echo ""  # Print a newline after the animation
}



# Bouncing animation with a reset point
animate_bounce() {
    local message="$1"
    local factor=3
    local max_pos=$(($(tput cols) / factor))  # Bounce until a third of the screen width
    local message_length=${#message}
    local pos=0
    local direction=1
    local color_index=0
    local colors=(91 92 93 94 95 96)  # Array of colors to use for bouncing

    for ((i = 0; i < max_pos * 2; i++)); do
        # Clear the line before printing the new position
        printf "\r\033[K"  # Clear the line

        # Adjust the padding based on the current position
        local padding=$(printf "%${pos}s" "")  # Create padding for the current position

        # Print the message with the padding and the current color
        display_colorful_message "${padding}${message}" "${colors[color_index]}"

        # Reduce flickering by adjusting the delay
        delay 0.08  # Slightly slower bouncing to reduce flickering

        # Control direction based on the position
        if ((direction == 1)); then
            ((pos++))
            # Reverse direction when the message reaches the end of the screen
            if ((pos >= max_pos - message_length)); then
                direction=-1
                # Change color when bouncing back
                ((color_index = (color_index + 1) % ${#colors[@]}))
            fi
        else
            ((pos--))
            # Reverse direction when the message reaches the start
            if ((pos <= 0)); then
                direction=1
                # Change color when bouncing forward
                ((color_index = (color_index + 1) % ${#colors[@]}))
            fi
        fi
    done
    printf "\r\033[K"  # Clear the line at the end of the animation
    echo ""  # Print a newline at the end
}



# Blinking animation
animate_blink() {
    local message="$1"

    for color in {33..37}; do
        printf "\r"
        display_colorful_message "$message" "$color"
        delay 0.4  # Slower blinking
        printf "\r\033[K"  # Clear line
        delay 0.4
    done
    echo ""
}

# Waving animation with smooth transition
# Waving animation with a bi-directional moving color window
animate_wave() {
    local message="$1"
    local wave_length=${#message}
    local color_cycle=(91 92 93 94)  # Array of colors to cycle through
    local color_index=0
    local window_size=3  # The size of the colored window (adjustable)
    local direction=1  # Direction of the wave (1 for right, -1 for left)
    local pos=0  # Starting position of the color window

    for ((i = 0; i < wave_length * 4; i++)); do  # Loop for multiple cycles
        printf "\r"  # Clear the line

        for ((j = 0; j < wave_length; j++)); do
            local char="${message:j:1}"

            # Apply color to characters within the moving window
            if ((j >= pos && j < pos + window_size)); then
                display_colorful_message "$char" "${color_cycle[color_index]}"
            else
                echo -n "$char"
            fi
        done

        # Change the color after each wave step
        color_index=$(((color_index + 1) % ${#color_cycle[@]}))

        # Move the position based on direction
        pos=$((pos + direction))

        # Reverse direction if we reach the start or the end of the string
        if ((pos + window_size >= wave_length || pos <= 0)); then
            direction=$((direction * -1))  # Reverse the direction
        fi

        delay 0.1  # Control the speed of the wave
    done

    echo ""  # Print a newline after the animation
}



# Fading effect
animate_fade() {
    local message="$1"

    for intensity in {0..255..15}; do
        printf "\r"
        echo -ne "\033[38;5;${intensity}m${message}\033[0m"
        delay 0.2  # Slower fading
    done
    echo ""
}

# Showtime!
clear
echo "🎉 Showtime! Enjoy the variety of animations! 🎉"
echo

# Animation sequence
animate_slide "Sliding Text Animation!"
animate_bounce "Bouncing Text Animation!"
animate_blink "Blinking Text Animation!"
animate_wave "Waving Text Animation!"
animate_fade "Fading Text Animation!"

# Concluding message
echo
echo "✨ The show has ended. Thanks for watching! ✨"
