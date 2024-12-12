#!/bin/bash

# Function to sort array1 based on the order of names in array2 using a specified key
sort_array_by_order() {
  local array1="$1"
  local order="$2"
  local key="$3"

  echo "$array1" | jq --argjson order "$order" --arg key "$key" '
    map( .[$key] as $name | {item: ., index: ( $order | index($name) // length) } ) |
    sort_by(.index) | map(.item)
  '
}

# Function to extract values based on a key
extract_values(){
    echo "$1" | jq -r "map(.$2)"
}

sort_array_according_to_other_array(){
    local array1="$1"
    local array2="$2"
    local key="$3"
    order="$(extract_values "$array2" "$key")"
    echo "$(sort_array_by_order "$array1" "$order" "$key")"
}

# Example Arrays
array1='[
  {"name": "item1", "value": "A"},
  {"name": "item2", "value": "B"},
  {"name": "item3", "value": "C"},
  {"name": "item4", "value": "D"}
]'

array2='[
  {"name": "item3", "value": "Z"},
  {"name": "item1", "value": "Y"},
  {"name": "item2", "value": "X"}
]'

# Extract values using the key "name" from array2
key="name"
echo "$(sort_array_according_to_other_array "$array1" "$array2" "$key")"