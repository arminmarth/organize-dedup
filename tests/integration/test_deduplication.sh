#!/bin/bash
# Test: Deduplication
# Verifies that duplicate files are detected and skipped

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

# Create duplicate files (same content, different names)
echo "duplicate content" > "$INPUT_DIR/file1.txt"
echo "duplicate content" > "$INPUT_DIR/file2.txt"
echo "unique content" > "$INPUT_DIR/file3.txt"

# Run script with deduplication enabled
bash "$SCRIPT" --action cp --deduplicate yes -i "$INPUT_DIR" -o "$OUTPUT_DIR" --extract-archives no --quiet

# Count output files (excluding metadata)
file_count=$(find "$OUTPUT_DIR" -type f ! -name ".*" ! -name "*.log" ! -name "*.csv" | wc -l)

# Should only have 2 files (one duplicate removed)
[[ $file_count -eq 2 ]] || { echo "Expected 2 files (1 duplicate removed), found $file_count"; exit 1; }

# Verify hash registry exists and has 2 entries
hash_registry="$OUTPUT_DIR/.hash_registry_sha256.txt"
[[ -f "$hash_registry" ]] || { echo "Hash registry not created"; exit 1; }

hash_count=$(wc -l < "$hash_registry")
[[ $hash_count -eq 2 ]] || { echo "Expected 2 hashes, found $hash_count"; exit 1; }

echo "✓ Deduplication test passed"
exit 0
