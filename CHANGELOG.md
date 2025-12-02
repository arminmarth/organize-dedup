# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.1] - 2024-12-02

### Fixed
- **Security:** Removed `eval` usage in Phase 1 and Phase 2 (replaced with bash arrays for safer command construction)
- **Correctness:** EXIF-detected file extensions are now normalized (e.g., "JPEG" → "jpg", "Matroska" → "mkv") for proper categorization
- **Safety:** Added guard against using `INPUT_DIR == OUTPUT_DIR` with `ACTION=mv` to prevent confusing behavior
- **Code Quality:** Clarified variable scope by declaring `clean_dt`, `datetime`, and `year_month` at the top of `process_file` function

### Changed
- **README:** Clarified that `-i` and `-o` have defaults (`.` and `./export`) rather than being strictly required
- **README:** Added note that mode presets only apply when options are at default values (explicit flags take precedence)

### Code Review
All improvements based on comprehensive code reviews from ChatGPT (2 rounds) and Gemini. All reviewers agreed v2.0.0 was production-ready; these changes are polish and safety improvements.

---

## [2.0.0] - 2024-12-02

### Major Release - Full Integration

This release integrates the best features from both `organize_and_dedup` v1.0 and `checksum-file-renamer` v1.1 into a unified, feature-rich tool.

### Added
- **Multiple Hash Algorithms**: Support for SHA1, SHA256, SHA512, and MD5
- **Simple Mode**: Fast checksum-based renaming with extension organization
- **Advanced Mode**: Full-featured organization (same as v1.0 behavior)
- **Flexible Naming Formats**: Choose between `hash`, `hash_ext`, or `date_hash_ext`
- **Multiple Organization Methods**: `none`, `extension`, `category`, `date`, or `category_date`
- **Rich CLI**: Comprehensive `--help` text with examples
- **Docker Support**: Dockerfile and Makefile for containerized deployment
- **Configurable Options**: Control archive extraction, recursion, and deduplication
- **Verbose and Quiet Modes**: Control output verbosity (`-v`, `-q`)
- **Version Flag**: `--version` to display version information

### Changed
- **CLI Interface**: New option-based interface (backward compatible with v1.0)
- **Mode Presets**: Simple and advanced modes with sensible defaults
- **Hash Registry**: Now includes algorithm in filename (`.hash_registry_<algorithm>.txt`)
- **Documentation**: Completely rewritten README with comprehensive examples
- **File Naming**: Configurable naming format (previously always `date_hash.ext`)
- **Organization**: Configurable organization method (previously always `category/date`)

### Improved
- **Flexibility**: Choose exactly how files are named and organized
- **Performance**: Option to use faster hash algorithms (MD5) for large files
- **Usability**: Clear help text and examples
- **Deployment**: Docker support for consistent environments
- **Compatibility**: Maintains backward compatibility with v1.0 usage

### Migration from v1.0
- v1.0 usage still works: `./organize_and_dedup.sh /input /output`
- v1.0 behavior is now "advanced mode" (default)
- Environment variables still work: `ACTION=mv ./script.sh`
- Hash registry from v1.0 is compatible (SHA256 algorithm)

---

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

---

## Future Enhancements (Planned)

- [ ] Verification script to validate hash registry
- [ ] Progress bar for large operations
- [ ] Parallel processing for multi-core systems
- [ ] Database backend option for very large collections
- [ ] Web UI for browsing organized files
- [ ] Support for additional archive formats
- [ ] Dry-run mode to preview changes
- [ ] Undo functionality
- [ ] Cloud storage integration (S3, Google Drive, etc.)
- [ ] Plugin system for custom categories

---

## Version History Summary

- **v2.0.1** (2024-12-02) - Security and correctness improvements based on code reviews
- **v2.0.0** (2024-12-02) - Full integration with multiple modes, hash algorithms, and Docker support
- **v1.0.0** (2024-12-02) - Initial release with advanced organization and deduplication
