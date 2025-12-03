#!/bin/bash
# Test: Basic copy operation
# Verifies that files are copied and organized correctly

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
echo "test file 1" > "$INPUT_DIR/file1.txt"
echo "test file 2" > "$INPUT_DIR/file2.txt"
echo "test file 3" > "$INPUT_DIR/file3.dat"

# Run script
bash "$SCRIPT" --action cp -i "$INPUT_DIR" -o "$OUTPUT_DIR" --extract-archives no --quiet

# Verify output directory exists
[[ -d "$OUTPUT_DIR" ]] || { echo "Output directory not created"; exit 1; }

# Verify files were processed
file_count=$(find "$OUTPUT_DIR" -type f ! -name ".*" ! -name "*.log" ! -name "*.csv" | wc -l)
[[ $file_count -eq 3 ]] || { echo "Expected 3 files, found $file_count"; exit 1; }

# Verify original files still exist
[[ -f "$INPUT_DIR/file1.txt" ]] || { echo "Original file1.txt missing"; exit 1; }
[[ -f "$INPUT_DIR/file2.txt" ]] || { echo "Original file2.txt missing"; exit 1; }
[[ -f "$INPUT_DIR/file3.dat" ]] || { echo "Original file3.dat missing"; exit 1; }

echo "✓ Basic copy test passed"
exit 0
