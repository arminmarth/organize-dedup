#!/bin/bash
#
# Example: Simple Mode Usage
#
# This example demonstrates using simple mode for fast checksum-based renaming.
# Perfect for quickly organizing a flat directory of files.

# Simple mode with default settings
# - Renames files to their checksums
# - Organizes by file extension
# - No date prefixes
# - No archive extraction
../organize_and_dedup.sh --mode simple -i /path/to/photos -o /path/to/renamed

# Simple mode with MD5 for speed
../organize_and_dedup.sh --mode simple --hash-algorithm md5 -i /path/to/videos -o /path/to/renamed

# Simple mode with verbose output
../organize_and_dedup.sh --mode simple -v -i /path/to/files -o /path/to/output
