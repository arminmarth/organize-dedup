#!/bin/bash
# Test: Only mismatched extensions
# Verifies that only files with wrong extensions are processed

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

# Create test files
echo "Text file with wrong extension" > "$INPUT_DIR/wrong.jpg"  # Wrong extension
echo "Text file with correct extension" > "$INPUT_DIR/correct.txt"  # Correct extension

# Run script with only-mismatched-extensions
bash "$SCRIPT" --action cp --only-mismatched-extensions --fix-extensions -i "$INPUT_DIR" -o "$OUTPUT_DIR" --extract-archives no --quiet

# Count output files (excluding metadata)
file_count=$(find "$OUTPUT_DIR" -type f ! -name ".*" ! -name "*.log" ! -name "*.csv" | wc -l)

# Should only have 1 file (the one with wrong extension)
[[ $file_count -eq 1 ]] || { echo "Expected 1 file, found $file_count"; exit 1; }

# Verify the correct file was NOT processed
correct_file=$(find "$OUTPUT_DIR" -type f -name "*correct*" 2>/dev/null | wc -l)
[[ $correct_file -eq 0 ]] || { echo "Correct file should not be processed"; exit 1; }

echo "✓ Only mismatched extensions test passed"
exit 0
