#!/bin/bash
#
# Example: Custom Configuration
#
# This example demonstrates custom configurations mixing and matching options.

# Organize by extension only (no categories, no dates)
../organize_and_dedup.sh \
    --organize-by extension \
    --naming-format hash_ext \
    -i /path/to/files \
    -o /path/to/output

# Organize by date only (no categories)
../organize_and_dedup.sh \
    --organize-by date \
    --naming-format date_hash_ext \
    -i /path/to/photos \
    -o /path/to/output

# Flat directory with date prefixes
../organize_and_dedup.sh \
    --organize-by none \
    --naming-format date_hash_ext \
    -i /path/to/files \
    -o /path/to/output

# Use MD5 for large video files (faster)
../organize_and_dedup.sh \
    --hash-algorithm md5 \
    --organize-by category \
    -i /path/to/videos \
    -o /path/to/organized

# Disable deduplication (process all files)
../organize_and_dedup.sh \
    --deduplicate no \
    -i /path/to/files \
    -o /path/to/output

# Non-recursive processing (flat directory only)
../organize_and_dedup.sh \
    --recursive no \
    -i /path/to/files \
    -o /path/to/output
