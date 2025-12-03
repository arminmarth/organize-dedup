#!/bin/bash
# Test: Extension correction
# Verifies that wrong extensions are detected and corrected

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

# Create test files with wrong extensions
echo "This is a text file" > "$INPUT_DIR/wrong_ext.jpg"  # Text file labeled as jpg
echo "Correct text file" > "$INPUT_DIR/correct.txt"      # Correct extension

# Run script with fix-extensions
bash "$SCRIPT" --action cp --fix-extensions -i "$INPUT_DIR" -o "$OUTPUT_DIR" --extract-archives no --quiet

# Verify extension mismatch report was created
[[ -f "$OUTPUT_DIR/extension_mismatches.csv" ]] || { echo "Extension mismatch report not created"; exit 1; }

# Verify at least one mismatch was detected
mismatch_count=$(grep -c "wrong_ext" "$OUTPUT_DIR/extension_mismatches.csv" || true)
[[ $mismatch_count -gt 0 ]] || { echo "Extension mismatch not detected"; exit 1; }

# Verify corrected file has .txt extension
corrected_file=$(find "$OUTPUT_DIR" -type f -name "*txt" ! -name ".*" ! -name "*.csv" | grep -v "correct" | head -1)
[[ -n "$corrected_file" ]] || { echo "Corrected file not found"; exit 1; }

echo "✓ Extension correction test passed"
exit 0
