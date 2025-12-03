#!/bin/bash

# organize_and_dedup.sh - v2.1.0
# 
# A comprehensive file organization and deduplication tool with multiple modes:
# - Simple mode: Fast checksum-based renaming with extension organization
# - Advanced mode: Full deduplication, archive extraction, date-based categorization
#
# Author: Armin Marth
# Version: 2.0.2
# License: MIT

set -euo pipefail

# ==================== VERSION ====================

VERSION="2.1.1"

# ==================== DEFAULT CONFIGURATION ====================

# Mode: simple or advanced
MODE="${MODE:-advanced}"

# Directories
INPUT_DIR=""
OUTPUT_DIR=""

# Action: cp (copy) or mv (move)
ACTION="${ACTION:-cp}"

# Hash algorithm: sha1, sha256, sha512, md5
HASH_ALGORITHM="${HASH_ALGORITHM:-sha256}"

# Naming format: hash, hash_ext, date_hash_ext
NAMING_FORMAT="${NAMING_FORMAT:-date_hash_ext}"

# Organization: none, extension, category, date, category_date
ORGANIZE_BY="${ORGANIZE_BY:-category_date}"

# Archive extraction: yes or no
EXTRACT_ARCHIVES="${EXTRACT_ARCHIVES:-yes}"

# Recursive processing: yes or no
RECURSIVE="${RECURSIVE:-yes}"

# Deduplication: yes or no
DEDUPLICATE="${DEDUPLICATE:-yes}"

# Strict tool checking
STRICT_TOOLS="${STRICT_TOOLS:-false}"

# Extension correction: yes or no
FIX_EXTENSIONS="${FIX_EXTENSIONS:-no}"

# Strict extensions: yes or no (only process files with correct extensions)
STRICT_EXTENSIONS="${STRICT_EXTENSIONS:-no}"

# Report extensions: yes or no (generate mismatch report only)
REPORT_EXTENSIONS="${REPORT_EXTENSIONS:-no}"

# Verbosity
VERBOSE=false
QUIET=false

# ==================== HELP TEXT ====================

show_help() {
    cat << EOF
organize_and_dedup.sh - v$VERSION

A comprehensive file organization and deduplication tool.

USAGE:
    organize_and_dedup.sh [OPTIONS]
    organize_and_dedup.sh [input_dir] [output_dir]  # Legacy format

MODES:
    --mode simple      Fast checksum renaming with extension organization
    --mode advanced    Full deduplication, archives, dates, categories (default)

CORE OPTIONS:
    -i, --input-dir DIR        Input directory (default: .)
    -o, --output-dir DIR       Output directory (default: ./export)
    -a, --action ACTION        Action: cp (copy) or mv (move) [default: cp]

HASH OPTIONS:
    --hash-algorithm ALG       Hash: sha1, sha256, sha512, md5 [default: sha256]

NAMING OPTIONS:
    --naming-format FMT        Format: hash, hash_ext, date_hash_ext [default: date_hash_ext]
                               hash           → abc123...
                               hash_ext       → abc123....jpg
                               date_hash_ext  → 2024-12-02_14-30-00_abc123....jpg

ORGANIZATION OPTIONS:
    --organize-by METHOD       Method: none, extension, category, date, category_date
                               [default: category_date]
                               none           → Flat directory
                               extension      → By file extension (jpg/, png/, etc.)
                               category       → By category (images/, videos/, etc.)
                               date           → By date (2024-12/, etc.)
                               category_date  → By category and date (images/2024-12/)

PROCESSING OPTIONS:
    --extract-archives BOOL    Extract archives: yes, no [default: yes in advanced mode]
    --recursive BOOL           Process subdirectories: yes, no [default: yes]
    --deduplicate BOOL         Enable deduplication: yes, no [default: yes]

EXTENSION CORRECTION OPTIONS:
    --fix-extensions yes|no    Automatically correct wrong extensions based on content [default: no]
    --strict-extensions yes|no Skip files with incorrect extensions [default: no]
    --report-extensions yes|no Generate mismatch report without processing [default: no]
                               Note: These options require 'yes' or 'no' value

TOOL OPTIONS:
    --strict-tools BOOL        Require all tools: yes, no [default: no]

OUTPUT OPTIONS:
    -v, --verbose              Verbose output
    -q, --quiet                Minimal output
    -h, --help                 Show this help message
    --version                  Show version

EXAMPLES:
    # Simple mode - fast checksum renaming
    organize_and_dedup.sh --mode simple -i /photos -o /renamed

    # Advanced mode - full organization
    organize_and_dedup.sh --mode advanced -i /photos -o /organized

    # Use MD5 for speed on large files
    organize_and_dedup.sh --hash-algorithm md5 -i /videos -o /organized

    # Organize by extension only, no date prefixes
    organize_and_dedup.sh --organize-by extension --naming-format hash_ext

    # Move files instead of copy
    organize_and_dedup.sh -i /input -o /output --action mv

    # Fix wrong file extensions automatically
    organize_and_dedup.sh -i /input -o /output --fix-extensions yes

    # Generate report of extension mismatches
    organize_and_dedup.sh -i /input -o /output --report-extensions yes

    # Legacy format (still supported)
    organize_and_dedup.sh /input /output
    ACTION=mv organize_and_dedup.sh /input /output

SIMPLE MODE PRESETS:
    --mode simple sets:
      --naming-format hash_ext
      --organize-by extension
      --extract-archives no
      --recursive no

ADVANCED MODE PRESETS:
    --mode advanced sets:
      --naming-format date_hash_ext
      --organize-by category_date
      --extract-archives yes
      --recursive yes

For more information, see: https://github.com/arminmarth/organize-dedup

EOF
}

# ==================== ARGUMENT PARSING ====================

parse_arguments() {
    # Handle no arguments
    if [[ $# -eq 0 ]]; then
        echo "Error: No arguments provided."
        echo "Try 'organize_and_dedup.sh --help' for more information."
        exit 1
    fi

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                echo "organize_and_dedup.sh version $VERSION"
                exit 0
                ;;
            --mode)
                MODE="$2"
                shift 2
                ;;
            -i|--input-dir)
                INPUT_DIR="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -a|--action)
                ACTION="$2"
                shift 2
                ;;
            --hash-algorithm)
                HASH_ALGORITHM="$2"
                shift 2
                ;;
            --naming-format)
                NAMING_FORMAT="$2"
                NAMING_FORMAT_SET=true
                shift 2
                ;;
            --organize-by)
                ORGANIZE_BY="$2"
                ORGANIZE_BY_SET=true
                shift 2
                ;;
            --extract-archives)
                EXTRACT_ARCHIVES="$2"
                EXTRACT_ARCHIVES_SET=true
                shift 2
                ;;
            --recursive)
                RECURSIVE="$2"
                RECURSIVE_SET=true
                shift 2
                ;;
            --deduplicate)
                DEDUPLICATE="$2"
                shift 2
                ;;
            --fix-extensions)
                FIX_EXTENSIONS="$2"
                shift 2
                ;;
            --strict-extensions)
                STRICT_EXTENSIONS="$2"
                shift 2
                ;;
            --report-extensions)
                REPORT_EXTENSIONS="$2"
                shift 2
                ;;
            --strict-tools)
                STRICT_TOOLS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -*)
                echo "Error: Unknown option: $1"
                echo "Try 'organize_and_dedup.sh --help' for more information."
                exit 1
                ;;
            *)
                # Positional arguments (legacy format)
                if [[ -z "$INPUT_DIR" ]]; then
                    INPUT_DIR="$1"
                elif [[ -z "$OUTPUT_DIR" ]]; then
                    OUTPUT_DIR="$1"
                else
                    echo "Error: Too many positional arguments: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Apply mode presets
    apply_mode_presets

    # Validate required arguments
    if [[ -z "$INPUT_DIR" ]]; then
        INPUT_DIR="."
    fi
    
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="./export"
    fi

    # Validate options
    validate_options
}

# ==================== MODE PRESETS ====================

apply_mode_presets() {
    case "$MODE" in
        simple)
            # Simple mode presets (only if not explicitly set by user)
            [[ "${NAMING_FORMAT_SET:-false}" == "false" ]] && NAMING_FORMAT="hash_ext"
            [[ "${ORGANIZE_BY_SET:-false}" == "false" ]] && ORGANIZE_BY="extension"
            [[ "${EXTRACT_ARCHIVES_SET:-false}" == "false" ]] && EXTRACT_ARCHIVES="no"
            [[ "${RECURSIVE_SET:-false}" == "false" ]] && RECURSIVE="no"
            ;;
        advanced)
            # Advanced mode presets (current defaults)
            ;;
        *)
            echo "Error: Invalid mode: $MODE"
            echo "Valid modes: simple, advanced"
            exit 1
            ;;
    esac
    return 0
}

# ==================== VALIDATION ====================

validate_options() {
    # Validate action
    case "$ACTION" in
        cp|mv) ;;
        *)
            echo "Error: Invalid action: $ACTION"
            echo "Valid actions: cp, mv"
            exit 1
            ;;
    esac

    # Validate hash algorithm
    case "$HASH_ALGORITHM" in
        sha1|sha256|sha512|md5) ;;
        *)
            echo "Error: Invalid hash algorithm: $HASH_ALGORITHM"
            echo "Valid algorithms: sha1, sha256, sha512, md5"
            exit 1
            ;;
    esac

    # Validate naming format
    case "$NAMING_FORMAT" in
        hash|hash_ext|date_hash_ext) ;;
        *)
            echo "Error: Invalid naming format: $NAMING_FORMAT"
            echo "Valid formats: hash, hash_ext, date_hash_ext"
            exit 1
            ;;
    esac

    # Validate organization method
    case "$ORGANIZE_BY" in
        none|extension|category|date|category_date) ;;
        *)
            echo "Error: Invalid organization method: $ORGANIZE_BY"
            echo "Valid methods: none, extension, category, date, category_date"
            exit 1
            ;;
    esac

    # Validate boolean options
    for opt in EXTRACT_ARCHIVES RECURSIVE DEDUPLICATE STRICT_TOOLS; do
        val="${!opt}"
        case "$val" in
            yes|no|true|false) ;;
            *)
                echo "Error: Invalid value for $opt: $val"
                echo "Valid values: yes, no, true, false"
                exit 1
                ;;
        esac
    done

    # Check input directory exists
    if [[ ! -d "$INPUT_DIR" ]]; then
        echo "Error: Input directory not found: $INPUT_DIR"
        exit 1
    fi
}

# Parse command line arguments
parse_arguments "$@"

# ==================== TOOL CHECKING ====================

check_tools() {
    local required_tools=(tar file)
    local hash_tools=()
    local optional_tools=(unrar 7z gunzip bunzip2 unxz)
    local missing=()
    
    # Add hash tool based on algorithm
    case "$HASH_ALGORITHM" in
        sha1) hash_tools=(sha1sum) ;;
        sha256) hash_tools=(sha256sum) ;;
        sha512) hash_tools=(sha512sum) ;;
        md5) hash_tools=(md5sum) ;;
    esac
    
    # Add exiftool if using date-based naming or organization
    if [[ "$NAMING_FORMAT" == "date_hash_ext" ]] || [[ "$ORGANIZE_BY" =~ date ]]; then
        required_tools+=(exiftool)
    fi
    
    # Add unzip if extracting archives
    if [[ "$EXTRACT_ARCHIVES" == "yes" ]] || [[ "$EXTRACT_ARCHIVES" == "true" ]]; then
        required_tools+=(unzip)
    fi
    
    # Check required tools
    for tool in "${required_tools[@]}" "${hash_tools[@]}"; do
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
    if [[ "$EXTRACT_ARCHIVES" == "yes" ]] || [[ "$EXTRACT_ARCHIVES" == "true" ]]; then
        for tool in "${optional_tools[@]}"; do
            if ! command -v "$tool" &> /dev/null; then
                if [[ "$STRICT_TOOLS" == "true" ]] || [[ "$STRICT_TOOLS" == "yes" ]]; then
                    echo "Error: Optional tool '$tool' is not installed (STRICT_TOOLS=true)."
                    exit 1
                else
                    [[ "$VERBOSE" == true ]] && echo "Warning: Optional tool '$tool' is not installed. Some archive types may not be processed."
                fi
            fi
        done
    fi
}

check_tools

# ==================== SETUP ====================

# Save original working directory
original_pwd=$(pwd)

# Convert to absolute paths
INPUT_DIR=$(cd "$INPUT_DIR" && pwd)
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)

# Return to original directory
cd "$original_pwd"

# Guard against INPUT_DIR == OUTPUT_DIR with ACTION=mv
if [[ "$ACTION" == "mv" ]] && [[ "$INPUT_DIR" == "$OUTPUT_DIR" ]]; then
    echo "Error: INPUT_DIR and OUTPUT_DIR must differ when ACTION=mv" >&2
    echo "  INPUT_DIR:  $INPUT_DIR" >&2
    echo "  OUTPUT_DIR: $OUTPUT_DIR" >&2
    exit 1
fi

# Print configuration (unless quiet)
if [[ "$QUIET" != true ]]; then
    echo "========================================"
    echo "organize_and_dedup.sh v$VERSION"
    echo "========================================"
    echo "Mode: $MODE"
    echo "Input directory: $INPUT_DIR"
    echo "Output directory: $OUTPUT_DIR"
    echo "Action: $ACTION"
    echo "Hash algorithm: $HASH_ALGORITHM"
    echo "Naming format: $NAMING_FORMAT"
    echo "Organization: $ORGANIZE_BY"
    echo "Extract archives: $EXTRACT_ARCHIVES"
    echo "Recursive: $RECURSIVE"
    echo "Deduplication: $DEDUPLICATE"
    echo ""
fi

# Set log file
log_file="$OUTPUT_DIR/processing.log"
export log_file

# Set temporary directory
tmp_dir="$original_pwd/tmp_organize_$$"
mkdir -p "$tmp_dir"
temp_dir=$(mktemp -d -p "$tmp_dir")

# Hash registry for deduplication
hash_registry="$OUTPUT_DIR/.hash_registry_${HASH_ALGORITHM}.txt"
touch "$hash_registry"

# Extension mismatch report
mismatch_report="$OUTPUT_DIR/extension_mismatches.csv"
if [[ "$FIX_EXTENSIONS" == "yes" ]] || [[ "$STRICT_EXTENSIONS" == "yes" ]] || [[ "$REPORT_EXTENSIONS" == "yes" ]]; then
    echo "original_path,current_ext,detected_ext,mime_type,hash,action" > "$mismatch_report"
    export mismatch_report
fi
export hash_registry

# Statistics tracking
declare -g files_processed=0
declare -g duplicates_skipped=0
declare -g extensions_corrected=0
declare -g extensions_mismatched=0
export files_processed duplicates_skipped extensions_corrected extensions_mismatched

# Cleanup function
cleanup() {
    [[ "$VERBOSE" == true ]] && echo "Cleaning up temporary files..."
    rm -rf "$temp_dir"
    rmdir "$tmp_dir" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# ==================== MIME TYPE TO EXTENSION MAPPING ====================

# Comprehensive MIME type to file extension mapping
declare -A MIME_TO_EXT=(
    # Documents
    ["application/vnd.openxmlformats-officedocument.wordprocessingml.document"]="docx"
    ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]="xlsx"
    ["application/vnd.openxmlformats-officedocument.presentationml.presentation"]="pptx"
    ["application/msword"]="doc"
    ["application/vnd.ms-excel"]="xls"
    ["application/vnd.ms-powerpoint"]="ppt"
    ["application/pdf"]="pdf"
    ["application/rtf"]="rtf"
    ["application/vnd.oasis.opendocument.text"]="odt"
    ["application/vnd.oasis.opendocument.spreadsheet"]="ods"
    ["application/vnd.oasis.opendocument.presentation"]="odp"
    
    # Archives
    ["application/zip"]="zip"
    ["application/x-rar"]="rar"
    ["application/x-rar-compressed"]="rar"
    ["application/vnd.rar"]="rar"
    ["application/x-7z-compressed"]="7z"
    ["application/x-tar"]="tar"
    ["application/gzip"]="gz"
    ["application/x-gzip"]="gz"
    ["application/x-bzip2"]="bz2"
    ["application/x-xz"]="xz"
    ["application/x-compress"]="z"
    
    # Images
    ["image/jpeg"]="jpg"
    ["image/png"]="png"
    ["image/gif"]="gif"
    ["image/webp"]="webp"
    ["image/svg+xml"]="svg"
    ["image/bmp"]="bmp"
    ["image/x-ms-bmp"]="bmp"
    ["image/tiff"]="tiff"
    ["image/x-icon"]="ico"
    ["image/vnd.adobe.photoshop"]="psd"
    ["image/heic"]="heic"
    ["image/heif"]="heif"
    
    # Video
    ["video/mp4"]="mp4"
    ["video/x-matroska"]="mkv"
    ["video/quicktime"]="mov"
    ["video/x-msvideo"]="avi"
    ["video/webm"]="webm"
    ["video/x-flv"]="flv"
    ["video/mpeg"]="mpeg"
    ["video/3gpp"]="3gp"
    ["video/x-ms-wmv"]="wmv"
    
    # Audio
    ["audio/mpeg"]="mp3"
    ["audio/mp4"]="m4a"
    ["audio/x-wav"]="wav"
    ["audio/wav"]="wav"
    ["audio/flac"]="flac"
    ["audio/ogg"]="ogg"
    ["audio/x-ms-wma"]="wma"
    ["audio/aac"]="aac"
    ["audio/opus"]="opus"
    
    # Text & Code
    ["text/plain"]="txt"
    ["text/html"]="html"
    ["text/css"]="css"
    ["text/javascript"]="js"
    ["application/javascript"]="js"
    ["application/json"]="json"
    ["application/xml"]="xml"
    ["text/xml"]="xml"
    ["text/csv"]="csv"
    ["text/markdown"]="md"
    ["text/x-python"]="py"
    ["text/x-shellscript"]="sh"
    ["text/x-c"]="c"
    ["text/x-c++"]="cpp"
    ["text/x-java"]="java"
    ["text/x-php"]="php"
    ["text/x-ruby"]="rb"
    ["text/x-go"]="go"
    ["text/x-rust"]="rs"
    
    # Executables & Binaries
    ["application/x-executable"]="bin"
    ["application/x-sharedlib"]="so"
    ["application/x-mach-binary"]="bin"
    ["application/x-dosexec"]="exe"
    ["application/vnd.microsoft.portable-executable"]="exe"
    ["application/x-msdownload"]="exe"
    
    # Fonts
    ["font/ttf"]="ttf"
    ["font/otf"]="otf"
    ["font/woff"]="woff"
    ["font/woff2"]="woff2"
    ["application/x-font-ttf"]="ttf"
    ["application/x-font-otf"]="otf"
)

export MIME_TO_EXT

# ==================== HASH FUNCTIONS ====================

# Calculate hash based on algorithm
calculate_hash() {
    local file="$1"
    local hash=""
    
    case "$HASH_ALGORITHM" in
        sha1)
            hash=$(sha1sum "$file" 2>> "$log_file" | awk '{print toupper($1)}')
            ;;
        sha256)
            hash=$(sha256sum "$file" 2>> "$log_file" | awk '{print toupper($1)}')
            ;;
        sha512)
            hash=$(sha512sum "$file" 2>> "$log_file" | awk '{print toupper($1)}')
            ;;
        md5)
            hash=$(md5sum "$file" 2>> "$log_file" | awk '{print toupper($1)}')
            ;;
    esac
    
    echo "$hash"
}

# Check if hash exists in registry
hash_exists() {
    local hash="$1"
    grep -qxF "$hash" "$hash_registry" 2>/dev/null || return 1
    return 0
}

# Add hash to registry
add_hash() {
    local hash="$1"
    echo "$hash" >> "$hash_registry"
}

export -f calculate_hash
export -f hash_exists
export -f add_hash
export HASH_ALGORITHM

# ==================== NORMALIZATION FUNCTIONS ====================

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

# Detect correct file extension based on content
detect_correct_extension() {
    local file="$1"
    local current_ext="${file##*.}"
    
    # If file has no extension, set current_ext to empty
    if [[ "$current_ext" == "$file" ]]; then
        current_ext=""
    fi
    
    # Get MIME type using file command
    local mime_type
    mime_type=$(file -b --mime-type "$file" 2>/dev/null)
    
    if [[ -z "$mime_type" ]]; then
        # Fallback: return current extension or empty
        echo "${current_ext}"
        return
    fi
    
    # Look up correct extension from MIME type
    # Use parameter expansion to safely check if key exists (Bash 4.2+ compatible)
    local correct_ext="${MIME_TO_EXT[$mime_type]:-}"
    
    if [[ -n "$correct_ext" ]]; then
        echo "$correct_ext"
    else
        # Fallback: return current extension or empty
        echo "${current_ext}"
    fi
}

get_category() {
    local ext="$1"
    case "$ext" in
        # Certificates
        pem|crt|cer|der|pfx|p12|key|csr|p7b|p7c)
            echo "certificates" ;;
        # Configurations
        ini|conf|config|cfg|properties|toml|plist|gitignore|eslintignore|htaccess|bashrc|bash_profile|bash_logout|lock|env|editorconfig)
            echo "configs" ;;
        # Structured data
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
        # Scripts and code
        sh|bash|bat|cmd|ps1|py|pl|rb|java|c|cpp|h|cs|go|rs|php|css|js|ts|ipynb|r|kt|swift|lua|perl|sql|awk|sed|vim|el|clj|scala|groovy|vb|vbs|asm|s|f|f90|pas|tcl|m|mm)
            echo "scripts" ;;
        # Archives
        zip|rar|7z|tar|gz|bz2|xz|tgz|tbz2|txz|lz|lzma|z|zst|iso|img|dmg|apk|jar|aar|deb|rpm|cab|arj|lzh|ace|zoo|arc|pak|wim)
            echo "archives" ;;
        # Fonts
        ttf|otf|woff|woff2|eot|afm|pfb|pfm|fnt|fntdata|dfont|fon|ttc)
            echo "fonts" ;;
        # Databases
        db|db3|sqlite|sqlite3|accdb|mdb|db-shm|db-wal|sqlite-shm|sqlite-wal|pdb|dbf|mdf|ldf|frm|ibd)
            echo "databases" ;;
        # Applications/Executables
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

export -f normalize_extension
export -f get_category

# ==================== EXTRACTION FUNCTION ====================

extract_file() {
    local file="$1"
    local dest_dir="$2"

    case "$file" in
        *.zip)
            if command -v unzip &> /dev/null && unzip -t "$file" > /dev/null 2>&1; then
                [[ "$VERBOSE" == true ]] && echo "Extracting ZIP: $file"
                unzip -o "$file" -d "$dest_dir" >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
            fi
            ;;
        *.tar.gz|*.tgz)
            if tar -tzf "$file" > /dev/null 2>&1; then
                [[ "$VERBOSE" == true ]] && echo "Extracting TAR.GZ: $file"
                tar -xzf "$file" -C "$dest_dir" --warning=no-unknown-keyword >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
            fi
            ;;
        *.rar)
            if command -v unrar &> /dev/null && unrar t "$file" > /dev/null 2>&1; then
                [[ "$VERBOSE" == true ]] && echo "Extracting RAR: $file"
                unrar x -o+ "$file" "$dest_dir" >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
            fi
            ;;
        *.tar.bz2|*.tbz2)
            if tar -tjf "$file" > /dev/null 2>&1; then
                [[ "$VERBOSE" == true ]] && echo "Extracting TAR.BZ2: $file"
                tar -xjf "$file" -C "$dest_dir" --warning=no-unknown-keyword >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
            fi
            ;;
        *.tar.xz|*.txz)
            if tar -tJf "$file" > /dev/null 2>&1; then
                [[ "$VERBOSE" == true ]] && echo "Extracting TAR.XZ: $file"
                tar -xJf "$file" -C "$dest_dir" --warning=no-unknown-keyword >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
            fi
            ;;
        *.7z)
            if command -v 7z &> /dev/null && 7z t "$file" > /dev/null 2>&1; then
                [[ "$VERBOSE" == true ]] && echo "Extracting 7Z: $file"
                7z x "$file" -o"$dest_dir" >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
            fi
            ;;
        *.tar)
            if tar -tf "$file" > /dev/null 2>&1; then
                [[ "$VERBOSE" == true ]] && echo "Extracting TAR: $file"
                tar -xf "$file" -C "$dest_dir" --warning=no-unknown-keyword >> "$log_file" 2>&1 || echo "Error extracting $file" | tee -a "$log_file"
            fi
            ;;
    esac
}

export -f extract_file

# ==================== FILE PROCESSING FUNCTION ====================

process_file() {
    local file="$1"
    local datetime=""
    local year_month=""
    local clean_dt=""

    # Skip if not a regular file
    if [[ ! -f "$file" ]]; then
        return
    fi

    # Skip if file is in output directory
    if [[ "$file" == "$OUTPUT_DIR"/* ]]; then
        return
    fi

    [[ "$VERBOSE" == true ]] && echo "Processing: $file"

    # Calculate hash
    local hash
    hash=$(calculate_hash "$file")
    
    if [[ -z "$hash" ]]; then
        echo "Error calculating hash for $file" | tee -a "$log_file"
        return
    fi

    # Check for duplicates if deduplication is enabled
    if [[ "$DEDUPLICATE" == "yes" ]] || [[ "$DEDUPLICATE" == "true" ]]; then
        if hash_exists "$hash"; then
            [[ "$VERBOSE" == true ]] && echo "Duplicate skipped: $file (hash: $hash)"
            ((duplicates_skipped++)) || true
            return
        fi
        add_hash "$hash"
    fi

    # Get file extension
    local filename=$(basename "$file")
    local raw_extension="${filename##*.}"
    local extension=""
    
    # Handle dotfiles and files without extensions
    if [[ "$filename" == .* ]] && [[ "$filename" != *.*.* ]]; then
        extension=""
    elif [[ "$filename" == "$raw_extension" ]]; then
        extension=""
    else
        extension=$(normalize_extension "$raw_extension")
    fi

    # Detect extension if missing (using exiftool)
    if [[ -z "$extension" ]] && command -v exiftool &> /dev/null; then
        local detected_type
        detected_type=$(exiftool -s -s -s -FileType "$file" 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [[ -n "$detected_type" ]]; then
            extension=$(normalize_extension "$detected_type")
        fi
    fi

    # Extension correction: detect correct extension based on file content
    local original_extension="$extension"
    local detected_extension=""
    local mime_type=""
    
    if [[ "$FIX_EXTENSIONS" == "yes" ]] || [[ "$STRICT_EXTENSIONS" == "yes" ]] || [[ "$REPORT_EXTENSIONS" == "yes" ]]; then
        detected_extension=$(detect_correct_extension "$file")
        mime_type=$(file -b --mime-type "$file" 2>/dev/null)
        
        # Check for mismatch
        if [[ -n "$detected_extension" ]] && [[ "$detected_extension" != "$original_extension" ]]; then
            # Log mismatch
            if [[ "$VERBOSE" == true ]] || [[ "$REPORT_EXTENSIONS" == "yes" ]]; then
                echo "Extension mismatch: $file" | tee -a "$log_file"
                echo "  Current: ${original_extension:-none}, Detected: $detected_extension (${mime_type})" | tee -a "$log_file"
            fi
            
            # Record mismatch for report
            ((extensions_mismatched++)) || true
            echo "$file,${original_extension:-none},$detected_extension,$mime_type,$hash,$(if [[ "$FIX_EXTENSIONS" == "yes" ]]; then echo "corrected"; else echo "detected"; fi)" >> "$mismatch_report"
            
            # Apply correction if --fix-extensions is enabled
            if [[ "$FIX_EXTENSIONS" == "yes" ]]; then
                extension="$detected_extension"
                ((extensions_corrected++)) || true
                [[ "$VERBOSE" == true ]] && echo "  Action: Using correct extension .$extension" | tee -a "$log_file"
            fi
            
            # Skip file if --strict-extensions is enabled and extension is wrong
            if [[ "$STRICT_EXTENSIONS" == "yes" ]]; then
                echo "  Action: Skipping file (strict mode)" | tee -a "$log_file"
                return
            fi
        fi
        
        # If --report-extensions is enabled, just report and skip processing
        if [[ "$REPORT_EXTENSIONS" == "yes" ]]; then
            return
        fi
    fi

    # Get category if needed
    local category=""
    if [[ "$ORGANIZE_BY" =~ category ]]; then
        if [[ -n "$extension" ]]; then
            category=$(get_category "$extension")
        else
            category="others"
        fi
    fi

    # Get date if needed
    if [[ "$NAMING_FORMAT" == "date_hash_ext" ]] || [[ "$ORGANIZE_BY" =~ date ]]; then
        datetime=$(exiftool -s3 -DateTimeOriginal "$file" 2>/dev/null || true)
        
        if [[ -z "$datetime" ]]; then
            datetime=$(exiftool -s3 -CreateDate "$file" 2>/dev/null || true)
        fi
        
        if [[ -z "$datetime" ]]; then
            if [[ "$(uname)" == "Darwin" ]]; then
                datetime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || true)
            else
                datetime=$(stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1 | cut -d'+' -f1 || true)
            fi
        fi
        
        if [[ -z "$datetime" ]]; then
            datetime=$(date "+%Y-%m-%d %H:%M:%S")
        fi

        # Clean datetime for filename
        clean_dt=$(echo "$datetime" | tr ':' '-' | tr ' ' '_')
        year_month=$(echo "$clean_dt" | cut -d'_' -f1 | cut -d'-' -f1-2)
    fi

    # Construct filename based on naming format
    local new_filename=""
    case "$NAMING_FORMAT" in
        hash)
            new_filename="$hash"
            ;;
        hash_ext)
            if [[ -n "$extension" ]]; then
                new_filename="${hash}.${extension}"
            else
                new_filename="$hash"
            fi
            ;;
        date_hash_ext)
            if [[ -n "$extension" ]]; then
                new_filename="${clean_dt}_${hash}.${extension}"
            else
                new_filename="${clean_dt}_${hash}"
            fi
            ;;
    esac

    # Determine destination directory based on organization method
    local dest_dir="$OUTPUT_DIR"
    
    case "$ORGANIZE_BY" in
        none)
            dest_dir="$OUTPUT_DIR"
            ;;
        extension)
            if [[ -n "$extension" ]]; then
                dest_dir="$OUTPUT_DIR/$extension"
            else
                dest_dir="$OUTPUT_DIR/no_extension"
            fi
            ;;
        category)
            dest_dir="$OUTPUT_DIR/$category"
            ;;
        date)
            dest_dir="$OUTPUT_DIR/$year_month"
            ;;
        category_date)
            dest_dir="$OUTPUT_DIR/$category/$year_month"
            ;;
    esac

    # Create destination directory
    if ! mkdir -p "$dest_dir"; then
        echo "Error creating directory $dest_dir" | tee -a "$log_file"
        return
    fi

    # Construct full destination path
    local dest_file="$dest_dir/$new_filename"

    # Check if destination file already exists
    if [[ -e "$dest_file" ]]; then
        [[ "$VERBOSE" == true ]] && echo "Warning: Destination file already exists: $dest_file"
        return
    fi

    # Copy or move the file
    if [[ "$ACTION" == "mv" ]]; then
        if mv "$file" "$dest_file"; then
            [[ "$VERBOSE" == true ]] && echo "Moved: $file -> $dest_file"
            ((files_processed++)) || true
        else
            echo "Error moving: $file -> $dest_file" | tee -a "$log_file"
        fi
    else
        if cp -p "$file" "$dest_file"; then
            [[ "$VERBOSE" == true ]] && echo "Copied: $file -> $dest_file"
            ((files_processed++)) || true
        else
            echo "Error copying: $file -> $dest_file" | tee -a "$log_file"
        fi
    fi
}

export -f process_file
export NAMING_FORMAT ORGANIZE_BY DEDUPLICATE ACTION OUTPUT_DIR VERBOSE

# ==================== MAIN EXECUTION ====================

if [[ "$QUIET" != true ]]; then
    echo "======================================" | tee -a "$log_file"
    echo "Starting file organization process" | tee -a "$log_file"
    echo "Date: $(date)" | tee -a "$log_file"
    echo "======================================" | tee -a "$log_file"
    echo "" | tee -a "$log_file"
fi

# Record starting hash count
start_hash_count=$(wc -l < "$hash_registry" 2>/dev/null || echo 0)

# Count total files
if [[ "$QUIET" != true ]]; then
    echo "Scanning input directory..." | tee -a "$log_file"
fi

set +e
if [[ "$RECURSIVE" == "yes" ]] || [[ "$RECURSIVE" == "true" ]]; then
    total_files=$(find "$INPUT_DIR" -type f 2>/dev/null | wc -l || echo 0)
else
    total_files=$(find "$INPUT_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l || echo 0)
fi
set -e

if [[ "$QUIET" != true ]]; then
    echo "Found $total_files files to process" | tee -a "$log_file"
    echo "" | tee -a "$log_file"
fi

# PHASE 1: Extract archives (if enabled)
if [[ "$EXTRACT_ARCHIVES" == "yes" ]] || [[ "$EXTRACT_ARCHIVES" == "true" ]]; then
    if [[ "$QUIET" != true ]]; then
        echo "======================================" | tee -a "$log_file"
        echo "PHASE 1: Extracting archives" | tee -a "$log_file"
        echo "======================================" | tee -a "$log_file"
    fi

    # Build find command using arrays (safer than eval)
    find_args=("$INPUT_DIR")
    if [[ "$RECURSIVE" != "yes" ]] && [[ "$RECURSIVE" != "true" ]]; then
        find_args+=("-maxdepth" "1")
    fi
    find_args+=("-type" "f")

    while IFS= read -r -d '' file; do
        extract_file "$file" "$temp_dir"
    done < <(find "${find_args[@]}" \( \
        -iname "*.zip" -o -iname "*.tar.gz" -o -iname "*.tgz" -o \
        -iname "*.rar" -o -iname "*.tar.bz2" -o -iname "*.tbz2" -o \
        -iname "*.tar.xz" -o -iname "*.txz" -o -iname "*.7z" -o \
        -iname "*.tar" \
    \) -print0 2>/dev/null)

    if [[ "$QUIET" != true ]]; then
        echo "" | tee -a "$log_file"
    fi
fi

# PHASE 2: Process archive files themselves (if extracting)
if [[ "$EXTRACT_ARCHIVES" == "yes" ]] || [[ "$EXTRACT_ARCHIVES" == "true" ]]; then
    if [[ "$QUIET" != true ]]; then
        echo "======================================" | tee -a "$log_file"
        echo "PHASE 2: Organizing archive files" | tee -a "$log_file"
        echo "======================================" | tee -a "$log_file"
    fi

    # Build find command using arrays (safer than eval)
    find_args=("$INPUT_DIR")
    if [[ "$RECURSIVE" != "yes" ]] && [[ "$RECURSIVE" != "true" ]]; then
        find_args+=("-maxdepth" "1")
    fi
    find_args+=("-type" "f")

    while IFS= read -r -d '' file; do
        process_file "$file"
    done < <(find "${find_args[@]}" \( \
        -iname "*.zip" -o -iname "*.tar.gz" -o -iname "*.tgz" -o \
        -iname "*.rar" -o -iname "*.tar.bz2" -o -iname "*.tbz2" -o \
        -iname "*.tar.xz" -o -iname "*.txz" -o -iname "*.7z" -o \
        -iname "*.tar" \
    \) -print0 2>/dev/null)

    if [[ "$QUIET" != true ]]; then
        echo "" | tee -a "$log_file"
    fi
fi

# PHASE 3: Process all other files
phase_num=3
if [[ "$EXTRACT_ARCHIVES" != "yes" ]] && [[ "$EXTRACT_ARCHIVES" != "true" ]]; then
    phase_num=1
fi

if [[ "$QUIET" != true ]]; then
    echo "======================================" | tee -a "$log_file"
    echo "PHASE $phase_num: Organizing files" | tee -a "$log_file"
    echo "======================================" | tee -a "$log_file"
fi

# Build find command based on recursive setting
if [[ "$RECURSIVE" == "yes" ]] || [[ "$RECURSIVE" == "true" ]]; then
    if [[ "$EXTRACT_ARCHIVES" == "yes" ]] || [[ "$EXTRACT_ARCHIVES" == "true" ]]; then
        # Process input and extracted files, excluding archives
        while IFS= read -r -d '' file; do
            process_file "$file"
        done < <(find "$INPUT_DIR" "$temp_dir" \
            -path "$OUTPUT_DIR" -prune -o \
            -type f ! \( \
                -iname "*.zip" -o -iname "*.tar.gz" -o -iname "*.tgz" -o \
                -iname "*.rar" -o -iname "*.tar.bz2" -o -iname "*.tbz2" -o \
                -iname "*.tar.xz" -o -iname "*.txz" -o -iname "*.7z" -o \
                -iname "*.tar" \
            \) -print0 2>/dev/null)
    else
        # Process all files in input directory
        while IFS= read -r -d '' file; do
            process_file "$file"
        done < <(find "$INPUT_DIR" \
            -path "$OUTPUT_DIR" -prune -o \
            -type f -print0 2>/dev/null)
    fi
else
    # Non-recursive: process only files in input directory root
    while IFS= read -r -d '' file; do
        process_file "$file"
    done < <(find "$INPUT_DIR" -maxdepth 1 -type f -print0 2>/dev/null)
fi

if [[ "$QUIET" != true ]]; then
    echo "" | tee -a "$log_file"
fi

# ==================== COMPLETION ====================

if [[ "$QUIET" != true ]]; then
    echo "======================================" | tee -a "$log_file"
    echo "Processing complete!" | tee -a "$log_file"
    echo "======================================" | tee -a "$log_file"
    echo "" | tee -a "$log_file"
    echo "Output directory: $OUTPUT_DIR" | tee -a "$log_file"
    echo "Log file: $log_file" | tee -a "$log_file"
    echo "Hash registry: $hash_registry" | tee -a "$log_file"
    
    # Show extension mismatch report if generated
    if [[ -f "$mismatch_report" ]]; then
        echo "Extension mismatch report: $mismatch_report" | tee -a "$log_file"
    fi
    
    echo "" | tee -a "$log_file"
fi

# Calculate statistics
end_hash_count=$(wc -l < "$hash_registry" 2>/dev/null || echo 0)
new_unique_files=$((end_hash_count - start_hash_count))

if [[ "$QUIET" != true ]]; then
    echo "Summary:" | tee -a "$log_file"
    echo "--------" | tee -a "$log_file"
    echo "Files in input directory: $total_files" | tee -a "$log_file"
    echo "New unique files this run: $new_unique_files" | tee -a "$log_file"
    echo "Files successfully processed: $files_processed" | tee -a "$log_file"
    echo "Duplicates skipped this run: $duplicates_skipped" | tee -a "$log_file"
    echo "Total unique hashes in registry (all runs): $end_hash_count" | tee -a "$log_file"
    
    # Show extension correction statistics if enabled
    if [[ "$FIX_EXTENSIONS" == "yes" ]] || [[ "$STRICT_EXTENSIONS" == "yes" ]] || [[ "$REPORT_EXTENSIONS" == "yes" ]]; then
        echo "Extensions corrected: $extensions_corrected" | tee -a "$log_file"
        echo "Extension mismatches detected: $extensions_mismatched" | tee -a "$log_file"
    fi
    
    echo "" | tee -a "$log_file"

    # Show organization breakdown
    if [[ "$ORGANIZE_BY" != "none" ]]; then
        echo "Files by organization:" | tee -a "$log_file"
        set +e
        for org_dir in "$OUTPUT_DIR"/*; do
            if [[ -d "$org_dir" ]] && [[ "$(basename "$org_dir")" != ".*" ]]; then
                org_name=$(basename "$org_dir")
                count=$(find "$org_dir" -type f 2>/dev/null | wc -l || echo 0)
                if [[ $count -gt 0 ]]; then
                    echo "  $org_name: $count files" | tee -a "$log_file"
                fi
            fi
        done
        set -e
        echo "" | tee -a "$log_file"
    fi

    echo "Done!" | tee -a "$log_file"
fi
