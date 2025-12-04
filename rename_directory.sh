#!/bin/bash

# Check if the directory argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

current_dir="$1"

# Convert the directory name to uppercase
new_dir=$(echo "$current_dir" | tr '[:lower:]' '[:upper:]')

# Rename the directory
mv "$current_dir" "$new_dir"

echo "Directory name changed to $new_dir"

