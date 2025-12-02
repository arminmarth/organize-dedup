# Changelog

All notable changes to this project are documented in this file.

## [1.0.0] - 2024-12-02

### Initial Release

This is the first production-ready release after extensive code review and testing.

### Features

- **Persistent Deduplication**: SHA256 hash-based deduplication that works across multiple runs
- **Archive Extraction**: Support for ZIP, RAR, 7Z, TAR.GZ, TAR.BZ2, TAR.XZ, and more
- **Smart Categorization**: Automatic sorting into 13 categories based on file extension
- **Date-Based Organization**: YYYY-MM directory structure using EXIF or file metadata
- **Safe by Default**: Copy mode instead of move mode to preserve originals
- **Comprehensive Logging**: Detailed logs and accurate statistics
- **Error Handling**: Graceful handling of permission errors and missing tools

### Code Review History

#### Review 1: Critical Bug Fixes
- Fixed broken deduplication (associative array export issue)
- Fixed subshell variable scope problems
- Implemented file-based hash registry
- Added process substitution to avoid subshells

#### Review 2: Logic and Safety Improvements
- Fixed category overlaps (json, yaml, jar, apk, etc.)
- Prevented output directory reprocessing
- Changed default action to copy instead of move
- Improved date parsing robustness
- Made tool checking flexible (required vs optional)

#### Review 3: Final Polish
- Fixed exact hash matching (grep -x)
- Fixed output directory path checking (/* instead of *)
- Fixed working directory management
- Implemented accurate statistics tracking
- Added graceful find error handling with set -e

### Technical Details

- **Language**: Bash 4+
- **Error Handling**: `set -euo pipefail`
- **Hash Algorithm**: SHA256
- **Deduplication**: File-based registry
- **Date Extraction**: EXIF → CreateDate → stat → current date

### Known Limitations

- SHA256 is CPU-intensive for very large video files (can switch to MD5 if needed)
- Requires bash 4+ for associative arrays (not used in final version, but syntax requires it)
- Cannot deduplicate files with different content but same hash (extremely unlikely with SHA256)

### Dependencies

**Required:**
- unzip
- tar
- sha256sum
- exiftool
- file

**Optional:**
- unrar (for RAR archives)
- 7z (for 7Z archives)
- gunzip, bunzip2, unxz (for individual compressed files)

## Future Enhancements (Planned)

- [ ] Verification script to validate hash registry
- [ ] Progress bar for large operations
- [ ] Parallel processing for multi-core systems
- [ ] Database backend option for very large collections
- [ ] Web UI for browsing organized files
- [ ] Support for additional archive formats
- [ ] Configurable hash algorithm (MD5, SHA1, SHA256, xxhash)
- [ ] Dry-run mode to preview changes
- [ ] Undo functionality
