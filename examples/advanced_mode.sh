#!/bin/bash
#
# Example: Advanced Mode Usage
#
# This example demonstrates using advanced mode for comprehensive file organization.
# Includes deduplication, archive extraction, date-based organization, and categorization.

# Advanced mode with default settings
# - Extracts archives
# - Organizes by category and date
# - Adds date prefixes to filenames
# - Persistent deduplication
../organize_and_dedup.sh --mode advanced -i /path/to/files -o /path/to/organized

# Advanced mode with custom hash algorithm
../organize_and_dedup.sh --mode advanced --hash-algorithm sha512 -i /path/to/files -o /path/to/organized

# Advanced mode without archive extraction
../organize_and_dedup.sh --mode advanced --extract-archives no -i /path/to/files -o /path/to/organized

# Advanced mode with move instead of copy
../organize_and_dedup.sh --mode advanced --action mv -i /path/to/files -o /path/to/organized
