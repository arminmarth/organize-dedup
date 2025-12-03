# Extension Correction Examples

Demonstrations of extension detection and correction features.

## Example 1: Report Mode - Audit Files

```bash
#!/bin/bash
# Create files with wrong extensions
mkdir -p messy_files
echo "This is text" > messy_files/document.jpg
echo "More text" > messy_files/readme.png
echo "Correct file" > messy_files/notes.txt

# Generate report without processing
../../organize_and_dedup.sh --report-extensions -i messy_files -o report_output

# View the report
cat report_output/extension_mismatches.csv
```

**Output:**
```csv
original_path,current_ext,detected_ext,mime_type,hash,action
/path/document.jpg,jpg,txt,text/plain,abc123...,detected
/path/readme.png,png,txt,text/plain,def456...,detected
```

## Example 2: Fix Mode - Automatically Correct Extensions

```bash
#!/bin/bash
# Create files with wrong extensions
mkdir -p wrong_extensions
echo "Text content" > wrong_extensions/file1.jpg
echo "More text" > wrong_extensions/file2.png

# Fix extensions automatically
../../organize_and_dedup.sh --fix-extensions -i wrong_extensions -o fixed_extensions

# Check results
find fixed_extensions -name "*.txt"
# All files now have .txt extension
```

## Example 3: Strict Mode - Only Process Correct Files

```bash
#!/bin/bash
# Create mixed files
mkdir -p mixed
echo "Wrong extension" > mixed/doc.jpg  # Will be skipped
echo "Correct file" > mixed/doc.txt     # Will be processed

# Process only files with correct extensions
../../organize_and_dedup.sh --strict-extensions -i mixed -o strict_output

# Check results
find strict_output -type f ! -name ".*" ! -name "*.csv" ! -name "*.log"
# Only doc.txt is present
```

## Example 4: Only Mismatched - Process Only Wrong Extensions

```bash
#!/bin/bash
# Create mixed files
mkdir -p mixed
echo "Wrong extension" > mixed/doc.jpg  # Will be processed
echo "Correct file" > mixed/doc.txt     # Will be skipped

# Process only files with wrong extensions
../../organize_and_dedup.sh --only-mismatched-extensions --fix-extensions \
  -i mixed -o mismatched_output

# Check results
find mismatched_output -type f ! -name ".*" ! -name "*.csv" ! -name "*.log"
# Only doc.jpg (now corrected to .txt) is present
```

## Example 5: Workflow - Audit, Review, Fix

```bash
#!/bin/bash
# Step 1: Audit files
../../organize_and_dedup.sh --report-extensions -i input -o audit

# Step 2: Review the report
cat audit/extension_mismatches.csv

# Step 3: Fix extensions
../../organize_and_dedup.sh --fix-extensions -i input -o output

# Step 4: Verify
cat output/extension_mismatches.csv
```

## Example 6: Separate Correct and Incorrect Files

```bash
#!/bin/bash
# Create test files
mkdir -p files
echo "Wrong 1" > files/doc1.jpg  # Text file with .jpg
echo "Wrong 2" > files/doc2.png  # Text file with .png
echo "Correct 1" > files/doc3.txt  # Correct
echo "Correct 2" > files/doc4.txt  # Correct

# Extract files with wrong extensions (and fix them)
../../organize_and_dedup.sh --action hardlink --only-mismatched-extensions --fix-extensions \
  -i files -o wrong_fixed

# Extract files with correct extensions
../../organize_and_dedup.sh --action hardlink --strict-extensions \
  -i files -o already_correct

# Results:
# - files/ (original, untouched)
# - wrong_fixed/ (2 files, now with .txt extension)
# - already_correct/ (2 files, kept as .txt)
# - Zero additional disk space (hardlinks)
```

## Supported File Types

The extension correction feature supports 100+ file types:

- **Documents:** PDF, Word (.docx), Excel (.xlsx), PowerPoint (.pptx), ODT, RTF
- **Archives:** ZIP, RAR, 7Z, TAR, GZIP, BZIP2
- **Images:** JPEG, PNG, GIF, BMP, TIFF, WebP, SVG, ICO
- **Video:** MP4, MKV, AVI, MOV, WebM, FLV
- **Audio:** MP3, FLAC, WAV, OGG, AAC, M4A
- **Code:** Python, JavaScript, Java, C/C++, Shell, Ruby, Go
- **Config:** JSON, XML, YAML, INI, TOML
- **And many more...**

## CSV Report Format

```csv
original_path,current_ext,detected_ext,mime_type,hash,action
/path/file.jpg,jpg,pdf,application/pdf,ABC123...,corrected
```

Fields:
- `original_path` - Full path to the file
- `current_ext` - Extension from filename
- `detected_ext` - Correct extension based on content
- `mime_type` - Detected MIME type
- `hash` - File hash for tracking
- `action` - "corrected" or "detected"

## Verification

```bash
# Check MIME type manually
file --mime-type filename

# Check with exiftool
exiftool -FileType filename

# Compare extensions
echo "Filename: $(basename filename)"
echo "MIME type: $(file -b --mime-type filename)"
```
