#!/bin/bash

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

boxed_text() {
local word=${1}          # Word to render
local font=${2:-slant}  # Default font is 'slant'
local min_width=${3:-80}  # Default minimum width is 80
local style=${4:-simple}  # Default border style is 'simple'

# Define the border styles
declare -A border_styles=(
["simple"]="- - | | + + + +"
["asterisk"]="* * * * * * * *"
["equal"]="= = | | + + + +"
["hash"]="# # # # # # # #"
["dotted"]=". . . . . . . ."
["starred"]="* * * * * * * *"
["boxed-dashes"]="- - - - - - - -"
["wave"]="~ ~ ~ ~ ~ ~ ~ ~"
["none"]="         "
)

# Extract the border characters
IFS=' ' read -r top_fence bottom_fence left_fence right_fence top_left_corner top_right_corner bottom_left_corner bottom_right_corner <<< "${border_styles[$style]}"

# Get the terminal width
terminal_width=$(tput cols)

# Generate the ASCII art
ascii_art=$(figlet -f "$font" "$word")

# Calculate the width of the ASCII art
art_width=$(echo "$ascii_art" | head -n 1 | wc -c)
art_width=$((art_width - 1))  # Subtract 1 to account for the newline character

# Determine the maximum width for borders (account for left/right fences)
max_border_width=$((terminal_width - 2))  # Subtract 2 for left and right fences
total_width=$((min_width > art_width ? min_width : art_width))

# Ensure the total width does not exceed terminal width
total_width=$((total_width > max_border_width ? max_border_width : total_width))

# Generate the top and bottom borders
top_border=$(printf "%s%s%s" "$top_left_corner" "$(printf "%${total_width}s" | tr ' ' "$top_fence")" "$top_right_corner")
bottom_border=$(printf "%s%s%s" "$bottom_left_corner" "$(printf "%${total_width}s" | tr ' ' "$bottom_fence")" "$bottom_right_corner")

# Print the top border
echo -e "$top_border"

# Print the ASCII art with left and right borders
while IFS= read -r line_content; do
   line_length=${#line_content}
   padding_left=$(( (total_width - line_length) / 2 ))
   padding_right=$(( total_width - padding_left - line_length ))
   printf "%s%*s%s%*s%s\n" "$left_fence" "$padding_left" "" "$line_content" "$padding_right" "" "$right_fence"
done <<< "$ascii_art"

# Print the bottom border
echo -e "$bottom_border"
}

export parse_yaml
export boxed_text