#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: organize_and_dedup.sh <input_dir> <output_dir>

Find files recursively in the input directory, detect their correct extension
from MIME/magic, and hardlink them into category/YYY-MM folders using a
SHA256 filename.
USAGE
}

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

for cmd in file sha256sum stat date; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' command not found." >&2
        exit 1
    fi
done

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
    timestamp=$(stat -c %W -- "$file" 2>/dev/null || echo 0)
    if [[ "$timestamp" == "0" || "$timestamp" == "-1" ]]; then
        timestamp=$(stat -c %Y -- "$file")
    fi
    date -d "@$timestamp" "+%Y-%m"
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

    mime=$(file --mime-type -b -- "$file")
    desc=$(file -b -- "$file")

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

    ext_category=$(get_extension_and_category "$file")
    extension=${ext_category%% *}
    category=${ext_category##* }
    extension=$(normalize_extension "$extension")

    if ! year_month=$(get_year_month_from_exif "$file"); then
        year_month=$(get_year_month_from_stat "$file")
    fi

    hash=$(sha256sum -- "$file" | awk '{print toupper($1)}')

    target_dir="$OUTPUT_DIR/$category/$year_month"
    mkdir -p "$target_dir"

    target_file="$target_dir/$hash.$extension"

    if [[ -e "$target_file" ]]; then
        return 0
    fi

    ln -- "$file" "$target_file"
}

find_cmd=(find "$INPUT_DIR" -type f)
if [[ "$OUTPUT_DIR" == "$INPUT_DIR" || "$OUTPUT_DIR" == "$INPUT_DIR"/* ]]; then
    find_cmd+=( -not -path "$OUTPUT_DIR/*" )
fi

while IFS= read -r -d '' file; do
    process_file "$file"
done < <("${find_cmd[@]}" -print0)
