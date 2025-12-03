#!/bin/bash
# Test: Hardlink operation
# Verifies that hardlinks are created correctly with same inode

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
echo "test content for hardlink" > "$INPUT_DIR/test.txt"

# Run script with hardlink action
bash "$SCRIPT" --action hardlink -i "$INPUT_DIR" -o "$OUTPUT_DIR" --extract-archives no --quiet

# Find the output file
output_file=$(find "$OUTPUT_DIR" -type f -name "*.txt" ! -name ".*" | head -1)
[[ -n "$output_file" ]] || { echo "Output file not found"; exit 1; }

# Get inode numbers
input_inode=$(stat -c %i "$INPUT_DIR/test.txt")
output_inode=$(stat -c %i "$output_file")

# Verify same inode (hardlink)
[[ "$input_inode" == "$output_inode" ]] || { echo "Inodes don't match: $input_inode != $output_inode"; exit 1; }

# Verify link count is 2
link_count=$(stat -c %h "$INPUT_DIR/test.txt")
[[ "$link_count" == "2" ]] || { echo "Link count should be 2, got $link_count"; exit 1; }

# Verify content is the same
input_content=$(cat "$INPUT_DIR/test.txt")
output_content=$(cat "$output_file")
[[ "$input_content" == "$output_content" ]] || { echo "Content mismatch"; exit 1; }

echo "✓ Hardlink test passed"
exit 0
