# organize-dedup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.2.0-blue)](https://github.com/arminmarth/organize-dedup/releases)

A comprehensive file organization and deduplication tool with multiple modes, hash algorithms, and flexible organization methods.

## Features

### Core Capabilities
- **🔄 Persistent Deduplication** - Skip duplicate files across multiple runs using hash registry
- **📦 Archive Extraction** - Automatically extract ZIP, RAR, 7Z, TAR.* archives
- **📅 Date-Based Organization** - Organize files by date using EXIF metadata
- **📂 Smart Categorization** - 13 categories (images, videos, documents, etc.)
- **🔐 Multiple Hash Algorithms** - SHA1, SHA256, SHA512, MD5
- **✨ Extension Correction** - Detect and fix wrong file extensions using MIME type detection (NEW in v2.1.0)
- **🔗 Link Support** - Hardlink and softlink options for zero-copy organization (NEW in v2.2.0)
- **🐳 Docker Support** - Containerized deployment with Makefile
- **⚙️ Flexible Configuration** - Multiple modes, naming formats, organization methods

### Two Modes

**Simple Mode** - Fast checksum-based renaming
- Rename files to their checksums
- Organize by file extension
- No date prefixes
- No archive extraction
- Perfect for quick organization

**Advanced Mode** - Full-featured organization
- Persistent deduplication
- Archive extraction and processing
- Date-based organization with EXIF metadata
- Smart categorization (13 categories)
- Comprehensive logging

## Installation

### Prerequisites

**Debian/Ubuntu:**
```bash
sudo apt-get install coreutils libimage-exiftool-perl file tar gzip bzip2 xz-utils unzip p7zip-full
```

**macOS:**
```bash
brew install coreutils exiftool p7zip
```

### Quick Start

```bash
# Clone the repository
git clone https://github.com/arminmarth/organize-dedup.git
cd organize-dedup

# Make executable
chmod +x organize_and_dedup.sh

# Run
./organize_and_dedup.sh --help
```

## Usage

### Basic Examples

```bash
# Simple mode - fast checksum renaming
./organize_and_dedup.sh --mode simple -i /photos -o /renamed

# Advanced mode - full organization
./organize_and_dedup.sh --mode advanced -i /photos -o /organized

# Legacy format (still supported)
./organize_and_dedup.sh /input /output
```

### Advanced Examples

```bash
# Use MD5 for speed on large video files
./organize_and_dedup.sh --hash-algorithm md5 -i /videos -o /organized

# Organize by extension only, no date prefixes
./organize_and_dedup.sh --organize-by extension --naming-format hash_ext -i /files -o /output

# Disable archive extraction
./organize_and_dedup.sh --extract-archives no -i /files -o /output

# Move files instead of copy
./organize_and_dedup.sh --action mv -i /input -o /output

# Hardlink files (zero disk space, same filesystem required) (NEW in v2.2.0)
./organize_and_dedup.sh --action hardlink -i /photos -o /organized

# Softlink files (works across filesystems) (NEW in v2.2.0)
./organize_and_dedup.sh --action softlink -i /external/files -o /organized

# Verbose output
./organize_and_dedup.sh -v -i /input -o /output

# Fix wrong file extensions automatically (NEW in v2.1.0)
./organize_and_dedup.sh --fix-extensions -i /input -o /output

# Generate report of extension mismatches without processing
./organize_and_dedup.sh --report-extensions -i /input -o /output

# Skip files with wrong extensions (strict mode)
./organize_and_dedup.sh --strict-extensions -i /input -o /output

# Only process files with wrong extensions (NEW in v2.2.0)
./organize_and_dedup.sh --only-mismatched-extensions --fix-extensions -i /input -o /output
```

## Configuration Options

### Core Options
| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `--mode` | `simple`, `advanced` | `advanced` | Operational mode |
| `-i, --input-dir` | path | `.` (current dir) | Input directory |
| `-o, --output-dir` | path | `./export` | Output directory |
| `-a, --action` | `cp`, `mv` | `cp` | Copy or move files |

### Hash Options
| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `--hash-algorithm` | `sha1`, `sha256`, `sha512`, `md5` | `sha256` | Hash algorithm |

### Naming Options
| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `--naming-format` | `hash`, `hash_ext`, `date_hash_ext` | `date_hash_ext` | File naming format |

**Naming Format Examples:**
- `hash` → `ABC123...`
- `hash_ext` → `ABC123....jpg`
- `date_hash_ext` → `2024-12-02_14-30-00_ABC123....jpg`

### Organization Options
| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `--organize-by` | `none`, `extension`, `category`, `date`, `category_date` | `category_date` | Organization method |

**Organization Examples:**
- `none` → Flat directory
- `extension` → `jpg/`, `png/`, `mp4/`
- `category` → `images/`, `videos/`, `documents/`
- `date` → `2024-12/`, `2024-11/`
- `category_date` → `images/2024-12/`, `videos/2024-11/`

### Processing Options
| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `--extract-archives` | `yes`, `no` | `yes` (advanced), `no` (simple) | Extract archives |
| `--recursive` | `yes`, `no` | `yes` (advanced), `no` (simple) | Process subdirectories |
| `--deduplicate` | `yes`, `no` | `yes` | Enable deduplication |

### Extension Correction Options (NEW in v2.1.0)
| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `--fix-extensions` | `yes`, `no` | `no` | Detect and correct file extensions based on MIME type |
| `--strict-extensions` | `yes`, `no` | `no` | Skip files with incorrect extensions |
| `--report-extensions` | `yes`, `no` | `no` | Generate extension mismatch report only (no processing) |

### Output Options
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Verbose output |
| `-q, --quiet` | Minimal output |
| `-h, --help` | Show help message |
| `--version` | Show version |

## Docker Usage

### Build Image

```bash
# Using Makefile
make build

# Or manually
docker build -t organize-dedup:latest .
```

### Run with Docker

```bash
# Simple mode
make simple INPUT=/path/to/files OUTPUT=/path/to/output

# Advanced mode
make advanced INPUT=/path/to/files OUTPUT=/path/to/output

# Custom options
make run INPUT=/path/to/files OUTPUT=/path/to/output OPTS='--mode simple --hash-algorithm md5'

# Or manually
docker run --rm \
  -v /path/to/files:/input \
  -v /path/to/output:/output \
  organize-dedup:latest \
  --mode simple -i /input -o /output
```

## How It Works

### Simple Mode Workflow

1. **Scan** input directory (non-recursive)
2. **Calculate** hash for each file
3. **Skip** duplicates (if deduplication enabled)
4. **Rename** to `<hash>.<ext>`
5. **Organize** by file extension

### Advanced Mode Workflow

1. **Extract** archives from input directory
2. **Organize** archive files themselves
3. **Process** all files (input + extracted)
4. **Calculate** hash for each file
5. **Skip** duplicates using persistent hash registry
6. **Extract** date from EXIF metadata
7. **Categorize** by file type (13 categories)
8. **Rename** to `<date>_<hash>.<ext>`
9. **Organize** into `<category>/<YYYY-MM>/` structure

## File Categories

The tool recognizes 13 file categories:

| Category | Extensions |
|----------|------------|
| **Images** | jpg, png, gif, bmp, tiff, heic, webp, svg, psd, raw, etc. |
| **Videos** | mp4, mkv, avi, mov, wmv, flv, webm, etc. |
| **Audios** | mp3, wav, flac, aac, ogg, m4a, wma, etc. |
| **Documents** | pdf, doc, docx, txt, md, xls, xlsx, ppt, pptx, etc. |
| **Scripts** | sh, py, js, java, c, cpp, php, etc. |
| **Archives** | zip, rar, 7z, tar, gz, iso, etc. |
| **Configs** | ini, conf, json, yaml, xml, etc. |
| **Certificates** | pem, crt, key, pfx, etc. |
| **Fonts** | ttf, otf, woff, woff2, etc. |
| **Databases** | db, sqlite, mdb, etc. |
| **Applications** | exe, dll, app, dmg, etc. |
| **Backups** | bak, tmp, old, backup, etc. |
| **Others** | Everything else |

## Mode Presets

**Note:** Mode presets are applied only when options are at their default values. Explicit command-line flags always take precedence.

### Simple Mode Sets:
- `--naming-format hash_ext`
- `--organize-by extension`
- `--extract-archives no`
- `--recursive no`

### Advanced Mode Sets:
- `--naming-format date_hash_ext`
- `--organize-by category_date`
- `--extract-archives yes`
- `--recursive yes`

## Deduplication

The tool uses a **persistent hash registry** to track unique files across multiple runs:

- Hash registry: `<output_dir>/.hash_registry_<algorithm>.txt`
- One hash per line
- Survives across runs
- Separate registry per hash algorithm

**Benefits:**
- Skip duplicates automatically
- Save disk space
- Consistent across runs
- Works with any hash algorithm

## Extension Correction (NEW in v2.1.0)

The tool can detect and correct file extensions based on actual file content using MIME type detection.

### How It Works

1. **Detection** - Uses `file --mime-type` to analyze file content
2. **Mapping** - Matches MIME type to correct extension (100+ file types supported)
3. **Action** - Corrects, reports, or skips based on selected mode

### Three Modes

**Fix Mode** (`--fix-extensions`)
- Automatically corrects wrong extensions
- Uses detected extension in output filename
- Generates CSV report of all corrections
- Example: `document.jpg` (actually PDF) → `...hash....pdf`

**Report Mode** (`--report-extensions`)
- Scans files and generates mismatch report
- Does not process or organize files
- Useful for auditing file collections
- Creates `extension_mismatches.csv` in output directory

**Strict Mode** (`--strict-extensions`)
- Skips files with incorrect extensions
- Only processes files with correct extensions
- Useful for quality control
- Generates report of skipped files

### Supported File Types

The extension correction feature supports 100+ file types including:

- **Documents:** PDF, Word, Excel, PowerPoint, ODT, RTF
- **Archives:** ZIP, RAR, 7Z, TAR, GZIP, BZIP2
- **Images:** JPEG, PNG, GIF, BMP, TIFF, WebP, SVG
- **Video:** MP4, MKV, AVI, MOV, WebM
- **Audio:** MP3, FLAC, WAV, OGG, AAC
- **Code:** Python, JavaScript, Java, C/C++, Shell scripts
- **Config:** JSON, XML, YAML, INI, TOML
- **And many more...**

### CSV Report Format

The `extension_mismatches.csv` report includes:

```csv
original_path,current_ext,detected_ext,mime_type,hash,action
/path/file.jpg,jpg,pdf,application/pdf,ABC123...,corrected
```

- `original_path` - Full path to the file
- `current_ext` - Extension from filename
- `detected_ext` - Correct extension based on content
- `mime_type` - Detected MIME type
- `hash` - File hash for tracking
- `action` - "corrected" or "detected"

### Use Cases

**Audit File Collection**
```bash
# Generate report without processing
./organize_and_dedup.sh --report-extensions -i /files -o /report
```

**Fix Misnamed Files**
```bash
# Automatically correct extensions
./organize_and_dedup.sh --fix-extensions -i /messy -o /clean
```

**Quality Control**
```bash
# Only process correctly-named files
./organize_and_dedup.sh --strict-extensions -i /input -o /output
```

## Link Types (NEW in v2.2.0)

The script supports four action types for handling files: **copy**, **move**, **hardlink**, and **softlink**.

### Quick Comparison

| Action | Disk Space | Original Preserved | Same Filesystem Required | Changes Propagate |
|--------|------------|-------------------|-------------------------|------------------|
| **cp** | 2x (doubles) | Yes | No | No |
| **mv** | 1x (no change) | No (moved) | No | N/A |
| **hardlink** | 1x (shared) | Yes | **Yes** | **Yes** |
| **softlink** | ~1x (pointer) | Yes | No | **Yes** |

### When to Use Each

**Copy (`--action cp`)** - Default, safest option
- ✅ Original files untouched
- ✅ Works across different filesystems
- ❌ Doubles disk space

**Move (`--action mv`)** - Permanent reorganization
- ✅ No additional disk space
- ✅ Cleans up source directory
- ❌ Original files removed

**Hardlink (`--action hardlink`)** - Zero-copy organization
- ✅ **Zero additional disk space** (same data, multiple names)
- ✅ Original files preserved in original location
- ✅ Fast operation
- ❌ **Must be on same filesystem** (same partition/drive)
- ⚠️ **Changes affect both locations** (shared inode)

**Softlink (`--action softlink`)** - Cross-filesystem pointers
- ✅ Works across different filesystems
- ✅ Minimal disk space (just pointer)
- ✅ Original files preserved
- ❌ **Broken if original deleted**
- ⚠️ **Changes affect both locations** (points to original)

### Example Use Cases

**Dual organization with zero disk space:**
```bash
# Keep originals + create organized structure, zero additional space
./organize_and_dedup.sh --action hardlink -i /photos -o /organized
# Now have both /photos (original) and /organized (by category/date)
```

**Separate correct and incorrect extensions:**
```bash
# Extract only files with wrong extensions (and fix them)
./organize_and_dedup.sh --action hardlink --only-mismatched-extensions --fix-extensions \
  -i /files -o /corrected

# Extract only files with correct extensions
./organize_and_dedup.sh --action hardlink --strict-extensions \
  -i /files -o /already_correct
```

**Cross-filesystem organization:**
```bash
# Link to files on external drive
./organize_and_dedup.sh --action softlink -i /external/photos -o /home/organized
```

### Important Warnings

⚠️ **Hardlink Checksum Warning:** If you modify a file in one location, it changes in BOTH locations (same inode). This changes the hash, which may cause deduplication issues.

⚠️ **Softlink Broken Link Warning:** If you delete the original file, softlinks become broken. Only use when originals are permanent.

⚠️ **Filesystem Limitation:** Hardlinks only work within the same filesystem. Check with `df /input /output`.

For detailed information, see [LINK_TYPES.md](LINK_TYPES.md).

## Performance

### Hash Algorithm Speed Comparison

| Algorithm | Speed | Security | Use Case |
|-----------|-------|----------|----------|
| **MD5** | Fastest | Low | Large video files, speed priority |
| **SHA1** | Fast | Medium | General use, legacy compatibility |
| **SHA256** | Medium | High | Recommended default |
| **SHA512** | Slow | Highest | Maximum security |

**Recommendation:** Use SHA256 for most cases, MD5 for large files when speed matters.

## Troubleshooting

### Common Issues

**Problem:** "Required tools missing"
```bash
# Install missing tools
sudo apt-get install coreutils libimage-exiftool-perl file tar unzip
```

**Problem:** "Permission denied"
```bash
# Make script executable
chmod +x organize_and_dedup.sh
```

**Problem:** "No files found"
```bash
# Check input directory exists and has files
ls -la /path/to/input

# Try verbose mode to see what's happening
./organize_and_dedup.sh -v -i /input -o /output
```

**Problem:** Docker "Permission denied"
```bash
# Run with sudo or add user to docker group
sudo make build
sudo make simple INPUT=/path OUTPUT=/path
```

## Migration from v1.0

v2.0 is **backward compatible** with v1.0:

```bash
# v1.0 usage (still works)
./organize_and_dedup.sh /input /output
ACTION=mv ./organize_and_dedup.sh /input /output

# v2.0 equivalent
./organize_and_dedup.sh -i /input -o /output
./organize_and_dedup.sh -i /input -o /output --action mv
```

**New in v2.0:**
- Multiple hash algorithms
- Simple mode
- Flexible naming formats
- Multiple organization methods
- Docker support
- Rich CLI with `--help`

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Armin Marth**
- GitHub: [@arminmarth](https://github.com/arminmarth)

## Acknowledgments

This project integrates the best features from:
- `organize_and_dedup` v1.0 - Advanced organization and deduplication
- `checksum-file-renamer` v1.1 - Simple checksum renaming with Docker support

Special thanks to ChatGPT, Gemini, and Claude for code reviews and recommendations.
