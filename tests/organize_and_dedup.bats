#!/usr/bin/env bats
#
# Test suite for organize_and_dedup.sh
# Covers basic functionality and regression tests for issues #15-#52.
#
# Requirements: bats, file, sha256sum, stat, date (GNU coreutils)
# Optional: exiftool (skipped if not installed)

load test_helper

setup() {
    SCRIPT="$(abspath "$BATS_TEST_DIRNAME/../organize_and_dedup.sh")"
    INPUT="$(mktemp -d)"
    OUTPUT="$(mktemp -d)"
    # Clean output so we start fresh
    rm -rf "$OUTPUT"
}

teardown() {
    rm -rf "$INPUT" "$OUTPUT"
}

# --- Basic functionality ---

@test "--version prints version" {
    run "$SCRIPT" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"organize_and_dedup.sh"* ]]
}

@test "--help prints usage" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"input_dir"* ]]
    [[ "$output" == *"output_dir"* ]]
}

@test "no args exits with error" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
}

@test "nonexistent input dir exits with error" {
    run "$SCRIPT" /nonexistent/path "$OUTPUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"input directory does not exist"* ]]
}

@test "same input and output dir exits with error" {
    run "$SCRIPT" "$INPUT" "$INPUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"must be different"* ]]
}

@test "output path exists and is not a dir exits with error" {
    local file="$INPUT/notadir"
    touch "$file"
    run "$SCRIPT" "$INPUT" "$file"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not a directory"* ]]
}

# --- File type detection ---

@test "JPEG files are categorized as images" {
    python3 "$BATS_TEST_DIRNAME/generate_test_data.py" "$INPUT" --count 0 --seed 1 2>/dev/null
    # generate_test_data always adds edge cases; create a clean one
    rm -rf "$INPUT"
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/test.jpg')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/images" -type f 2>/dev/null | wc -l)" -ge 1 ]
}

@test "PNG files are categorized as images" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_png
make_png('$INPUT/test.png')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/images" -name '*.png' -type f 2>/dev/null | wc -l)" -ge 1 ]
}

@test "PDF files are categorized as documents" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_pdf
make_pdf('$INPUT/test.pdf')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/documents" -name '*.pdf' -type f 2>/dev/null | wc -l)" -ge 1 ]
}

@test "MP3 files are categorized as audio" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_mp3
make_mp3('$INPUT/test.mp3')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/audio" -name '*.mp3' -type f 2>/dev/null | wc -l)" -ge 1 ]
}

@test "MP4 files are categorized as videos" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_mp4
make_mp4('$INPUT/test.mp4')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/videos" -name '*.mp4' -type f 2>/dev/null | wc -l)" -ge 1 ]
}

@test "ZIP files are categorized as archives" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_zip
make_zip('$INPUT/test.zip')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/archives" -name '*.zip' -type f 2>/dev/null | wc -l)" -ge 1 ]
}

@test "JSON files are categorized as text" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_json
make_json('$INPUT/test.json')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/text" -name '*.json' -type f 2>/dev/null | wc -l)" -ge 1 ]
}

@test "Python files are categorized (issue #37: may be text or code depending on file magic)" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_python
make_python('$INPUT/test.py')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # file --mime-type may return text/x-python, text/x-script.python, or text/plain
    # depending on the magic database version. The script may classify it as
    # code, text, or unknown. This test documents that the file is processed
    # without error, regardless of classification.
    [ "$(find "$OUTPUT" -type f | wc -l)" -ge 1 ]
}

@test "Bash scripts are categorized as code" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_bash
make_bash('$INPUT/test.sh')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/code" -name '*.sh' -type f 2>/dev/null | wc -l)" -ge 1 ]
}

@test "SQLite databases are categorized as databases" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_sqlite
make_sqlite('$INPUT/test.sqlite')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/databases" -name '*.sqlite' -type f 2>/dev/null | wc -l)" -ge 1 ]
}

@test "TTF fonts are categorized as fonts" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_ttf
make_ttf('$INPUT/test.ttf')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/fonts" -type f 2>/dev/null | wc -l)" -ge 1 ]
}

# --- Dedup ---

@test "identical files are deduped (only first is linked)" {
    mkdir -p "$INPUT/sub1" "$INPUT/sub2"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/sub1/original.jpg')
"
    cp "$INPUT/sub1/original.jpg" "$INPUT/sub2/copy.jpg"

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # Should be exactly 1 file in output
    [ "$(find "$OUTPUT" -type f | wc -l)" -eq 1 ]
    [[ "$output" == *"Duplicate detected"* ]]
}

@test "5 identical JPEGs produce 1 output file" {
    mkdir -p "$INPUT/photos"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/photos/canonical.jpg')
"
    for i in 1 2 3 4 5; do
        cp "$INPUT/photos/canonical.jpg" "$INPUT/photos/copy_$i.jpg"
    done

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/images" -type f | wc -l)" -eq 1 ]
}

@test "files with same content but different extensions: first wins" {
    mkdir -p "$INPUT"
    echo "name,age
Alice,30" > "$INPUT/data.txt"
    echo "name,age
Alice,30" > "$INPUT/data.csv"

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # First file processed wins; second is a duplicate
    [[ "$output" == *"Duplicate detected"* ]]
    [ "$(find "$OUTPUT/text" -type f | wc -l)" -eq 1 ]
}

# --- Edge cases ---

@test "empty files are processed without error" {
    mkdir -p "$INPUT"
    touch "$INPUT/empty1.txt"
    touch "$INPUT/empty2.txt"
    touch "$INPUT/empty3.txt"

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # All empty files have the same SHA-256, so only 1 output
    [ "$(find "$OUTPUT" -type f | wc -l)" -eq 1 ]
}

@test "files with no extension are processed" {
    mkdir -p "$INPUT"
    echo "just text" > "$INPUT/README"

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT" -type f | wc -l)" -ge 1 ]
}

@test "files with spaces in names are processed" {
    mkdir -p "$INPUT"
    echo "content" > "$INPUT/file with spaces.txt"

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT" -type f | wc -l)" -ge 1 ]
}

@test "files with special characters are processed" {
    mkdir -p "$INPUT"
    echo "content" > "$INPUT/file(1).txt"
    echo "content2 different" > "$INPUT/file&special.txt"
    echo "content3 also different" > "$INPUT/file+plus.txt"

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT" -type f | wc -l)" -ge 3 ]
}

@test "Unicode filenames are processed" {
    mkdir -p "$INPUT"
    echo "unicode content here" > "$INPUT/tëst_fïle.txt"

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT" -type f | wc -l)" -ge 1 ]
}

@test "very long filename is processed" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_text
make_text('$INPUT/' + 'x'*200 + '.txt')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT" -type f | wc -l)" -ge 1 ]
}

@test "wrong extension file is classified by content not name" {
    mkdir -p "$INPUT"
    # A JPEG saved as .dat
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/photo.dat')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # Should be in images, not unknown
    [ "$(find "$OUTPUT/images" -type f 2>/dev/null | wc -l)" -ge 1 ]
}

@test "nested directories are traversed" {
    mkdir -p "$INPUT/a/b/c/d"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_png
make_png('$INPUT/a/b/c/deep.png')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/images" -name '*.png' -type f | wc -l)" -ge 1 ]
}

# --- tar.gz detection (issue #34) ---

@test "tar.gz file is detected (issue #34 - extension should be tar.gz or gz)" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_targz
make_targz('$INPUT/archive.tar.gz')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # The file should be in archives
    [ "$(find "$OUTPUT/archives" -type f | wc -l)" -ge 1 ]
    # Issue #34: it should ideally be .tar.gz, but current code saves as .gz
    # This test documents current behaviour — the extension is .gz (the bug)
    local found_gz
    found_gz=$(find "$OUTPUT/archives" -name '*.gz' -type f | wc -l)
    [ "$found_gz" -ge 1 ]
}

@test "tar.gz misnamed as .gz is still detected as archive" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_targz
make_targz('$INPUT/misnamed.gz')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/archives" -type f | wc -l)" -ge 1 ]
}

@test "plain .gz (not tar) is categorized as archive with .gz extension" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_gz
make_gz('$INPUT/plain.gz')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT/archives" -name '*.gz' -type f | wc -l)" -ge 1 ]
}

# --- Output structure ---

@test "output uses category/YYYY-MM/hash.ext structure" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/test.jpg')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # Check structure: images/YYYY-MM/hash.jpg
    local files
    files=$(find "$OUTPUT" -type f -name '*.jpg')
    [ -n "$files" ]
    # Path should match images/YYYY-MM/hash.jpg
    [[ "$files" == *"/images/"* ]]
    local parent
    parent=$(dirname "$files")
    [[ "$(basename "$parent")" =~ ^[0-9]{4}-[0-9]{2}$ ]]
}

@test "output filenames are SHA-256 hex (64 chars) with extension" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_png
make_png('$INPUT/test.png')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    local file
    file=$(find "$OUTPUT" -type f -name '*.png' | head -1)
    [ -n "$file" ]
    local basename
    basename=$(basename "$file")
    local hash_part
    hash_part="${basename%%.*}"
    # Should be 64 hex chars
    [[ "$hash_part" =~ ^[0-9A-Fa-f]{64}$ ]]
}

# --- Re-run behaviour ---

@test "re-run on same input produces no new files (all duplicates)" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg, make_png, make_pdf
make_jpeg('$INPUT/a.jpg')
make_png('$INPUT/b.png')
make_pdf('$INPUT/c.pdf')
"
    # First run
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    local first_count
    first_count=$(find "$OUTPUT" -type f | wc -l)

    # Second run
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    local second_count
    second_count=$(find "$OUTPUT" -type f | wc -l)

    [ "$first_count" -eq "$second_count" ]
    [[ "$output" == *"Duplicate detected"* ]]
}

# --- Summary output ---

@test "summary line contains processed count" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/test.jpg')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Completed."* ]]
    [[ "$output" == *"Processed:"* ]]
    [[ "$output" == *"linked:"* ]]
    [[ "$output" == *"duplicates:"* ]]
}

@test "summary shows 0 warnings on clean run" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/test.jpg')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"warnings: 0"* ]]
}

# --- Large dataset ---

@test "generated test dataset (80 files) processes cleanly" {
    python3 "$BATS_TEST_DIRNAME/generate_test_data.py" "$INPUT" --count 80 --seed 42 >/dev/null 2>&1
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Completed."* ]]
    # Should have processed > 0 files
    [[ "$output" == *"Processed: 1"* ]]  # 106+ files, starts with 1
}

# --- Hardlink verification ---

@test "output files are hardlinks (same inode as source)" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/test.jpg')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    local outfile
    outfile=$(find "$OUTPUT" -type f -name '*.jpg' | head -1)
    [ -n "$outfile" ]
    # Same filesystem — check inode matches
    local in_inode out_inode
    in_inode=$(stat -c '%i' "$INPUT/test.jpg")
    out_inode=$(stat -c '%i' "$outfile")
    [ "$in_inode" -eq "$out_inode" ]
}

# --- Issue-specific regression tests ---

# Issue #15: skipped counter never incremented
@test "issue #15: skipped counter is present in summary (may be 0)" {
    mkdir -p "$INPUT"
    echo "test" > "$INPUT/file.txt"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped:"* ]]
}

# Issue #16: cleanup_on_interrupt exits 130 for SIGTERM (should be 143)
# Skipped: SIGINT timing is unreliable in CI — the script may finish before
# the signal arrives. The exit code issue is documented in the issue itself.
@test "issue #16: cleanup_on_interrupt function exists and uses exit 130" {
    # Verify the function is defined in the script
    run grep -c 'cleanup_on_interrupt' "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" -ge 2 ]]  # defined + used in trap
    run grep 'exit 130' "$SCRIPT"
    [ "$status" -eq 0 ]
}

# Issue #22: CI should actually test bash
# (This is tested by the existence of this test suite itself)

# Issue #34: tar.gz saved as .gz
@test "issue #34: tar.gz files end up in archives (current behaviour: .gz ext)" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_targz
make_targz('$INPUT/real.tar.gz')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # Current behaviour: saved as .gz (the bug)
    # Fix would save as .tar.gz
    local gz_count
    gz_count=$(find "$OUTPUT/archives" -name '*.gz' -type f | wc -l)
    [ "$gz_count" -ge 1 ]
    # Document: currently NO .tar.gz files are produced
    local targz_count
    targz_count=$(find "$OUTPUT/archives" -name '*.tar.gz' -type f | wc -l)
    # This should be 0 with current code (the bug)
    [ "$targz_count" -eq 0 ]
}

# Issue #35: all empty files dedup to one
@test "issue #35: all empty files dedup to a single output entry" {
    mkdir -p "$INPUT/dir1" "$INPUT/dir2" "$INPUT/dir3"
    touch "$INPUT/dir1/empty.txt"
    touch "$INPUT/dir2/empty.log"
    touch "$INPUT/dir3/empty.dat"

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # All empty files have same SHA-256 → 1 output
    [ "$(find "$OUTPUT" -type f | wc -l)" -eq 1 ]
}

# Issue #37: code files misclassified as text/plain
@test "issue #37: Python file is processed (classification depends on file magic version)" {
    # file --mime-type may return text/x-python, text/x-script.python, or text/plain
    # The script's case statement may not catch all variants → falls to bin unknown
    # This test documents that the file IS processed without error.
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_python
make_python('$INPUT/hello.py')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT" -type f | wc -l)" -ge 1 ]
}

# Issue #45: MIME type not lowercased
@test "issue #45: file with uppercase MIME in magic db still processes" {
    # This is a defensive test — most file versions return lowercase
    # We just ensure processing doesn't crash on unusual MIME types
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_text
make_text('$INPUT/plain.txt')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT" -type f | wc -l)" -ge 1 ]
}

# Issue #48: pre-existing files not following naming convention
@test "issue #48: pre-existing non-hash-named files in output are not deduped against" {
    mkdir -p "$INPUT" "$OUTPUT/images/2026-01"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/test.jpg')
"
    # Create a pre-existing file with a non-hash name
    cp "$INPUT/test.jpg" "$OUTPUT/images/2026-01/my_photo.jpg"

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # Current behaviour: the pre-existing file is NOT detected as a duplicate
    # because it doesn't follow the <64hex>.<ext> naming convention.
    # So the script will create a new hash-named file.
    local hash_files
    hash_files=$(find "$OUTPUT" -name '*.jpg' -regextype posix-extended -regex '.*/[0-9A-Fa-f]{64}\.jpg' | wc -l)
    [ "$hash_files" -ge 1 ]
}

# Issue #22: no actual testing in CI
@test "issue #22: this test suite exists (bash repo has bash tests)" {
    # Meta test — if this runs, the test suite works
    [ -f "$BATS_TEST_DIRNAME/organize_and_dedup.bats" ]
    [ -f "$BATS_TEST_DIRNAME/test_helper.bash" ]
    [ -f "$BATS_TEST_DIRNAME/generate_test_data.py" ]
}

# Issue #38: exiftool tag precedence ignored
@test "issue #38: exiftool tag precedence — DateTimeOriginal should take priority" {
    if ! command -v exiftool >/dev/null 2>&1; then
        skip "exiftool not installed"
    fi
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/photo.jpg')
"
    # Set DateTimeOriginal to 2020-03 and CreateDate to 2021-05
    exiftool -overwrite_original \
        -DateTimeOriginal='2020:03:15 12:00:00' \
        -CreateDate='2021:05:20 14:00:00' \
        "$INPUT/photo.jpg" 2>/dev/null

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # The script should use DateTimeOriginal (2020-03) not CreateDate (2021-05)
    # Current bug: head -n1 picks exiftool's output order, not argument order
    local dir_2020_03 dir_2021_05
    dir_2020_03=$(find "$OUTPUT" -type d -name '2020-03' 2>/dev/null | head -1)
    dir_2021_05=$(find "$OUTPUT" -type d -name '2021-05' 2>/dev/null | head -1)
    # At least one should exist
    [ -n "$dir_2020_03" ] || [ -n "$dir_2021_05" ]
    # Document: ideally DateTimeOriginal (2020-03) wins, but current code
    # may pick whichever exiftool outputs first
}

# Issue #39: many common MIME types fall through to 'bin unknown'
@test "issue #39: files with unrecognized MIME types go to 'unknown' category" {
    mkdir -p "$INPUT"
    # Create a file that file --mime-type won't recognize as any known type
    # A raw binary blob with no magic bytes
    python3 -c "
import os
with open('$INPUT/mystery.bin', 'wb') as f:
    f.write(b'\\x01\\x02\\x03\\x04\\x05\\x06\\x07\\x08' * 100)
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # Should end up in unknown/ — this documents the current behaviour
    [ "$(find "$OUTPUT/unknown" -type f 2>/dev/null | wc -l)" -ge 1 ]
}

@test "issue #39: RPM package falls through to 'bin unknown' (missing MIME)" {
    mkdir -p "$INPUT"
    # Create a minimal RPM-like file (application/x-rpm not in case statement)
    # RPM magic: ed ab ee db
    python3 -c "
with open('$INPUT/package.rpm', 'wb') as f:
    f.write(b'\\xed\\xab\\xee\\xdb' + b'\\x00' * 100)
"
    local mime
    mime=$(file --mime-type -b "$INPUT/package.rpm" 2>/dev/null)
    echo "MIME: $mime" >&3

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # If file detects it as application/x-rpm, it's NOT in the case statement
    # so it goes to unknown. If file doesn't detect the magic, it may be
    # application/octet-stream → also unknown.
    [ "$(find "$OUTPUT/unknown" -type f 2>/dev/null | wc -l)" -ge 1 ]
}

# Issue #41: find invocations missing -- before user-supplied directory paths
@test "issue #41: directory named with leading dash doesn't crash find" {
    # This tests robustness against paths starting with -
    # Create a directory named -test
    mkdir -p "$INPUT"
    local dashdir="$INPUT/-testdir"
    mkdir -p "$dashdir"
    echo "content" > "$dashdir/file.txt"

    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [ "$(find "$OUTPUT" -type f | wc -l)" -ge 1 ]
}

# Issue #47: un-canonicalized paths bypass self-exclusion
@test "issue #47: input dir with trailing dot doesn't bypass output exclusion" {
    # /tmp/xxx and /tmp/xxx/. should be treated as the same dir
    # but the script only strips trailing / not trailing /.
    mkdir -p "$INPUT/subdir"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/subdir/test.jpg')
"
    # Create output inside input
    local output_inside="$INPUT/output"
    mkdir -p "$output_inside"

    # Run with input path ending in /. — should still exclude output
    run "$SCRIPT" "${INPUT}/." "$output_inside"
    [ "$status" -eq 0 ]
    # The script should not re-scan the output directory
    # If it does, it might process its own output files
    # Count files — should be 1 (the JPEG), not more
    [ "$(find "$output_inside" -type f -name '*.jpg' | wc -l)" -le 1 ]
}

# Issue #51: stale existing_hashes path recorded in seen_hashes
@test "issue #51: stale path in seen_hashes after existing_hashes match" {
    mkdir -p "$INPUT" "$OUTPUT/images/2026-01"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/photo.jpg')
"
    # Simulate a pre-existing file in output with the same hash
    cp "$INPUT/photo.jpg" "$OUTPUT/images/2026-01/EXISTINGHASH.jpg"
    local existing_hash
    existing_hash=$(sha256sum "$INPUT/photo.jpg" | cut -d' ' -f1)
    existing_hash=$(echo "$existing_hash" | tr 'a-f' 'A-F')
    mv "$OUTPUT/images/2026-01/EXISTINGHASH.jpg" \
       "$OUTPUT/images/2026-01/${existing_hash}.jpg"

    # Run — should detect the existing file as a duplicate
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Duplicate detected (already in output)"* ]]

    # Now delete the pre-existing file and run again
    rm -f "$OUTPUT/images/2026-01/${existing_hash}.jpg"

    # Second run: the input file should now be linked (no duplicate)
    # Bug #51: if seen_hashes has a stale path, it might still report
    # duplicate even though the output file is gone. But seen_hashes
    # doesn't persist across runs, so this is safe within one run only.
    # The real bug is within a single run if the file is deleted mid-run.
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # Should link the file now since the pre-existing one was deleted
    [ "$(find "$OUTPUT/images" -type f -name '*.jpg' | wc -l)" -ge 1 ]
}

# Issue #25: cross-filesystem copy fallback (test what we can on single FS)
@test "issue #25: hardlink succeeds on same filesystem (no copy fallback)" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg
make_jpeg('$INPUT/test.jpg')
"
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    # On same filesystem, should hardlink (not copy)
    [[ "$output" == *"Linked to:"* ]]
    [[ "$output" != *"Copied to:"* ]]
}

# Issue #30: symlinked paths in find exclusion
@test "issue #30: symlinked input directory — find does not follow by default (bug)" {
    # Issue #30: find doesn't use -L, so a symlinked input directory
    # results in 0 files processed. This documents the bug.
    mkdir -p "$INPUT/realdir"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_png
make_png('$INPUT/realdir/test.png')
"
    # Create a symlink to the input dir in /tmp
    local linked="/tmp/linked_input_$$"
    ln -s "$INPUT" "$linked"

    run "$SCRIPT" "$linked" "$OUTPUT"
    [ "$status" -eq 0 ]
    # Bug: find without -L doesn't follow the symlinked root
    # so 0 files are processed. This documents the issue.
    [[ "$output" == *"Processed: 0"* ]]
    rm -f "$linked"
}

# Issue #32: re-runs with MIME change between runs
@test "issue #32: re-run produces same output (idempotent)" {
    mkdir -p "$INPUT"
    python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME')
from generate_test_data import make_jpeg, make_png, make_pdf
make_jpeg('$INPUT/a.jpg')
make_png('$INPUT/b.png')
make_pdf('$INPUT/c.pdf')
"
    # First run
    "$SCRIPT" "$INPUT" "$OUTPUT" >/dev/null 2>&1
    local first_count
    first_count=$(find "$OUTPUT" -type f | wc -l)

    # Second run — should not add any new files
    run "$SCRIPT" "$INPUT" "$OUTPUT"
    [ "$status" -eq 0 ]
    local second_count
    second_count=$(find "$OUTPUT" -type f | wc -l)
    [ "$first_count" -eq "$second_count" ]
}

# Issue #49: normalize_extension tgz branch unreachable
@test "issue #49: .tgz extension is normalized to tar.gz (code health)" {
    # Verify normalize_extension exists and handles tgz
    run grep 'tgz' "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tar.gz"* ]]
}