#!/usr/bin/env bash
# rename_directory.sh
# Summary: Rename a directory by converting its name to uppercase.
# Usage: bash rename_directory.sh <directory>

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

current_dir="$1"
new_dir=$(echo "$current_dir" | tr '[:lower:]' '[:upper:]')

# Perform rename
mv "$current_dir" "$new_dir"
echo "Directory name changed to $new_dir"

