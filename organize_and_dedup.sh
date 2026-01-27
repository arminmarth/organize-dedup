#!/usr/bin/env bash

set -uo pipefail

VERSION="1.0.0"

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

warn() {
    printf '[%s] Warning: %s\n' "$(date '+%H:%M:%S')" "$*" >&2
}

usage() {
    cat <<'USAGE'
Usage: organize_and_dedup.sh <input_dir> <output_dir>

Find files recursively in the input directory, detect their correct extension
from MIME/magic, and hardlink them into category/YYYY-MM folders using a
SHA256 filename.

Options:
  -h, --help     Show this help message.
  -v, --version  Show the script version.
USAGE
}

cleanup_on_interrupt() {
    warn "Interrupted. Processed: $processed, linked: $linked, skipped: $skipped, duplicates: $duplicates, warnings: $failed"
    exit 130
}

if [[ $# -eq 1 ]]; then
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            echo "organize_and_dedup.sh $VERSION"
            exit 0
            ;;
    esac
fi

if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

INPUT_DIR="${1%/}"
OUTPUT_DIR="${2%/}"

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Error: input directory does not exist: $INPUT_DIR" >&2
    exit 1
fi

if [[ -e "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: output path exists and is not a directory: $OUTPUT_DIR" >&2
    exit 1
fi

if [[ "$INPUT_DIR" == "$OUTPUT_DIR" ]]; then
    echo "Error: input and output directories must be different." >&2
    exit 1
fi

STAT_CMD="stat"
if command -v gstat >/dev/null 2>&1; then
    STAT_CMD="gstat"
fi

HASH_CMD="sha256sum"
if ! command -v "$HASH_CMD" >/dev/null 2>&1; then
    if command -v shasum >/dev/null 2>&1; then
        HASH_CMD="shasum"
    fi
fi

for cmd in file "$HASH_CMD" "$STAT_CMD" date; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' command not found." >&2
        exit 1
    fi
done

log "Starting organize_and_dedup.sh $VERSION"
log "Input directory: $INPUT_DIR"
log "Output directory: $OUTPUT_DIR"
log "Hash command: $HASH_CMD"

mkdir -p -- "$OUTPUT_DIR"
if [[ ! -w "$OUTPUT_DIR" ]]; then
    echo "Error: output directory is not writable: $OUTPUT_DIR" >&2
    exit 1
fi

trap cleanup_on_interrupt INT TERM

get_year_month_from_exif() {
    local file="$1"
    if ! command -v exiftool >/dev/null 2>&1; then
        return 1
    fi

    local exif_date
    exif_date=$(exiftool -s -s -s \
        -DateTimeOriginal \
        -CreateDate \
        -MediaCreateDate \
        -d "%Y-%m" \
        -- "$file" 2>/dev/null | head -n 1 || true)

    if [[ "$exif_date" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
        printf '%s' "$exif_date"
        return 0
    fi

    return 1
}

get_year_month_from_stat() {
    local file="$1"
    local timestamp
    timestamp=$(get_stat_timestamp "$file" "%W" "%B")
    if [[ "$timestamp" == "0" || "$timestamp" == "-1" ]]; then
        timestamp=$(get_stat_timestamp "$file" "%Y" "%m")
    fi
    format_timestamp "$timestamp"
}

get_stat_timestamp() {
    local file="$1"
    local gnu_flag="$2"
    local bsd_flag="$3"

    if "$STAT_CMD" -c "$gnu_flag" -- "$file" >/dev/null 2>&1; then
        "$STAT_CMD" -c "$gnu_flag" -- "$file"
        return
    fi

    if "$STAT_CMD" -f "$bsd_flag" -- "$file" >/dev/null 2>&1; then
        "$STAT_CMD" -f "$bsd_flag" -- "$file"
        return
    fi

    date +%s
}

format_timestamp() {
    local timestamp="$1"
    if [[ -z "$timestamp" || "$timestamp" == "0" || "$timestamp" == "-1" ]]; then
        date "+%Y-%m"
        return
    fi
    if command -v gdate >/dev/null 2>&1; then
        gdate -d "@$timestamp" "+%Y-%m"
        return
    fi
    if date -d "@$timestamp" "+%Y-%m" >/dev/null 2>&1; then
        date -d "@$timestamp" "+%Y-%m"
        return
    fi
    date -r "$timestamp" "+%Y-%m"
}

hash_file() {
    local file="$1"
    local output
    if [[ "$HASH_CMD" == "sha256sum" ]]; then
        output=$(sha256sum -- "$file" 2>/dev/null || true)
    else
        output=$(shasum -a 256 -- "$file" 2>/dev/null || true)
    fi
    printf '%s' "${output%% *}"
}

normalize_extension() {
    local ext="${1,,}"
    case "$ext" in
        jpg|jpeg|jpe|jfif) echo "jpg" ;;
        tif|tiff) echo "tiff" ;;
        heif|heic) echo "heic" ;;
        mp4|m4v|f4v|f4p|f4a|f4b) echo "mp4" ;;
        mov|qt) echo "mov" ;;
        mp3|mp2|mpga) echo "mp3" ;;
        oga|ogg) echo "ogg" ;;
        tgz|tar.gz) echo "tar.gz" ;;
        *) echo "$ext" ;;
    esac
}

get_extension_and_category() {
    local file="$1"
    local mime
    local desc

    mime=$(file --mime-type -b -- "$file" 2>/dev/null || true)
    desc=$(file -b -- "$file" 2>/dev/null || true)

    if [[ -z "$mime" ]]; then
        warn "unable to read file type for '$file'."
        echo "bin unknown"
        return 0
    fi

    case "$mime" in
        image/jpeg) echo "jpg images"; return 0 ;;
        image/png) echo "png images"; return 0 ;;
        image/gif) echo "gif images"; return 0 ;;
        image/webp) echo "webp images"; return 0 ;;
        image/tiff) echo "tiff images"; return 0 ;;
        image/bmp|image/x-ms-bmp) echo "bmp images"; return 0 ;;
        image/svg+xml) echo "svg images"; return 0 ;;
        image/heic|image/heif) echo "heic images"; return 0 ;;
        video/mp4) echo "mp4 videos"; return 0 ;;
        video/quicktime) echo "mov videos"; return 0 ;;
        video/x-msvideo) echo "avi videos"; return 0 ;;
        video/x-matroska) echo "mkv videos"; return 0 ;;
        video/webm) echo "webm videos"; return 0 ;;
        video/mpeg) echo "mpeg videos"; return 0 ;;
        video/3gpp) echo "3gp videos"; return 0 ;;
        audio/mpeg) echo "mp3 audio"; return 0 ;;
        audio/x-wav|audio/wav) echo "wav audio"; return 0 ;;
        audio/flac) echo "flac audio"; return 0 ;;
        audio/aac) echo "aac audio"; return 0 ;;
        audio/mp4) echo "m4a audio"; return 0 ;;
        audio/ogg|audio/opus) echo "ogg audio"; return 0 ;;
        application/pdf) echo "pdf documents"; return 0 ;;
        application/msword) echo "doc documents"; return 0 ;;
        application/vnd.openxmlformats-officedocument.wordprocessingml.document)
            echo "docx documents"; return 0 ;;
        application/vnd.ms-excel) echo "xls documents"; return 0 ;;
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet)
            echo "xlsx documents"; return 0 ;;
        application/vnd.ms-powerpoint) echo "ppt documents"; return 0 ;;
        application/vnd.openxmlformats-officedocument.presentationml.presentation)
            echo "pptx documents"; return 0 ;;
        application/rtf) echo "rtf documents"; return 0 ;;
        application/vnd.oasis.opendocument.text) echo "odt documents"; return 0 ;;
        application/vnd.oasis.opendocument.spreadsheet) echo "ods documents"; return 0 ;;
        application/vnd.oasis.opendocument.presentation) echo "odp documents"; return 0 ;;
        text/plain) echo "txt text"; return 0 ;;
        text/csv) echo "csv text"; return 0 ;;
        application/json|text/json) echo "json text"; return 0 ;;
        text/xml|application/xml) echo "xml text"; return 0 ;;
        text/html) echo "html text"; return 0 ;;
        application/zip) echo "zip archives"; return 0 ;;
        application/x-7z-compressed) echo "7z archives"; return 0 ;;
        application/x-rar|application/vnd.rar) echo "rar archives"; return 0 ;;
        application/x-tar) echo "tar archives"; return 0 ;;
        application/gzip|application/x-gzip) echo "gz archives"; return 0 ;;
        application/x-bzip2) echo "bz2 archives"; return 0 ;;
        application/x-xz) echo "xz archives"; return 0 ;;
        application/x-executable|application/x-pie-executable|application/x-sharedlib|application/x-msdownload|application/vnd.microsoft.portable-executable)
            echo "exe executables"; return 0 ;;
    esac

    if [[ "$desc" == *"tar archive"* && "$mime" == "application/gzip" ]]; then
        echo "tar.gz archives"
        return 0
    fi

    echo "bin unknown"
}

process_file() {
    local file="$1"
    local ext_category
    local extension
    local category
    local year_month
    local hash
    local target_dir
    local target_file
    local action

    log "Processing: $file"

    if [[ ! -r "$file" ]]; then
        ((++failed))
        warn "unreadable file '$file'."
        return 0
    fi

    ext_category=$(get_extension_and_category "$file")
    extension=${ext_category%% *}
    category=${ext_category##* }
    extension=$(normalize_extension "$extension")

    if ! year_month=$(get_year_month_from_exif "$file"); then
        year_month=$(get_year_month_from_stat "$file")
    fi

    hash=$(hash_file "$file")
    if [[ -z "$hash" ]]; then
        ((++failed))
        warn "failed to compute hash for '$file'."
        return 0
    fi
    hash=${hash^^}

    if [[ -n "${seen_hashes[$hash]:-}" ]]; then
        ((++duplicates))
        log "Duplicate detected (already processed hash): $file"
        return 0
    fi

    if [[ -n "${existing_hashes[$hash]:-}" ]]; then
        ((++duplicates))
        log "Duplicate detected (already in output): $file"
        seen_hashes[$hash]="${existing_hashes[$hash]}"
        return 0
    fi

    target_dir="$OUTPUT_DIR/$category/$year_month"
    if ! mkdir -p -- "$target_dir"; then
        ((++failed))
        warn "failed to create directory '$target_dir'."
        return 0
    fi

    target_file="$target_dir/$hash.$extension"

    if [[ -e "$target_file" ]]; then
        ((++duplicates))
        log "Duplicate detected (already exists): $target_file"
        seen_hashes[$hash]="$target_file"
        return 0
    fi

    if compgen -G "$target_dir/$hash.*" >/dev/null; then
        ((++duplicates))
        log "Duplicate detected (same hash in directory): $file"
        seen_hashes[$hash]="$target_dir/$hash.*"
        return 0
    fi

    action="Linked"
    if ! ln -- "$file" "$target_file"; then
        warn "hardlink failed for '$file' -> '$target_file', attempting copy."
        if ! cp -p -- "$file" "$target_file"; then
            ((++failed))
            warn "failed to copy '$file' -> '$target_file'."
            return 0
        fi
        action="Copied"
    fi

    ((++linked))
    seen_hashes[$hash]="$target_file"
    log "$action to: $target_file"
}

processed=0
linked=0
skipped=0
duplicates=0
failed=0
declare -A existing_hashes=()
declare -A seen_hashes=()

if [[ -d "$OUTPUT_DIR" ]]; then
    while IFS= read -r -d '' existing_file; do
        base_name=${existing_file##*/}
        hash_candidate=${base_name%%.*}
        if [[ "$hash_candidate" =~ ^[0-9A-Fa-f]{64}$ ]]; then
            existing_hashes[${hash_candidate^^}]="$existing_file"
        fi
    done < <(find "$OUTPUT_DIR" -type f -print0)
fi

find_cmd=(find "$INPUT_DIR" -type f)
if [[ "$OUTPUT_DIR" == "$INPUT_DIR" || "$OUTPUT_DIR" == "$INPUT_DIR"/* ]]; then
    find_cmd+=( -not -path "$OUTPUT_DIR/*" )
fi

while IFS= read -r -d '' file; do
    ((++processed))
    process_file "$file"
done < <("${find_cmd[@]}" -print0)

log "Completed. Processed: $processed, linked: $linked, skipped: $skipped, duplicates: $duplicates, warnings: $failed"
