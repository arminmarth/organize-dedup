#!/usr/bin/env bash
# Test helper for organize_and_dedup bats tests

# Get absolute path of a file/directory
abspath() {
    local path="$1"
    if [[ -d "$path" ]]; then
        (cd "$path" && pwd)
    else
        local dir base
        dir=$(dirname "$path")
        base=$(basename "$path")
        echo "$(cd "$dir" && pwd)/$base"
    fi
}

# Check if a command is available
has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# Count files in a directory (recursive)
count_files() {
    find "$1" -type f 2>/dev/null | wc -l
}

# Count files matching a pattern
count_files_matching() {
    local dir="$1"
    local pattern="$2"
    find "$dir" -type f -name "$pattern" 2>/dev/null | wc -l
}