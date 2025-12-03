#!/bin/bash
# Test: Softlink operation
# Verifies that symbolic links are created correctly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
SCRIPT="$REPO_DIR/organize_and_dedup.sh"

# Create test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

INPUT_DIR="$TEST_DIR/input"
OUTPUT_DIR="$TEST_DIR/output"

mkdir -p "$INPUT_DIR"

# Create test file
echo "test content for softlink" > "$INPUT_DIR/test.txt"

# Run script with softlink action
bash "$SCRIPT" --action softlink -i "$INPUT_DIR" -o "$OUTPUT_DIR" --extract-archives no --quiet

# Find the output file
output_file=$(find "$OUTPUT_DIR" -type l -name "*.txt" | head -1)
[[ -n "$output_file" ]] || { echo "Softlink not found"; exit 1; }

# Verify it's a symbolic link
[[ -L "$output_file" ]] || { echo "File is not a symbolic link"; exit 1; }

# Verify link target
link_target=$(readlink "$output_file")
[[ -n "$link_target" ]] || { echo "Link target is empty"; exit 1; }

# Verify content is accessible through link
output_content=$(cat "$output_file")
input_content=$(cat "$INPUT_DIR/test.txt")
[[ "$input_content" == "$output_content" ]] || { echo "Content mismatch"; exit 1; }

echo "✓ Softlink test passed"
exit 0
