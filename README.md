# File Organizer & Deduplicator

A robust bash script to extract archives, deduplicate files, and organize them by date and category.

## Features

- ✅ **Persistent Deduplication** - SHA256 hash-based, works across multiple runs
- ✅ **Archive Extraction** - Supports ZIP, RAR, 7Z, TAR.GZ, TAR.BZ2, TAR.XZ, and more
- ✅ **Smart Categorization** - Automatically sorts files into categories (images, videos, documents, etc.)
- ✅ **Date-Based Organization** - Organizes files into YYYY-MM directories using EXIF or file metadata
- ✅ **Safe by Default** - Copies files instead of moving (configurable)
- ✅ **Comprehensive Logging** - Detailed logs and statistics
- ✅ **Production Ready** - Extensive error handling and validation

## Quick Start

```bash
# Basic usage (copy files from current directory to ./export)
./organize_and_dedup.sh

# Specify input and output directories
./organize_and_dedup.sh /path/to/messy/files /path/to/organized/output

# Move files instead of copying (destructive!)
ACTION=mv ./organize_and_dedup.sh /path/to/input /path/to/output
```

## Installation

### Prerequisites

**Required tools:**
- `unzip` - For ZIP archives
- `tar` - For TAR archives
- `sha256sum` - For file hashing
- `exiftool` - For EXIF metadata extraction
- `file` - For file type detection

**Optional tools** (for additional archive formats):
- `unrar` - For RAR archives
- `7z` - For 7Z archives
- `gunzip`, `bunzip2`, `unxz` - For individual compressed files

### Install on Debian/Ubuntu

```bash
# Required tools
sudo apt-get install unzip tar coreutils libimage-exiftool-perl file

# Optional tools
sudo apt-get install unrar p7zip-full gzip bzip2 xz-utils
```

### Install on macOS

```bash
# Using Homebrew
brew install exiftool

# Optional tools
brew install unrar p7zip
```

## Usage

### Basic Examples

```bash
# Organize current directory
./organize_and_dedup.sh

# Organize specific directory
./organize_and_dedup.sh ~/Downloads ~/Organized

# Move files instead of copy
ACTION=mv ./organize_and_dedup.sh ~/Downloads ~/Organized

# Require all tools to be installed
STRICT_TOOLS=true ./organize_and_dedup.sh
```

### Configuration Options

#### Environment Variables

- **`ACTION`** - Set to `cp` (default) or `mv`
  - `cp` - Copy files (safe, preserves originals)
  - `mv` - Move files (destructive, deletes originals)

- **`STRICT_TOOLS`** - Set to `true` or `false` (default)
  - `true` - Exit if any tool is missing
  - `false` - Warn about missing optional tools, continue anyway

#### Examples

```bash
# Safe mode (copy files)
./organize_and_dedup.sh

# Destructive mode (move files)
ACTION=mv ./organize_and_dedup.sh

# Strict tool checking
STRICT_TOOLS=true ./organize_and_dedup.sh

# Combine options
ACTION=mv STRICT_TOOLS=true ./organize_and_dedup.sh /input /output
```

## How It Works

### Processing Phases

1. **Phase 1: Extract Archives**
   - Finds all archive files in input directory
   - Extracts to temporary directory
   - Validates archives before extraction

2. **Phase 2: Organize Archive Files**
   - Processes the archive files themselves
   - Moves/copies to `archives/YYYY-MM/` directory
   - Deduplicates based on hash

3. **Phase 3: Organize All Other Files**
   - Processes non-archive files from input directory
   - Processes extracted files from temporary directory
   - Deduplicates based on hash
   - Organizes by category and date

### Deduplication

Files are deduplicated using SHA256 hashing:

1. Calculate SHA256 hash of file content
2. Check if hash exists in registry (`.hash_registry.txt`)
3. If duplicate → skip file
4. If unique → add hash to registry and process file

The hash registry persists across runs, so duplicates are detected even when running the script multiple times.

### File Naming

Files are renamed using this pattern:

```
<datetime>_<hash>.<extension>

Examples:
2023-10-20_14-00-00_A1B2C3D4E5F6789...jpg
2024-12-02_09-30-15_F6E5D4C3B2A1098...pdf
```

**Components:**
- `datetime` - From EXIF metadata or file modification time
- `hash` - SHA256 hash (uppercase, truncated in display)
- `extension` - Normalized file extension

### Directory Structure

```
output_dir/
├── images/
│   ├── 2023-10/
│   ├── 2023-11/
│   └── 2024-12/
├── videos/
│   └── 2024-12/
├── documents/
│   └── 2024-12/
├── archives/
│   └── 2024-12/
├── audios/
├── scripts/
├── configs/
├── certificates/
├── fonts/
├── databases/
├── applications/
├── backups/
├── others/
├── .hash_registry.txt  # Hidden file tracking all hashes
└── processing.log      # Detailed log of all operations
```

## Categories

Files are automatically categorized based on their extension:

| Category | Extensions |
|----------|-----------|
| **Images** | jpg, png, tiff, bmp, gif, heic, webp, svg, raw, etc. |
| **Videos** | mp4, mkv, webm, avi, mov, wmv, flv, mpeg, etc. |
| **Audios** | mp3, wav, flac, aac, ogg, m4a, wma, etc. |
| **Documents** | pdf, doc, docx, txt, md, xls, xlsx, ppt, pptx, csv, etc. |
| **Archives** | zip, rar, 7z, tar, gz, bz2, xz, iso, jar, apk, etc. |
| **Scripts** | sh, bash, py, pl, rb, java, c, cpp, php, js, ts, etc. |
| **Configs** | ini, conf, cfg, json, yaml, yml, xml, plist, etc. |
| **Certificates** | pem, crt, cer, der, pfx, p12, key, etc. |
| **Fonts** | ttf, otf, woff, woff2, eot, etc. |
| **Databases** | db, sqlite, accdb, mdb, etc. |
| **Applications** | exe, dll, bin, com, app, msi, etc. |
| **Backups** | bak, tmp, old, backup, orig, etc. |
| **Others** | Everything else |

## Output

### Console Output

```
======================================
Starting file organization process
Date: Mon Dec  2 06:00:00 UTC 2024
======================================

Scanning input directory...
Found 1,234 files in input directory

======================================
PHASE 1: Extracting archives
======================================
Extracting ZIP: archive.zip
...

======================================
PHASE 2: Organizing archive files
======================================
Processing: archive.zip
Copied: archive.zip -> archives/2024-12/2024-12-02_14-30-00_ABC123...zip
...

======================================
PHASE 3: Organizing all other files
======================================
Processing: photo.jpg
Copied: photo.jpg -> images/2024-12/2024-12-02_15-00-00_DEF456...jpg
Duplicate skipped: photo_copy.jpg (hash: DEF456...)
...

======================================
Processing complete!
======================================

Output directory: /path/to/output
Log file: /path/to/output/processing.log
Hash registry: /path/to/output/.hash_registry.txt

Summary:
--------
Files in input directory: 1,234
New unique files this run: 987
Files successfully processed: 987
Duplicates skipped this run: 247
Total unique hashes in registry (all runs): 2,345

Files by category:
  images: 456 files
  videos: 123 files
  documents: 234 files
  archives: 89 files
  audios: 45 files
  scripts: 23 files
  others: 17 files

Done!
```

### Log File

All operations are logged to `processing.log` in the output directory with detailed information about:
- Files processed
- Duplicates skipped
- Errors encountered
- Extraction operations
- Hash calculations

## Advanced Usage

### Resuming Interrupted Operations

The script is designed to be resumable:

```bash
# Run the script
./organize_and_dedup.sh /input /output

# If interrupted (Ctrl+C), just run again
./organize_and_dedup.sh /input /output

# The hash registry persists, so:
# - Already processed files are skipped (duplicates)
# - Only new/unprocessed files are handled
```

### Processing Multiple Directories

```bash
# Process multiple input directories to same output
./organize_and_dedup.sh /input1 /output
./organize_and_dedup.sh /input2 /output
./organize_and_dedup.sh /input3 /output

# Duplicates across all directories are detected
```

### Inspecting the Hash Registry

```bash
# View all unique file hashes
cat /path/to/output/.hash_registry.txt

# Count unique files
wc -l /path/to/output/.hash_registry.txt

# Search for specific hash
grep "ABC123..." /path/to/output/.hash_registry.txt
```

## Performance

### Speed

- **Photos/Documents**: Excellent performance
- **Large Videos**: SHA256 hashing is CPU-intensive for multi-GB files

### Optimization for Large Video Collections

If processing many large video files is too slow, you can modify the script to use a faster hash:

```bash
# Edit the script and change sha256sum to md5sum
# Line ~425 in process_file function:
hash=$(md5sum "$file" 2>> "$log_file")  # Instead of sha256sum
```

**Trade-offs:**
- `md5sum` - Faster, slightly higher collision risk
- `sha256sum` - Slower, extremely low collision risk (recommended)

## Troubleshooting

### "Error: Required tools missing"

Install the missing tools:

```bash
# Debian/Ubuntu
sudo apt-get install unzip tar coreutils libimage-exiftool-perl file

# macOS
brew install exiftool
```

### "Cannot extract [archive type]"

Install the optional tool for that archive type:

```bash
# For RAR files
sudo apt-get install unrar

# For 7Z files
sudo apt-get install p7zip-full
```

### "Permission denied" errors

Ensure you have read access to input directory and write access to output directory:

```bash
# Check permissions
ls -la /path/to/input
ls -la /path/to/output

# Fix permissions if needed
chmod -R u+r /path/to/input
chmod -R u+w /path/to/output
```

### Script crashes with "set -e" error

Check the log file for details:

```bash
tail -n 50 /path/to/output/processing.log
```

## Safety Features

- ✅ **Copy by default** - Original files are preserved
- ✅ **Collision detection** - Won't overwrite existing files
- ✅ **Atomic operations** - Hash added before copy/move
- ✅ **Comprehensive logging** - All operations are logged
- ✅ **Error handling** - Graceful handling of permission errors
- ✅ **Cleanup on exit** - Temporary files are always removed

## Technical Details

### Hash Registry

- **Location**: `<output_dir>/.hash_registry.txt`
- **Format**: One SHA256 hash per line (uppercase)
- **Persistence**: Survives across multiple runs
- **Purpose**: Enables deduplication across runs and directories

### Temporary Files

- **Location**: `<original_pwd>/tmp_organize/`
- **Purpose**: Extraction of archives
- **Cleanup**: Automatically removed on script exit

### Error Handling

- `set -euo pipefail` - Strict error handling
- Graceful handling of `find` permission errors
- Validation of all archive files before extraction
- Comprehensive error logging

## Development

### Code Review History

This script has been through extensive code review:
- Initial implementation
- First review: Fixed critical deduplication bugs
- Second review: Fixed category overlaps and safety issues
- Third review: Added robust date parsing and flexible tool checking
- Fourth review: Fixed hash matching, path checking, and statistics
- Fifth review: Final polish and expert approval

### Testing

Recommended test scenarios:
1. Basic deduplication
2. Archive extraction
3. Category assignment
4. Copy vs move modes
5. Output directory pruning
6. Hash exact matching
7. Working directory management
8. Statistics accuracy
9. Error handling

## License

MIT License - Feel free to use, modify, and distribute.

## Contributing

Contributions are welcome! Please:
1. Test your changes thoroughly
2. Update documentation
3. Follow existing code style
4. Add comments for complex logic

## Credits

Developed with assistance from multiple AI code reviewers to ensure production-ready quality.

## Support

For issues, questions, or suggestions, please open an issue on GitHub.
