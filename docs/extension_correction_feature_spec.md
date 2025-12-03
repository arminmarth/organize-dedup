# Extension Correction Feature Specification

## 📋 Overview

Add capability to detect and correct file extension mismatches by analyzing file content using the `file` command, and handle duplicate files with different extensions.

## 🎯 Use Cases

### 1. Wrong Extension
```
misnamedfile.zip  (actually a DOCX file)
→ Detect: content is application/vnd.openxmlformats-officedocument.wordprocessingml.document
→ Correct: rename to misnamedfile.docx
```

### 2. Missing Extension
```
misnamedfile  (no extension, but is a DOCX file)
→ Detect: content is application/vnd.openxmlformats-officedocument.wordprocessingml.document
→ Correct: rename to misnamedfile.docx
```

### 3. Duplicate Files with Different Extensions
```
document.zip  (hash: abc123, actually DOCX)
document.docx (hash: abc123, actually DOCX)
→ Detect: same content, different names
→ Action: keep correct extension, mark other as duplicate
```

## 🔧 Technical Approach

### Detection Method

Use the `file` command which reads file magic bytes:

```bash
file -b --mime-type filename
# Returns: application/vnd.openxmlformats-officedocument.wordprocessingml.document
```

### MIME Type to Extension Mapping

Create a comprehensive mapping table:

```bash
declare -A mime_to_ext=(
    # Documents
    ["application/vnd.openxmlformats-officedocument.wordprocessingml.document"]="docx"
    ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]="xlsx"
    ["application/vnd.openxmlformats-officedocument.presentationml.presentation"]="pptx"
    ["application/msword"]="doc"
    ["application/vnd.ms-excel"]="xls"
    ["application/vnd.ms-powerpoint"]="ppt"
    ["application/pdf"]="pdf"
    ["application/rtf"]="rtf"
    
    # Archives
    ["application/zip"]="zip"
    ["application/x-rar"]="rar"
    ["application/x-7z-compressed"]="7z"
    ["application/x-tar"]="tar"
    ["application/gzip"]="gz"
    ["application/x-bzip2"]="bz2"
    
    # Images
    ["image/jpeg"]="jpg"
    ["image/png"]="png"
    ["image/gif"]="gif"
    ["image/webp"]="webp"
    ["image/svg+xml"]="svg"
    ["image/bmp"]="bmp"
    ["image/tiff"]="tiff"
    
    # Video
    ["video/mp4"]="mp4"
    ["video/x-matroska"]="mkv"
    ["video/quicktime"]="mov"
    ["video/x-msvideo"]="avi"
    ["video/webm"]="webm"
    
    # Audio
    ["audio/mpeg"]="mp3"
    ["audio/mp4"]="m4a"
    ["audio/x-wav"]="wav"
    ["audio/flac"]="flac"
    ["audio/ogg"]="ogg"
    
    # Text
    ["text/plain"]="txt"
    ["text/html"]="html"
    ["text/css"]="css"
    ["text/javascript"]="js"
    ["application/json"]="json"
    ["application/xml"]="xml"
    ["text/csv"]="csv"
    
    # Code
    ["text/x-python"]="py"
    ["text/x-shellscript"]="sh"
    ["text/x-c"]="c"
    ["text/x-c++"]="cpp"
    ["text/x-java"]="java"
)
```

## 🎨 Feature Design

### Option 1: Fix Extensions Mode (Recommended)

Add `--fix-extensions` flag:

```bash
./organize_and_dedup.sh --fix-extensions -i /photos -o /organized
```

**Behavior:**
1. For each file, detect actual content type using `file` command
2. Compare detected extension with current extension
3. If mismatch:
   - Log the mismatch
   - Use correct extension in output filename
   - Add to mismatch report

**Output naming:**
```
# Original: misnamedfile.zip (actually DOCX)
# Hash: abc123def456...
# Detected: application/vnd.openxmlformats-officedocument.wordprocessingml.document

# With --fix-extensions:
output/documents/abc123def456.docx  # Correct extension

# Without --fix-extensions:
output/archives/abc123def456.zip    # Wrong category and extension
```

### Option 2: Strict Mode

Add `--strict-extensions` flag:

```bash
./organize_and_dedup.sh --strict-extensions -i /photos -o /organized
```

**Behavior:**
- Only process files where extension matches content
- Skip or warn about mismatched files
- Useful for validation

### Option 3: Report Only Mode

Add `--report-extensions` flag:

```bash
./organize_and_dedup.sh --report-extensions -i /photos -o /organized
```

**Behavior:**
- Generate report of extension mismatches
- Don't fix automatically
- Let user decide what to do

## 📊 Handling Duplicates with Different Extensions

### Scenario

```
Input directory:
- document.zip  (hash: abc123, content: DOCX)
- document.docx (hash: abc123, content: DOCX)
- report.doc    (hash: abc123, content: DOCX)
```

### Strategy 1: Prefer Correct Extension

```bash
# With --fix-extensions and --deduplicate yes

# First file processed: document.zip
# - Detect: actually DOCX
# - Fix: save as abc123.docx
# - Add hash to registry

# Second file: document.docx
# - Hash already exists
# - Extension is correct
# - Mark as duplicate, skip

# Third file: report.doc
# - Hash already exists
# - Extension is wrong (should be docx)
# - Mark as duplicate, skip
```

**Result:** One file with correct extension

### Strategy 2: Keep Original Names

Add `--keep-original-names` flag:

```bash
# With --fix-extensions and --keep-original-names

# Output:
document.docx  (from document.zip, extension corrected)
document-1.docx (from document.docx, duplicate detected)
report.docx    (from report.doc, extension corrected, duplicate detected)
```

**Result:** All files kept with corrected extensions and conflict resolution

### Strategy 3: Create Extension Mismatch Report

Generate `extension_mismatches.csv`:

```csv
original_path,original_ext,detected_mime,correct_ext,hash,action
/input/document.zip,zip,application/vnd.openxml...,docx,abc123,corrected
/input/misnamed,none,image/jpeg,jpg,def456,added_extension
/input/photo.png,png,image/png,png,ghi789,correct
```

## 🔍 Implementation Details

### New Function: `detect_correct_extension()`

```bash
detect_correct_extension() {
    local file="$1"
    local current_ext="${file##*.}"
    
    # Get MIME type
    local mime_type
    mime_type=$(file -b --mime-type "$file" 2>/dev/null)
    
    if [[ -z "$mime_type" ]]; then
        echo "$current_ext"  # Fallback to current
        return
    fi
    
    # Look up correct extension
    local correct_ext="${mime_to_ext[$mime_type]}"
    
    if [[ -n "$correct_ext" ]]; then
        echo "$correct_ext"
    else
        echo "$current_ext"  # Fallback to current
    fi
}
```

### Modified `process_file()` Function

```bash
process_file() {
    local file="$1"
    local ext="${file##*.}"
    
    # NEW: Detect correct extension if --fix-extensions enabled
    if [[ "$FIX_EXTENSIONS" == "yes" ]]; then
        local detected_ext
        detected_ext=$(detect_correct_extension "$file")
        
        if [[ "$detected_ext" != "$ext" ]]; then
            # Log mismatch
            echo "Extension mismatch: $file" | tee -a "$log_file"
            echo "  Current: .$ext, Detected: .$detected_ext" | tee -a "$log_file"
            
            # Use detected extension
            ext="$detected_ext"
            
            # Add to mismatch report
            echo "$file,$ext,$detected_ext,$(calculate_hash "$file")" >> "$mismatch_report"
        fi
    fi
    
    # Continue with normal processing using corrected extension
    # ...
}
```

### New CLI Options

```bash
--fix-extensions          Detect and correct file extensions based on content
--strict-extensions       Only process files with correct extensions
--report-extensions       Generate extension mismatch report only
--keep-original-names     Keep original filenames when fixing extensions
```

## 📝 Output Files

### 1. Extension Mismatch Report

`extension_mismatches.csv`:
```csv
original_path,current_ext,detected_ext,mime_type,hash,action_taken
/input/doc.zip,zip,docx,application/vnd.openxml...,abc123,corrected
/input/file,none,jpg,image/jpeg,def456,added
/input/photo.png,png,png,image/png,ghi789,no_change
```

### 2. Enhanced Processing Log

```
Processing: /input/document.zip
  Extension mismatch detected!
  Current: .zip
  Detected: .docx (application/vnd.openxmlformats-officedocument.wordprocessingml.document)
  Action: Using correct extension .docx
  Output: /output/documents/abc123def456.docx
```

### 3. Summary Statistics

```
Extension Correction Summary:
  Files processed: 150
  Extension mismatches found: 23
  Extensions corrected: 23
  Files with missing extensions: 5
  Extensions added: 5
  
Mismatch breakdown:
  .zip → .docx: 12 files
  .zip → .xlsx: 5 files
  (no ext) → .jpg: 3 files
  .txt → .json: 2 files
  .dat → .pdf: 1 file
```

## 🧪 Testing Scenarios

### Test 1: DOCX Named as ZIP

```bash
# Create test file
cp document.docx misnamed.zip

# Run with fix
./organize_and_dedup.sh --fix-extensions -i . -o ./output

# Expected: output/documents/[hash].docx
```

### Test 2: File Without Extension

```bash
# Create test file
cp photo.jpg photofile

# Run with fix
./organize_and_dedup.sh --fix-extensions -i . -o ./output

# Expected: output/images/[hash].jpg
```

### Test 3: Duplicate with Different Extensions

```bash
# Create duplicates
cp document.docx file1.zip
cp document.docx file2.doc
cp document.docx file3.docx

# Run with fix and dedup
./organize_and_dedup.sh --fix-extensions --deduplicate yes -i . -o ./output

# Expected: Only one file in output with .docx extension
```

## 🎯 Benefits

1. **Automatic Correction** - No manual renaming needed
2. **Proper Categorization** - Files go to correct category based on actual content
3. **Deduplication Accuracy** - Duplicates detected even with wrong extensions
4. **Data Integrity** - Content-based detection is more reliable than filename
5. **Audit Trail** - Complete report of all corrections made

## ⚠️ Limitations

1. **MIME Detection Accuracy** - `file` command may not detect all formats perfectly
2. **Ambiguous Types** - Some MIME types map to multiple extensions (e.g., JPEG → jpg/jpeg)
3. **Performance** - Running `file` on every file adds overhead
4. **False Positives** - Text files might be misdetected (e.g., JSON as plain text)

## 🔄 Compatibility

- **Backward Compatible** - Feature is opt-in via flag
- **No Breaking Changes** - Default behavior unchanged
- **Works with Existing Features** - Compatible with all current modes and options

## 📅 Implementation Plan

### Phase 1: Basic Detection (v2.1.0)
- Add `detect_correct_extension()` function
- Add `--fix-extensions` flag
- Generate mismatch report
- Update categorization to use detected extension

### Phase 2: Advanced Handling (v2.2.0)
- Add `--strict-extensions` mode
- Add `--keep-original-names` option
- Improve duplicate handling with different extensions
- Add interactive mode for corrections

### Phase 3: Enhanced Detection (v3.0.0)
- Add custom MIME type mappings
- Support for rare/custom file types
- Machine learning-based detection
- Integration with external file identification tools

## 📊 Priority

**High** - This solves a real user problem and adds significant value to the tool.

**Proposed for:** v2.1.0 (Feature Enhancements release)
