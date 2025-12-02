#!/bin/bash

# Combined script to extract, deduplicate, rename, and organize files.
# - Extracts compressed files from the input directory
# - Deduplicates files based on SHA256 hash (persistent across all operations)
# - Normalizes file extensions
# - Adds date as prefix to filename
# - Organizes files into ./<category>/YYYY-MM/ directories
# - Supports specifying the input and output directories
#
# Usage: ./organize_and_dedup.sh [input_directory] [output_directory]
# If no directories are specified, defaults to the current directory for input and './export' for output.
#
# This version incorporates ALL recommendations from multiple code reviews:
# - File-based hash registry for persistent deduplication
# - Process substitution to avoid subshell variable issues
# - Prunes output directory from find to avoid reprocessing
# - Fixed category overlaps and duplicates
# - Option to copy instead of move (safer)
# - Improved date parsing robustness
# - Better error handling and logging
# - Exact hash matching with grep -x
# - Correct output directory path checking
# - Accurate statistics tracking
# - Working directory management

set -euo pipefail

# ==================== CONFIGURATION ====================

# ACTION: Set to "cp" to copy files (safer), or "mv" to move files (destructive)
ACTION="${ACTION:-cp}"  # Can be overridden with: ACTION=mv ./script.sh

# Strict tool checking: Set to "true" to exit if tools are missing, "false" to warn only
STRICT_TOOLS="${STRICT_TOOLS:-false}"

# ==================== FUNCTIONS ====================

# Function to check if required tools are installed
check_tools() {
  local tools=(unzip tar sha256sum exiftool file)
  local optional_tools=(unrar 7z gunzip bunzip2 unxz)
  local missing=()
  
  # Check required tools
  for tool in "${tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      missing+=("$tool")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Required tools missing: ${missing[*]}"
    echo "Please install them and try again."
    exit 1
  fi
  
  # Check optional tools
  for tool in "${optional_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      if [[ "$STRICT_TOOLS" == "true" ]]; then
        echo "Error: Optional tool '$tool' is not installed (STRICT_TOOLS=true)."
        exit 1
      else
        echo "Warning: Optional tool '$tool' is not installed. Some archive types may not be processed."
      fi
    fi
  done
}

# Call the function to check tools
check_tools

# ==================== SETUP ====================

# Save original working directory
original_pwd=$(pwd)

# Set input and output directories from arguments or defaults
if [[ -n "${1:-}" ]]; then
  input_dir="$1"
else
  input_dir="."  # Default to current directory
fi

if [[ -n "${2:-}" ]]; then
  output_dir="$2"
else
  output_dir="./export"
fi

# Convert to absolute paths to avoid issues with relative paths
# FIX: Don't change working directory permanently
input_dir=$(cd "$input_dir" && pwd)
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)

# Return to original directory
cd "$original_pwd"

echo "Input directory: $input_dir"
echo "Output directory: $output_dir"
echo "Action: $ACTION (copy/move files)"
echo ""

# Set log file
log_file="$output_dir/processing.log"
export log_file

# Set temporary directory (in original working directory, not output)
tmp_dir="$original_pwd/tmp_organize"
mkdir -p "$tmp_dir"
temp_dir=$(mktemp -d -p "$tmp_dir")

# File-based hash registry for persistent deduplication across all operations
hash_registry="$output_dir/.hash_registry.txt"
touch "$hash_registry"
export hash_registry

# Statistics tracking
declare -g files_processed=0
declare -g duplicates_skipped=0
export files_processed duplicates_skipped

# Cleanup function
cleanup() {
  echo ""
  echo "Cleaning up temporary files..."
  rm -rf "$temp_dir"
  # Remove tmp_dir if empty
  rmdir "$tmp_dir" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# ==================== HASH FUNCTIONS ====================

# Function to check if hash exists in registry
# FIX: Use -x for exact line matching to avoid substring false positives
hash_exists() {
  local hash="$1"
  grep -qxF "$hash" "$hash_registry" 2>/dev/null
}

# Function to add hash to registry
add_hash() {
  local hash="$1"
  echo "$hash" >> "$hash_registry"
}

# Export hash functions
export -f hash_exists
export -f add_hash

# ==================== NORMALIZATION FUNCTIONS ====================

# Function to normalize file extension
normalize_extension() {
  local ext="${1,,}"  # Convert to lowercase
  case "$ext" in
    # Images
    jpg|jpeg|jpe|jfif) echo "jpg" ;;
    tif|tiff) echo "tiff" ;;
    heic|heif) echo "heic" ;;
    jp2|j2c|j2k|jpx|jpf) echo "jp2" ;;
    # Raw image formats
    cr2|cr3|crw|dng|nef|nrw|raf|rw2|x3f|mrw|orf|arw|srf|sr2|pef|raw) echo "raw" ;;
    # Audio
    m4a|m4b|m4p) echo "m4a" ;;
    oga|ogg) echo "ogg" ;;
    aif|aiff|aifc) echo "aif" ;;
    mp3|mp2|mpga) echo "mp3" ;;
    # Video
    mp4|m4v|f4v|f4p|f4a|f4b) echo "mp4" ;;
    rm|ram|ra) echo "rm" ;;
    mts|m2ts|m2t) echo "mts" ;;
    mkv|mk3d|mks|mka) echo "mkv" ;;
    mov|qt) echo "mov" ;;
    # Programming
    pyc|pyo|pyx|pyi|pyd) echo "py" ;;
    c++|cc|cxx) echo "cpp" ;;
    hpp|hxx|h++) echo "h" ;;
    # Web
    htm|html) echo "html" ;;
    xhtml|xht) echo "html" ;;
    # Documents
    md|markdown|mdown|mkd) echo "md" ;;
    # TypeScript
    ts|tsx) echo "ts" ;;
    # Default: return as-is
    *) echo "$ext" ;;
  esac
}

# Function to categorize files based on extension
# NOTE: Order matters! First match wins.
get_category() {
  local ext="$1"
  case "$ext" in
    # Certificates (must come before configs to avoid overlap)
    pem|crt|cer|der|pfx|p12|key|csr|p7b|p7c)
      echo "certificates" ;;
    
    # Configurations (must come before scripts to catch config files)
    ini|conf|config|cfg|properties|toml|plist|gitignore|eslintignore|htaccess|bashrc|bash_profile|bash_logout|lock|env|editorconfig)
      echo "configs" ;;
    
    # Structured data (must come before scripts)
    json|yaml|yml|xml)
      echo "configs" ;;
    
    # Images
    jpg|png|tiff|bmp|gif|heic|webp|svg|ico|psd|ai|eps|raw|jp2|exr|hdr|indd|dcm|cpt|xcf|flif|fits|bpg|tga|pcx|ppm|pgm|pbm|pnm)
      echo "images" ;;
    
    # Videos
    mp4|mkv|webm|avi|mov|wmv|flv|mpeg|mpg|m4v|3gp|3g2|mts|m2ts|asf|rm|swf|f4v|f4p|f4a|f4b|mxf|ts|dv|ogv|vob)
      echo "videos" ;;
    
    # Audios
    mp3|wav|flac|aac|ogg|m4a|wma|aif|ape|opus|aa|midi|mid|ra|amr|tta|dts|ac3)
      echo "audios" ;;
    
    # Documents
    pdf|doc|docx|odt|rtf|txt|md|epub|mobi|azw3|xls|xlsx|ods|ppt|pptx|odp|csv|ics|vcf|eml|djvu|chm|rst|odg|html|xhtml)
      echo "documents" ;;
    
    # Scripts and code (after configs to avoid overlap)
    sh|bash|bat|cmd|ps1|py|pl|rb|java|c|cpp|h|cs|go|rs|php|css|js|ts|ipynb|r|kt|swift|lua|perl|sql|awk|sed|vim|el|clj|scala|groovy|vb|vbs|asm|s|f|f90|pas|tcl|m|mm)
      echo "scripts" ;;
    
    # Archives (jar is here, not in scripts or applications)
    zip|rar|7z|tar|gz|bz2|xz|tgz|tbz2|txz|lz|lzma|z|zst|iso|img|dmg|apk|jar|aar|deb|rpm|cab|arj|lzh|ace|zoo|arc|pak|wim)
      echo "archives" ;;
    
    # Fonts
    ttf|otf|woff|woff2|eot|afm|pfb|pfm|fnt|fntdata|dfont|fon|ttc)
      echo "fonts" ;;
    
    # Databases
    db|db3|sqlite|sqlite3|accdb|mdb|db-shm|db-wal|sqlite-shm|sqlite-wal|pdb|dbf|mdf|ldf|frm|ibd)
      echo "databases" ;;
    
    # Applications/Executables (after archives to avoid apk/jar overlap)
    exe|dll|bin|com|app|msi|run|so|dylib|bundle)
      echo "applications" ;;
    
    # Backups
    bak|tmp|old|backup|orig|swp|swo|~)
      echo "backups" ;;
    
    # Others
    *)
      echo "others" ;;
  esac
}

# Export functions for use in subshells
export -f normalize_extension
export -f get_category

# ==================== EXTRACTION FUNCTION ====================

# Function to extract compressed files
extract_file() {
  local file="$1"
  local dest_dir="$2"

  case "$file" in
    *.zip)
      if command -v unzip &> /dev/null && unzip -t "$file" > /dev/null 2>&1; then
        echo "Extracting ZIP: $file"
        unzip -o "$file" -d "$dest_dir" >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
      else
        echo "Cannot extract ZIP (invalid or unzip not installed): $file" | tee -a "$log_file"
      fi
      ;;
    *.tar.gz|*.tgz)
      if tar -tzf "$file" > /dev/null 2>&1; then
        echo "Extracting TAR.GZ: $file"
        tar -xzf "$file" -C "$dest_dir" --warning=no-unknown-keyword >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
      else
        echo "Cannot extract TAR.GZ (invalid): $file" | tee -a "$log_file"
      fi
      ;;
    *.rar)
      if command -v unrar &> /dev/null && unrar t "$file" > /dev/null 2>&1; then
        echo "Extracting RAR: $file"
        unrar x -o+ "$file" "$dest_dir" >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
      else
        echo "Cannot extract RAR (invalid or unrar not installed): $file" | tee -a "$log_file"
      fi
      ;;
    *.tar.bz2|*.tbz2)
      if tar -tjf "$file" > /dev/null 2>&1; then
        echo "Extracting TAR.BZ2: $file"
        tar -xjf "$file" -C "$dest_dir" --warning=no-unknown-keyword >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
      else
        echo "Cannot extract TAR.BZ2 (invalid): $file" | tee -a "$log_file"
      fi
      ;;
    *.tar.xz|*.txz)
      if tar -tJf "$file" > /dev/null 2>&1; then
        echo "Extracting TAR.XZ: $file"
        tar -xJf "$file" -C "$dest_dir" --warning=no-unknown-keyword >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
      else
        echo "Cannot extract TAR.XZ (invalid): $file" | tee -a "$log_file"
      fi
      ;;
    *.7z)
      if command -v 7z &> /dev/null && 7z t "$file" > /dev/null 2>&1; then
        echo "Extracting 7Z: $file"
        7z x "$file" -o"$dest_dir" >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
      else
        echo "Cannot extract 7Z (invalid or 7z not installed): $file" | tee -a "$log_file"
      fi
      ;;
    *.gz)
      if command -v gunzip &> /dev/null && gzip -t "$file" > /dev/null 2>&1; then
        echo "Extracting GZ: $file"
        gunzip -c "$file" > "$dest_dir/$(basename "${file%.gz}")" 2>> "$log_file" || echo "Error extracting $file" | tee -a "$log_file"
      else
        echo "Cannot extract GZ (invalid or gunzip not installed): $file" | tee -a "$log_file"
      fi
      ;;
    *.bz2)
      if command -v bunzip2 &> /dev/null && bzip2 -t "$file" > /dev/null 2>&1; then
        echo "Extracting BZ2: $file"
        bunzip2 -c "$file" > "$dest_dir/$(basename "${file%.bz2}")" 2>> "$log_file" || echo "Error extracting $file" | tee -a "$log_file"
      else
        echo "Cannot extract BZ2 (invalid or bunzip2 not installed): $file" | tee -a "$log_file"
      fi
      ;;
    *.xz)
      if command -v unxz &> /dev/null && xz -t "$file" > /dev/null 2>&1; then
        echo "Extracting XZ: $file"
        unxz -c "$file" > "$dest_dir/$(basename "${file%.xz}")" 2>> "$log_file" || echo "Error extracting $file" | tee -a "$log_file"
      else
        echo "Cannot extract XZ (invalid or unxz not installed): $file" | tee -a "$log_file"
      fi
      ;;
    *.tar)
      if tar -tf "$file" > /dev/null 2>&1; then
        echo "Extracting TAR: $file"
        tar -xf "$file" -C "$dest_dir" --warning=no-unknown-keyword >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
      else
        echo "Cannot extract TAR (invalid): $file" | tee -a "$log_file"
      fi
      ;;
    *)
      echo "Unsupported archive type: $file" | tee -a "$log_file"
      ;;
  esac
}

export -f extract_file

# ==================== FILE PROCESSING FUNCTION ====================

# Function to process each file
process_file() {
  local file="$1"

  # Skip if not a regular file
  if [[ ! -f "$file" ]]; then
    return
  fi

  # FIX: Correct output directory check - must include trailing slash
  # to avoid matching paths that start with the same string
  if [[ "$file" == "$output_dir"/* ]]; then
    return
  fi

  echo "Processing: $file"

  # Calculate SHA256 hash
  local hash
  if ! hash=$(sha256sum "$file" 2>> "$log_file"); then
    echo "Error calculating hash for $file" | tee -a "$log_file"
    return
  fi
  hash=$(echo "$hash" | awk '{print toupper($1)}')

  # Check for duplicates using file-based registry
  if hash_exists "$hash"; then
    echo "Duplicate skipped: $file (hash: $hash)" | tee -a "$log_file"
    ((duplicates_skipped++)) || true
    return
  fi

  # Add hash to registry immediately (before copy/move)
  # NOTE: If copy/move fails, hash is still recorded. This is intentional
  # to avoid re-hashing the same file on subsequent runs.
  add_hash "$hash"

  # Get the file extension and normalize it
  local filename=$(basename "$file")
  local raw_extension="${filename##*.}"
  local extension=""
  
  # Handle dotfiles and files without extensions
  if [[ "$filename" == .* ]] && [[ "$filename" != *.*.* ]]; then
    # This is a dotfile with no extension (e.g., .bashrc)
    extension=""
  elif [[ "$filename" == "$raw_extension" ]]; then
    # No extension
    extension=""
  else
    extension=$(normalize_extension "$raw_extension")
  fi

  # Get the category
  local category
  if [[ -n "$extension" ]]; then
    category=$(get_category "$extension")
  else
    category="others"
  fi

  # Get date and time from EXIF or file metadata
  local datetime=""
  datetime=$(exiftool -s3 -DateTimeOriginal "$file" 2>/dev/null || true)
  
  if [[ -z "$datetime" ]]; then
    datetime=$(exiftool -s3 -CreateDate "$file" 2>/dev/null || true)
  fi
  
  if [[ -z "$datetime" ]]; then
    # Use file modification date as fallback
    if [[ "$(uname)" == "Darwin" ]]; then
      datetime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || true)
    else
      # Linux: Remove fractional seconds and timezone for robustness
      datetime=$(stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1 | cut -d'+' -f1 || true)
    fi
  fi
  
  # Final fallback: use current date
  if [[ -z "$datetime" ]]; then
    echo "Warning: Unable to get date for '$file'. Using current date." | tee -a "$log_file"
    datetime=$(date "+%Y-%m-%d %H:%M:%S")
  fi

  # Clean datetime string for filename
  # Convert "2023:10:20 14:00:00" or "2023-10-20 14:00:00" to "2023-10-20_14-00-00"
  local clean_dt=$(echo "$datetime" | tr ':' '-' | tr ' ' '_')
  
  # Extract year-month for directory structure
  local year_month=$(echo "$clean_dt" | cut -d'_' -f1 | cut -d'-' -f1-2)

  # Create the destination directory
  local dest_dir="$output_dir/$category/$year_month"
  if ! mkdir -p "$dest_dir"; then
    echo "Error creating directory $dest_dir" | tee -a "$log_file"
    return
  fi

  # Construct the destination file path
  local new_filename
  if [[ -n "$extension" ]]; then
    new_filename="${clean_dt}_${hash}.${extension}"
  else
    new_filename="${clean_dt}_${hash}"
  fi
  local dest_file="$dest_dir/$new_filename"

  # Check if destination file already exists (collision detection)
  if [[ -e "$dest_file" ]]; then
    echo "Warning: Destination file already exists: $dest_file" | tee -a "$log_file"
    return
  fi

  # Copy or move the file
  if [[ "$ACTION" == "mv" ]]; then
    if mv "$file" "$dest_file"; then
      echo "Moved: $file -> $dest_file" | tee -a "$log_file"
      ((files_processed++)) || true
    else
      echo "Error moving: $file -> $dest_file" | tee -a "$log_file"
    fi
  else
    if cp -p "$file" "$dest_file"; then
      echo "Copied: $file -> $dest_file" | tee -a "$log_file"
      ((files_processed++)) || true
    else
      echo "Error copying: $file -> $dest_file" | tee -a "$log_file"
    fi
  fi
}

export -f process_file

# ==================== MAIN EXECUTION ====================

echo "======================================" | tee -a "$log_file"
echo "Starting file organization process" | tee -a "$log_file"
echo "Date: $(date)" | tee -a "$log_file"
echo "======================================" | tee -a "$log_file"
echo "" | tee -a "$log_file"

# Record starting hash count for accurate statistics
start_hash_count=$(wc -l < "$hash_registry" 2>/dev/null || echo 0)

# Count total files for progress reporting
# FIX: Handle find errors gracefully with set -e
echo "Scanning input directory..." | tee -a "$log_file"
set +e
total_files=$(find "$input_dir" -type f 2>/dev/null | wc -l || echo 0)
set -e
echo "Found $total_files files in input directory" | tee -a "$log_file"
echo "" | tee -a "$log_file"

# PHASE 1: Extract all compressed files
echo "======================================" | tee -a "$log_file"
echo "PHASE 1: Extracting archives" | tee -a "$log_file"
echo "======================================" | tee -a "$log_file"

# Use process substitution to avoid subshell issues
while IFS= read -r -d '' file; do
  extract_file "$file" "$temp_dir"
done < <(find "$input_dir" -type f \( \
  -iname "*.zip" -o -iname "*.tar.gz" -o -iname "*.tgz" -o \
  -iname "*.rar" -o -iname "*.tar.bz2" -o -iname "*.tbz2" -o \
  -iname "*.tar.xz" -o -iname "*.txz" -o -iname "*.7z" -o \
  -iname "*.gz" -o -iname "*.bz2" -o -iname "*.xz" -o -iname "*.tar" \
\) -print0 2>/dev/null)

echo "" | tee -a "$log_file"

# PHASE 2: Process archive files themselves
echo "======================================" | tee -a "$log_file"
echo "PHASE 2: Organizing archive files" | tee -a "$log_file"
echo "======================================" | tee -a "$log_file"

while IFS= read -r -d '' file; do
  process_file "$file"
done < <(find "$input_dir" -type f \( \
  -iname "*.zip" -o -iname "*.tar.gz" -o -iname "*.tgz" -o \
  -iname "*.rar" -o -iname "*.tar.bz2" -o -iname "*.tbz2" -o \
  -iname "*.tar.xz" -o -iname "*.txz" -o -iname "*.7z" -o \
  -iname "*.gz" -o -iname "*.bz2" -o -iname "*.xz" -o -iname "*.tar" \
\) -print0 2>/dev/null)

echo "" | tee -a "$log_file"

# PHASE 3: Process all non-archive files (from input and extracted)
echo "======================================" | tee -a "$log_file"
echo "PHASE 3: Organizing all other files" | tee -a "$log_file"
echo "======================================" | tee -a "$log_file"

# Prune output_dir to avoid reprocessing already-organized files
while IFS= read -r -d '' file; do
  process_file "$file"
done < <(find "$input_dir" "$temp_dir" \
  -path "$output_dir" -prune -o \
  -type f ! \( \
    -iname "*.zip" -o -iname "*.tar.gz" -o -iname "*.tgz" -o \
    -iname "*.rar" -o -iname "*.tar.bz2" -o -iname "*.tbz2" -o \
    -iname "*.tar.xz" -o -iname "*.txz" -o -iname "*.7z" -o \
    -iname "*.gz" -o -iname "*.bz2" -o -iname "*.xz" -o -iname "*.tar" \
  \) -print0 2>/dev/null)

echo "" | tee -a "$log_file"

# ==================== COMPLETION ====================

echo "======================================" | tee -a "$log_file"
echo "Processing complete!" | tee -a "$log_file"
echo "======================================" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "Output directory: $output_dir" | tee -a "$log_file"
echo "Log file: $log_file" | tee -a "$log_file"
echo "Hash registry: $hash_registry" | tee -a "$log_file"
echo "" | tee -a "$log_file"

# FIX: Accurate statistics
end_hash_count=$(wc -l < "$hash_registry" 2>/dev/null || echo 0)
new_unique_files=$((end_hash_count - start_hash_count))

echo "Summary:" | tee -a "$log_file"
echo "--------" | tee -a "$log_file"
echo "Files in input directory: $total_files" | tee -a "$log_file"
echo "New unique files this run: $new_unique_files" | tee -a "$log_file"
echo "Files successfully processed: $files_processed" | tee -a "$log_file"
echo "Duplicates skipped this run: $duplicates_skipped" | tee -a "$log_file"
echo "Total unique hashes in registry (all runs): $end_hash_count" | tee -a "$log_file"
echo "" | tee -a "$log_file"

# Show category breakdown
echo "Files by category:" | tee -a "$log_file"
set +e
for category_dir in "$output_dir"/*; do
  if [[ -d "$category_dir" ]] && [[ "$(basename "$category_dir")" != ".*" ]]; then
    category=$(basename "$category_dir")
    count=$(find "$category_dir" -type f 2>/dev/null | wc -l || echo 0)
    if [[ $count -gt 0 ]]; then
      echo "  $category: $count files" | tee -a "$log_file"
    fi
  fi
done
set -e

echo "" | tee -a "$log_file"
echo "Done!" | tee -a "$log_file"
