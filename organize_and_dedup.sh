#!/usr/bin/env bash

set -uo pipefail

VERSION="0.9.1"

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

warn() {
    printf '[%s] Warning: %s\n' "$(date '+%H:%M:%S')" "$*" >&2
}

usage() {
    cat <<'USAGE'
Usage: organize_and_dedup.sh [options] <input_dir> <output_dir>

Find files recursively in the input directory, detect their correct extension
from MIME/magic, and hardlink them into category/YYYY-MM folders using a
SHA256 filename.

Options:
  -h, --help        Show this help message.
  -v, --version     Show the script version.
  -n, --dry-run     Preview actions without modifying the filesystem.
  -q, --quiet       Suppress per-file log output (summary only).
  --maxdepth N      Limit find recursion depth (default: unlimited).
USAGE
}

# --- Globals (initialized before trap) ---
processed=0
linked=0
skipped=0
duplicates=0
failed=0
copied=0
declare -A existing_hashes=()
declare -A seen_hashes=()

cleanup_on_interrupt() {
    warn "Interrupted. Processed: $processed, linked: $linked, copied: $copied, skipped: $skipped, duplicates: $duplicates, warnings: $failed"
    exit 130
}

cleanup_on_term() {
    warn "Terminated. Processed: $processed, linked: $linked, copied: $copied, skipped: $skipped, duplicates: $duplicates, warnings: $failed"
    exit 143
}

# --- Argument parsing ---
DRY_RUN=0
QUIET=0
MAXDEPTH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            echo "organize_and_dedup.sh $VERSION"
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -q|--quiet)
            QUIET=1
            shift
            ;;
        --maxdepth)
            if [[ -z "${2:-}" || "$2" == -* || ! "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --maxdepth requires a positive integer argument." >&2
                exit 1
            fi
            MAXDEPTH="$2"
            shift 2
            ;;
        --maxdepth=*)
            MAXDEPTH="${1#*=}"
            if [[ ! "$MAXDEPTH" =~ ^[0-9]+$ ]]; then
                echo "Error: --maxdepth requires a positive integer argument." >&2
                exit 1
            fi
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Error: unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "Error: bash 4.0 or newer is required to run this script." >&2
    exit 1
fi

# --- Canonicalize paths (issue #47) ---
INPUT_DIR_RAW="$1"
OUTPUT_DIR_RAW="$2"

# Strip trailing slashes
INPUT_DIR="${INPUT_DIR_RAW%/}"
OUTPUT_DIR="${OUTPUT_DIR_RAW%/}"

# Canonicalize via realpath if available (issue #47)
if command -v realpath >/dev/null 2>&1; then
    INPUT_DIR=$(realpath -- "$INPUT_DIR")
    OUTPUT_DIR_REAL=$(realpath -m -- "$OUTPUT_DIR")
elif command -v readlink >/dev/null 2>&1; then
    INPUT_DIR=$(readlink -f -- "$INPUT_DIR")
    # readlink -m creates the path even if it doesn't exist
    OUTPUT_DIR_REAL=$(readlink -m -- "$OUTPUT_DIR")
else
    OUTPUT_DIR_REAL="$OUTPUT_DIR"
fi

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Error: input directory does not exist: $INPUT_DIR" >&2
    exit 1
fi

if [[ -e "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: output path exists and is not a directory: $OUTPUT_DIR" >&2
    exit 1
fi

# Use canonicalized paths for comparison (issue #47)
if [[ "$INPUT_DIR" == "$OUTPUT_DIR_REAL" ]]; then
    echo "Error: input and output directories must be different." >&2
    exit 1
fi

# --- Tool detection ---
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

DATE_CMD="date"
if command -v gdate >/dev/null 2>&1; then
    DATE_CMD="gdate"
fi

# Issue #52: on macOS, BSD stat/date don't support GNU flags — require gstat/gdate
if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
    if [[ "$STAT_CMD" == "stat" ]]; then
        echo "Error: 'gstat' (GNU stat) not found — required on macOS." >&2
        echo "  On macOS, install GNU coreutils: brew install coreutils" >&2
        exit 1
    fi
    if [[ "$DATE_CMD" == "date" ]]; then
        echo "Error: 'gdate' (GNU date) not found — required on macOS." >&2
        echo "  On macOS, install GNU coreutils: brew install coreutils" >&2
        exit 1
    fi
fi

# Check that all required tools are available
for cmd in file "$HASH_CMD" "$STAT_CMD" "$DATE_CMD"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' command not found." >&2
        if [[ "$cmd" == "gdate" || "$cmd" == "gstat" ]]; then
            echo "  On macOS, install GNU coreutils: brew install coreutils" >&2
        fi
        exit 1
    fi
done

# --- Preflight check: hardlink support (issue #33) ---
check_hardlink_support() {
    local test_a="$OUTPUT_DIR/.hardlink_probe_$$_$RANDOM"
    local test_b="$test_a.link"
    touch -- "$test_a" 2>/dev/null
    if ! ln -- "$test_a" "$test_b" 2>/dev/null; then
        rm -f -- "$test_a" 2>/dev/null
        warn "output filesystem does not support hardlinks — files will be copied instead."
        return 1
    fi
    rm -f -- "$test_a" "$test_b"
    return 0
}

log "Starting organize_and_dedup.sh $VERSION"
log "Input directory: $INPUT_DIR"
log "Output directory: $OUTPUT_DIR"
log "Hash command: $HASH_CMD"
if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY RUN — no files will be modified."
fi

# Create output dir only when not in dry-run mode (review feedback)
if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p -- "$OUTPUT_DIR"
fi
# In dry-run mode, skip writability check if output doesn't exist yet
if [[ "$DRY_RUN" -eq 0 || -d "$OUTPUT_DIR" ]]; then
    if [[ ! -w "$OUTPUT_DIR" ]]; then
        echo "Error: output directory is not writable: $OUTPUT_DIR" >&2
        exit 1
    fi
fi

HARDLINK_OK=1
if [[ "$DRY_RUN" -eq 0 ]]; then
    check_hardlink_support || HARDLINK_OK=0
fi

# Set traps AFTER counters are initialized (issue #31)
trap cleanup_on_interrupt INT
trap cleanup_on_term TERM

# --- Functions ---

get_year_month_from_exif() {
    local file="$1"
    if ! command -v exiftool >/dev/null 2>&1; then
        return 1
    fi

    # Issue #38: explicitly try each tag in priority order
    local exif_date
    for tag in DateTimeOriginal CreateDate MediaCreateDate; do
        exif_date=$(exiftool -s -s -s -"$tag" -d "%Y-%m" -- "$file" 2>/dev/null | head -n 1 || true)
        if [[ "$exif_date" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
            # Issue #38: reject zero/garbage dates
            local year="${exif_date:0:4}"
            local month="${exif_date:5:2}"
            if [[ "$year" -ge 1970 && "$year" -le 2100 && "$month" -ge 1 && "$month" -le 12 ]]; then
                printf '%s' "$exif_date"
                return 0
            fi
        fi
    done

    return 1
}

# Issue #36: detect stat variant once and use single call
STAT_IS_GNU=""
detect_stat_variant() {
    if "$STAT_CMD" -c "%Y" -- / >/dev/null 2>&1; then
        STAT_IS_GNU=1
    else
        STAT_IS_GNU=0
    fi
}
detect_stat_variant

get_year_month_from_stat() {
    local file="$1"
    local timestamp

    if [[ "$STAT_IS_GNU" == "1" ]]; then
        # GNU stat: %Y = mtime epoch
        timestamp=$("$STAT_CMD" -c "%Y" -- "$file" 2>/dev/null || true)
    else
        # BSD stat: -f %m = mtime epoch
        timestamp=$("$STAT_CMD" -f "%m" -- "$file" 2>/dev/null || true)
    fi

    if [[ -z "$timestamp" || "$timestamp" == "0" || "$timestamp" == "-1" ]]; then
        "$DATE_CMD" "+%Y-%m"
        return
    fi

    if "$DATE_CMD" -d "@$timestamp" "+%Y-%m" >/dev/null 2>&1; then
        "$DATE_CMD" -d "@$timestamp" "+%Y-%m"
    else
        "$DATE_CMD" -r "$timestamp" "+%Y-%m"
    fi
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
        tgz) echo "tar.gz" ;;
        *) echo "$ext" ;;
    esac
}

# Issue #17: single file call (was 2)
# Issue #45: lowercase MIME before case matching
# Issue #37: handle text/x-script.python and other variants
# Issue #39: expanded MIME type coverage
get_extension_and_category() {
    local file="$1"
    local mime
    local desc

    # Issue #17: single call, capture both mime and desc
    local file_output
    file_output=$(file --mime-type -b -- "$file" 2>/dev/null || true)
    mime="${file_output,,}"  # Issue #45: lowercase

    if [[ -z "$mime" ]]; then
        warn "unable to read file type for '$file'."
        echo "bin unknown"
        return 0
    fi

    # Issue #39: expanded coverage with additional MIME types
    case "$mime" in
        image/jpeg) echo "jpg images"; return 0 ;;
        image/png) echo "png images"; return 0 ;;
        image/gif) echo "gif images"; return 0 ;;
        image/webp) echo "webp images"; return 0 ;;
        image/tiff) echo "tiff images"; return 0 ;;
        image/avif) echo "avif images"; return 0 ;;
        image/bmp|image/x-ms-bmp) echo "bmp images"; return 0 ;;
        image/svg+xml) echo "svg images"; return 0 ;;
        image/x-icon|image/vnd.microsoft.icon) echo "ico images"; return 0 ;;
        image/jp2|image/x-j2c|image/x-jp2-codestream) echo "jp2 images"; return 0 ;;
        image/pgf|image/x-pgf) echo "pgf images"; return 0 ;;
        image/x-portable-pixmap) echo "ppm images"; return 0 ;;
        image/x-tga) echo "tga images"; return 0 ;;
        image/x-xcf) echo "xcf images"; return 0 ;;
        image/x-exr) echo "exr images"; return 0 ;;
        image/x-dpx) echo "dpx images"; return 0 ;;
        image/vnd.djvu) echo "djvu documents"; return 0 ;;
        image/vnd.fpx) echo "fpx images"; return 0 ;;
        image/vnd.ms-photo|image/jxr) echo "jxr images"; return 0 ;;
        image/vnd.radiance) echo "hdr images"; return 0 ;;
        image/x-canon-cr2) echo "cr2 images"; return 0 ;;
        image/x-canon-cr3) echo "cr3 images"; return 0 ;;
        image/x-canon-crw) echo "crw images"; return 0 ;;
        image/x-fujifilm-raf|image/x-fuji-raf) echo "raf images"; return 0 ;;
        image/x-panasonic-rw2) echo "rw2 images"; return 0 ;;
        image/x-minolta-mrw) echo "mrw images"; return 0 ;;
        image/x-sigma-x3f|image/x-x3f) echo "x3f images"; return 0 ;;
        image/x-sony-pmp) echo "pmp images"; return 0 ;;
        image/x-zeiss-czi) echo "czi images"; return 0 ;;
        image/x-photo-cd) echo "pcd images"; return 0 ;;
        image/x-paintshoppro|image/x-paintnet) echo "psp images"; return 0 ;;
        image/flif) echo "flif images"; return 0 ;;
        image/bpg) echo "bpg images"; return 0 ;;
        image/fits) echo "fits images"; return 0 ;;
        image/heic|image/heif) echo "heic images"; return 0 ;;
        image/jxl) echo "jxl images"; return 0 ;;
        image/vnd.zbrush.pcx|image/x-pcx) echo "pcx images"; return 0 ;;
        image/wmf|image/x-wmf) echo "wmf images"; return 0 ;;
        image/x-ms-emf|image/emf) echo "emf images"; return 0 ;;
        application/postscript) echo "ps documents"; return 0 ;;
        application/vnd.adobe.photoshop) echo "psd images"; return 0 ;;
        video/mp4) echo "mp4 videos"; return 0 ;;
        video/x-m4v) echo "m4v videos"; return 0 ;;
        video/x-ms-asf) echo "asf videos"; return 0 ;;
        video/quicktime) echo "mov videos"; return 0 ;;
        video/m2ts) echo "m2ts videos"; return 0 ;;
        video/x-msvideo) echo "avi videos"; return 0 ;;
        video/x-matroska) echo "mkv videos"; return 0 ;;
        video/webm) echo "webm videos"; return 0 ;;
        video/mpeg) echo "mpeg videos"; return 0 ;;
        video/3gpp) echo "3gp videos"; return 0 ;;
        video/x-flv) echo "flv videos"; return 0 ;;
        video/x-dv) echo "dv videos"; return 0 ;;
        video/x-red-r3d) echo "r3d videos"; return 0 ;;
        video/x-ms-wtv) echo "wtv videos"; return 0 ;;
        application/vnd.rn-realmedia) echo "rm videos"; return 0 ;;
        video/MP2T|video/mp2t) echo "ts videos"; return 0 ;;
        video/x-ms-wmv) echo "wmv videos"; return 0 ;;
        application/x-shockwave-flash) echo "swf videos"; return 0 ;;
        application/mxf) echo "mxf videos"; return 0 ;;
        audio/mpeg) echo "mp3 audio"; return 0 ;;
        audio/x-wav|audio/wav) echo "wav audio"; return 0 ;;
        audio/flac) echo "flac audio"; return 0 ;;
        audio/aac) echo "aac audio"; return 0 ;;
        audio/mp4|audio/x-m4a) echo "m4a audio"; return 0 ;;
        audio/ogg|audio/opus) echo "ogg audio"; return 0 ;;
        audio/x-aiff) echo "aiff audio"; return 0 ;;
        audio/x-pn-realaudio) echo "ra audio"; return 0 ;;
        audio/x-musepack) echo "mpc audio"; return 0 ;;
        audio/x-monkeys-audio|audio/x-ape) echo "ape audio"; return 0 ;;
        audio/audible) echo "aa audio"; return 0 ;;
        audio/midi) echo "mid audio"; return 0 ;;
        audio/AMR|audio/amr) echo "amr audio"; return 0 ;;
        audio/x-ms-wma) echo "wma audio"; return 0 ;;
        audio/vnd.dolby.dd-raw) echo "ac3 audio"; return 0 ;;
        audio/x-mpegurl) echo "m3u playlists"; return 0 ;;
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
        application/rtf|text/rtf) echo "rtf documents"; return 0 ;;
        application/vnd.oasis.opendocument.text) echo "odt documents"; return 0 ;;
        application/vnd.oasis.opendocument.spreadsheet) echo "ods documents"; return 0 ;;
        application/vnd.oasis.opendocument.presentation) echo "odp documents"; return 0 ;;
        application/vnd.oasis.opendocument.text-template) echo "ott documents"; return 0 ;;
        application/vnd.oasis.opendocument.spreadsheet-template) echo "ots documents"; return 0 ;;
        application/vnd.oasis.opendocument.presentation-template) echo "otp documents"; return 0 ;;
        application/vnd.oasis.opendocument.graphics|application/vnd.oasis.opendocument.graphics-template)
            echo "odg documents"; return 0 ;;
        application/epub+zip) echo "epub documents"; return 0 ;;
        application/x-mobipocket-ebook) echo "mobi documents"; return 0 ;;
        application/vnd.ms-htmlhelp|application/x-chm) echo "chm documents"; return 0 ;;
        # Codex review: don't default all OLE containers to .doc — disambiguate
        application/x-ole-storage|application/vnd.ms-office)
            local ole_desc
            ole_desc=$(file -b -- "$file" 2>/dev/null || true)
            case "$ole_desc" in
                *MSI*Installer*) echo "msi archives"; return 0 ;;
                *Outlook*) echo "msg email"; return 0 ;;
                *Excel*) echo "xls documents"; return 0 ;;
                *PowerPoint*) echo "ppt documents"; return 0 ;;
                *Visio*) echo "vsdx documents"; return 0 ;;
                *) echo "doc documents"; return 0 ;;
            esac ;;
        application/vnd.ms-outlook) echo "msg email"; return 0 ;;
        application/mbox) echo "mbox email"; return 0 ;;
        message/rfc822) echo "eml email"; return 0 ;;
        application/vnd.visio.drawing.main+xml|application/vnd.ms-visio.drawing.main+xml) echo "vsdx documents"; return 0 ;;
        application/vnd.sketchup.skp) echo "skp documents"; return 0 ;;
        application/x-indesign) echo "indd documents"; return 0 ;;
        application/x-plist) echo "plist config"; return 0 ;;
        text/calendar) echo "ics documents"; return 0 ;;
        text/vcard) echo "vcf documents"; return 0 ;;
        text/plain)
            # Issue #37: filename-based fallback for code files that libmagic
            # reports as text/plain (Go, Rust, TOML, Markdown, YAML, etc.)
            local basename="${file##*/}"
            local ext="${basename##*.}"
            ext="${ext,,}"
            if [[ "$ext" != "$basename" ]]; then
                case "$ext" in
                    py) echo "py code"; return 0 ;;
                    js|mjs) echo "js code"; return 0 ;;
                    ts) echo "ts code"; return 0 ;;
                    go) echo "go code"; return 0 ;;
                    rs) echo "rs code"; return 0 ;;
                    rb) echo "rb code"; return 0 ;;
                    java) echo "java code"; return 0 ;;
                    c|h) echo "c code"; return 0 ;;
                    cpp|cc|cxx) echo "cpp code"; return 0 ;;
                    sh|bash|zsh) echo "sh code"; return 0 ;;
                    sql) echo "sql text"; return 0 ;;
                    md|markdown) echo "md text"; return 0 ;;
                    yaml|yml) echo "yaml text"; return 0 ;;
                    toml) echo "toml text"; return 0 ;;
                    css) echo "css text"; return 0 ;;
                    pl|pm) echo "pl code"; return 0 ;;
                    bat|cmd) echo "bat code"; return 0 ;;
                    ps1) echo "ps1 code"; return 0 ;;
                    log) echo "log text"; return 0 ;;
                    ini|conf|cfg|properties) echo "ini text"; return 0 ;;
                    tex) echo "tex text"; return 0 ;;
                    srt) echo "srt subtitles"; return 0 ;;
                    vtt) echo "vtt subtitles"; return 0 ;;
                esac
            fi
            echo "txt text"; return 0 ;;
        text/csv) echo "csv text"; return 0 ;;
        text/x-env) echo "env text"; return 0 ;;
        text/x-php|application/x-httpd-php) echo "php code"; return 0 ;;
        # Issue #37: handle all Python MIME variants
        text/x-python|text/x-python3|text/x-script.python) echo "py code"; return 0 ;;
        application/x-bytecode.python) echo "pyc code"; return 0 ;;
        text/x-sh|text/x-shellscript|text/x-bash|text/x-zsh) echo "sh code"; return 0 ;;
        text/x-perl) echo "pl code"; return 0 ;;
        text/x-ruby) echo "rb code"; return 0 ;;
        text/x-java) echo "java code"; return 0 ;;
        # Issue #37: handle C/C++ variants (file returns text/x-c for Go, text/x-c++ for Java)
        text/x-c) echo "c code"; return 0 ;;
        text/x-c++|text/x-cplusplus) echo "cpp code"; return 0 ;;
        text/x-asm) echo "asm code"; return 0 ;;
        text/x-makefile) echo "makefile code"; return 0 ;;
        text/x-diff) echo "diff text"; return 0 ;;
        text/troff|text/x-tex) echo "txt text"; return 0 ;;
        application/json|text/json|application/x-ndjson) echo "json text"; return 0 ;;
        text/xml|application/xml|application/xhtml+xml) echo "xml text"; return 0 ;;
        text/html) echo "html text"; return 0 ;;
        application/javascript|text/javascript) echo "js code"; return 0 ;;
        application/x-gettext-translation) echo "po text"; return 0 ;;
        text/x-po) echo "po text"; return 0 ;;
        text/x-msdos-batch) echo "bat code"; return 0 ;;
        text/vtt) echo "vtt subtitles"; return 0 ;;
        application/x-subrip) echo "srt subtitles"; return 0 ;;
        text/x-m4) echo "m4 text"; return 0 ;;
        application/zip) echo "zip archives"; return 0 ;;
        application/x-7z-compressed) echo "7z archives"; return 0 ;;
        application/x-rar|application/vnd.rar) echo "rar archives"; return 0 ;;
        application/x-tar) echo "tar archives"; return 0 ;;
        # Issue #34: detect tar.gz before plain gz
        # file returns application/gzip for both .gz and .tar.gz — need to check
        # the description to distinguish
        application/gzip|application/x-gzip)
            # Check if this is actually a tar.gz by decompressing and checking
            # file -b only shows "gzip compressed data" — need -z to look inside
            local desc
            desc=$(file -bz -- "$file" 2>/dev/null || true)
            if [[ "$desc" == *"tar archive"* ]]; then
                echo "tar.gz archives"
            else
                echo "gz archives"
            fi
            return 0 ;;
        application/x-bzip2) echo "bz2 archives"; return 0 ;;
        application/x-xz) echo "xz archives"; return 0 ;;
        application/x-iso9660-image) echo "iso archives"; return 0 ;;
        # Issue #39: add RPM, DEB, and other common archive types
        application/x-rpm) echo "rpm archives"; return 0 ;;
        application/vnd.debian.binary-package|application/x-archive) echo "deb archives"; return 0 ;;
        application/vnd.ms-msi|application/x-msi) echo "msi archives"; return 0 ;;
        application/vnd.android.package-archive) echo "apk archives"; return 0 ;;
        application/x-lzh-compressed) echo "lha archives"; return 0 ;;
        application/zlib) echo "zlib archives"; return 0 ;;
        application/x-compress) echo "Z archives"; return 0 ;;
        application/x-lzma) echo "lzma archives"; return 0 ;;
        application/x-arc) echo "arc archives"; return 0 ;;
        application/x-bittorrent) echo "torrent archives"; return 0 ;;
        application/java-archive|application/x-java-applet) echo "jar archives"; return 0 ;;
        application/x-executable|application/x-pie-executable|application/x-sharedlib|application/x-msdownload|application/vnd.microsoft.portable-executable|application/x-object|application/x-dosexec|application/x-mach-binary)
            echo "exe executables"; return 0 ;;
        application/wasm) echo "wasm executables"; return 0 ;;
        application/x-ms-shortcut) echo "lnk executables"; return 0 ;;
        application/x-mswinurl) echo "url text"; return 0 ;;
        application/vnd.sqlite3) echo "sqlite databases"; return 0 ;;
        application/x-gdbm) echo "gdbm databases"; return 0 ;;
        application/vnd.iccprofile) echo "icc data"; return 0 ;;
        application/dicom) echo "dcm images"; return 0 ;;
        application/dxf|image/vnd.dxf) echo "dxf documents"; return 0 ;;
        application/vnd.tcpdump.pcap) echo "pcap data"; return 0 ;;
        application/x-numpy-data) echo "npy data"; return 0 ;;
        application/x-hdf5) echo "h5 data"; return 0 ;;
        application/fits) echo "fits data"; return 0 ;;
        application/x-cdf) echo "cdf data"; return 0 ;;
        application/x-matlab-data) echo "mat data"; return 0 ;;
        application/x-stargallery-thm) echo "thm data"; return 0 ;;
        application/x-adobe-aco) echo "aco data"; return 0 ;;
        application/x-dbt) echo "dbt data"; return 0 ;;
        application/etl) echo "etl data"; return 0 ;;
        application/x-ibm-rom|application/x-genesis-rom|application/x-sms-rom|application/x-nes-rom|application/x-ms-sdi|application/x-commodore-exec|application/x-commodore-basic|application/x-ms-dat|application/x-linux-kernel) echo "rom firmware"; return 0 ;;
        application/x-qemu-disk|application/x-floppy-image-tc) echo "img firmware"; return 0 ;;
        application/x-pem-file|application/x-putty-private-key|text/x-ssl-private-key|text/pgp|application/pgp-signature) echo "pem certs"; return 0 ;;
        application/x-git) echo "git data"; return 0 ;;
        application/x-font-type1) echo "pfb fonts"; return 0 ;;
        application/x-font-pfm) echo "pfm fonts"; return 0 ;;
        application/x-dfont) echo "dfont fonts"; return 0 ;;
        application/font-ttf|font/ttf) echo "ttf fonts"; return 0 ;;
        application/font-otf|application/vnd.ms-opentype|font/otf) echo "otf fonts"; return 0 ;;
        font/woff) echo "woff fonts"; return 0 ;;
        font/woff2) echo "woff2 fonts"; return 0 ;;
        font/sfnt) echo "ttf fonts"; return 0 ;;
        font/x-postscript-pfb) echo "pfb fonts"; return 0 ;;
        application/vnd.ms-fontobject) echo "eot fonts"; return 0 ;;
        font/x-amiga-font) echo "amiga fonts"; return 0 ;;
        # Issue #39: add markdown, YAML, TOML, CSS, SQL as text
        text/markdown) echo "md text"; return 0 ;;
        text/x-yaml|text/yaml) echo "yaml text"; return 0 ;;
        text/css) echo "css text"; return 0 ;;
        text/x-sql) echo "sql text"; return 0 ;;
        application/yaml|application/x-yaml) echo "yaml text"; return 0 ;;
        application/x-setupscript|application/x-wine-extension-ini) echo "ini text"; return 0 ;;
        text/x-ms-regedit) echo "reg text"; return 0 ;;
        application/x-bplist) echo "plist config"; return 0 ;;
        application/octet-stream)
            # Phase 2: second-pass identification using file -b description
            # file --mime-type reports octet-stream for many identifiable files
            # (minified JS, Python scripts, ELF objects, DOS COM, BIOS ROMs, etc.)
            local desc
            desc=$(file -b -- "$file" 2>/dev/null || true)
            case "$desc" in
                *JavaScript*) echo "js code"; return 0 ;;
                *Python*script*) echo "py code"; return 0 ;;
                *Node.js*) echo "js code"; return 0 ;;
                *ELF*) echo "exe executables"; return 0 ;;
                *DOS\ executable*|*PE32*) echo "exe executables"; return 0 ;;
                *Composite\ Document*MSI*) echo "msi archives"; return 0 ;;
                *Composite\ Document*) echo "doc documents"; return 0 ;;
                *BIOS*ROM*|*ROM\ Ext*) echo "rom firmware"; return 0 ;;
                *Android\ package*|*Android\ binary\ XML*) echo "apk archives"; return 0 ;;
                *PCX*) echo "pcx images"; return 0 ;;
                *Adobe\ Photoshop*) echo "psd images"; return 0 ;;
                *SubRip*) echo "srt subtitles"; return 0 ;;
                *Audio\ file\ with\ ID3*) echo "mp3 audio"; return 0 ;;
                *OpenPGP*Key*) echo "pem certs"; return 0 ;;
                *PGP\ signature*) echo "pem certs"; return 0 ;;
                *GNU\ gettext*|*GNU\ message\ catalog*) echo "po text"; return 0 ;;
                *Generic\ INItialization*) echo "ini text"; return 0 ;;
                *Windows\ setup\ INF*) echo "ini text"; return 0 ;;
                *LHa*archive*) echo "lha archives"; return 0 ;;
                *zlib\ compressed*) echo "zlib archives"; return 0 ;;
                *Squashfs\ filesystem*) echo "sqsh archives"; return 0 ;;
                *AutoCAD\ Drawing*) echo "dxf documents"; return 0 ;;
                *TeX\ font\ metric*) echo "tfm text"; return 0 ;;
                *SQLite*) echo "sqlite databases"; return 0 ;;
                *DER\ Encoded*) echo "pem certs"; return 0 ;;
                *Windows\ Enhanced\ Metafile*) echo "emf images"; return 0 ;;
                *ISO\ Media*) echo "iso archives"; return 0 ;;
                *Applesoft\ BASIC*) echo "bas code"; return 0 ;;
                *current\ ar\ archive*) echo "a archives"; return 0 ;;
                *XENIX*relocatable*) echo "exe executables"; return 0 ;;
                *Microsoft\ ASF*) echo "asf videos"; return 0 ;;
                *Excel*BIFF*) echo "xls documents"; return 0 ;;
                *ESP-IDF*|*firmware*) echo "rom firmware"; return 0 ;;
                *MSX\ ROM*|*Genesis\ ROM*|*NES\ ROM*) echo "rom firmware"; return 0 ;;
            esac
            # Truly unidentifiable binary data
            echo "bin unknown"; return 0 ;;
    esac

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

    if [[ "$QUIET" -eq 0 ]]; then
        log "Processing: $file"
    fi

    if [[ ! -r "$file" ]]; then
        ((++skipped))
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
        ((++skipped))
        ((++failed))
        warn "failed to compute hash for '$file'."
        return 0
    fi
    hash=${hash^^}

    if [[ -n "${seen_hashes[$hash]:-}" ]]; then
        ((++duplicates))
        if [[ "$QUIET" -eq 0 ]]; then
            log "Duplicate detected (already processed hash): $file"
        fi
        return 0
    fi

    if [[ -n "${existing_hashes[$hash]:-}" ]]; then
        ((++duplicates))
        if [[ "$QUIET" -eq 0 ]]; then
            log "Duplicate detected (already in output): $file"
        fi
        # Issue #51: store the hash key only, not a stale path that may be deleted mid-run
        seen_hashes[$hash]=1
        return 0
    fi

    target_dir="$OUTPUT_DIR/$category/$year_month"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        target_file="$target_dir/$hash.$extension"
        ((++linked))
        if [[ "$QUIET" -eq 0 ]]; then
            log "[DRY RUN] Would link to: $target_file"
        fi
        seen_hashes[$hash]=1
        return 0
    fi

    if ! mkdir -p -- "$target_dir"; then
        ((++failed))
        warn "failed to create directory '$target_dir'."
        return 0
    fi

    target_file="$target_dir/$hash.$extension"

    if [[ -e "$target_file" ]]; then
        ((++duplicates))
        if [[ "$QUIET" -eq 0 ]]; then
            log "Duplicate detected (already exists): $target_file"
        fi
        seen_hashes[$hash]=1
        return 0
    fi

    if compgen -G "$target_dir/$hash.*" >/dev/null; then
        ((++duplicates))
        if [[ "$QUIET" -eq 0 ]]; then
            log "Duplicate detected (same hash in directory): $file"
        fi
        seen_hashes[$hash]=1
        return 0
    fi

    action="Linked"
    if [[ "$HARDLINK_OK" -eq 1 ]]; then
        if ! ln -- "$file" "$target_file"; then
            # Issue #25: warn loudly when falling back to copy
            warn "WARNING: hardlink failed for '$file' -> '$target_file', falling back to copy. File was COPIED, not hardlinked."
            if ! cp -p -- "$file" "$target_file"; then
                ((++failed))
                warn "failed to copy '$file' -> '$target_file'."
                return 0
            fi
            ((++copied))
            action="Copied"
        fi
    else
        # Issue #25: when hardlinks not supported, copy with explicit loud warning
        warn "WARNING: hardlinks not supported on output filesystem — copying '$file' -> '$target_file'. File was COPIED, not hardlinked."
        if ! cp -p -- "$file" "$target_file"; then
            ((++failed))
            warn "failed to copy '$file' -> '$target_file'."
            return 0
        fi
        ((++copied))
        action="Copied"
    fi

    ((++linked))
    seen_hashes[$hash]=1
    if [[ "$QUIET" -eq 0 ]]; then
        log "$action to: $target_file"
    fi
}

# --- Pre-scan existing output for hash dedup (issue #42: note about O(N)) ---
# Issue #48: also hash pre-existing files that don't follow <64hex>.<ext> naming
if [[ -d "$OUTPUT_DIR" ]]; then
    # Issue #41: use -- before path
    # Issue #30: use canonical path and -L to follow symlinks
    while IFS= read -r -d '' existing_file; do
        base_name=${existing_file##*/}
        hash_candidate=${base_name%%.*}
        if [[ "$hash_candidate" =~ ^[0-9A-Fa-f]{64}$ ]]; then
            existing_hashes[${hash_candidate^^}]="$existing_file"
        else
            # Issue #48: hash pre-existing files with non-hash names
            if [[ -r "$existing_file" ]]; then
                local_hash=$(hash_file "$existing_file")
                if [[ -n "$local_hash" ]]; then
                    existing_hashes[${local_hash^^}]="$existing_file"
                fi
            fi
        fi
    done < <(find -L -- "$OUTPUT_DIR" -type f -print0)
fi

# --- Build find command ---
# Issue #41: use -- before paths
# Issue #30: use -L to follow symlinked directories, and use canonical INPUT_DIR
# Note: -maxdepth must come before other expressions in find
find_cmd=(find -L -- "$INPUT_DIR")
if [[ -n "$MAXDEPTH" ]]; then
    find_cmd+=( -maxdepth "$MAXDEPTH" )
fi
find_cmd+=( -type f )

# Issue #47: compare canonical paths for output exclusion
if [[ "$OUTPUT_DIR_REAL" == "$INPUT_DIR" || "$OUTPUT_DIR_REAL" == "$INPUT_DIR"/* ]]; then
    find_cmd+=( -not -path "$OUTPUT_DIR_REAL/*" )
fi

# --- Main loop ---
while IFS= read -r -d '' file; do
    ((++processed))
    process_file "$file"
done < <("${find_cmd[@]}" -print0)

log "Completed. Processed: $processed, linked: $linked, copied: $copied, skipped: $skipped, duplicates: $duplicates, warnings: $failed"
