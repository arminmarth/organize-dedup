# Changelog

All notable changes to this project will be documented in this file.

## [2.0.2] - 2025-12-02

### 🐛 Critical Bug Fixes
- **Fixed script crash**: Removed `local` keyword from Phase 1 and Phase 2 find_args declarations (was causing "local: can only be used in a function" error)
- **Fixed mode preset override bug**: Mode presets now correctly respect explicit command-line flags
  - Added tracking flags (`NAMING_FORMAT_SET`, `ORGANIZE_BY_SET`, `EXTRACT_ARCHIVES_SET`, `RECURSIVE_SET`)
  - Presets only apply when options are at default values
  - Example: `--mode simple --recursive yes` now correctly processes recursively (previously was overridden to `no`)
- **Fixed function return codes**: `apply_mode_presets` and `hash_exists` now properly return 0 to prevent `set -e` from exiting prematurely

### ✨ Improvements
- **Dynamic version in help**: Help text now uses `$VERSION` variable instead of hardcoded version string
- **Clearer help text**: Changed `-i` and `-o` from "required" to showing actual defaults ("default: ." and "default: ./export")

### 📝 Documentation
- Updated all version references to 2.0.2
- Clarified that mode presets only apply to options not explicitly set by user

### 🧪 Testing
All critical functionality verified:
- ✅ Script executes without crashes
- ✅ Mode presets respect explicit flags
- ✅ Deduplication works correctly
- ✅ All hash algorithms work (SHA1, SHA256, SHA512, MD5)
- ✅ Recursive and non-recursive modes work
- ✅ Exit codes are correct

### 🎓 Code Review Status
- **ChatGPT**: "Fix that `local` usage and this is absolutely 'ship it' material." ✅ FIXED
- **Gemini**: "Once the CLI logic is fixed, this script is rock solid." (Grade: A-) ✅ FIXED

---

## [2.0.1] - 2025-12-02

### 🔒 Security
- **Removed `eval` usage** in Phase 1 and 2 - Replaced with bash arrays for safer command construction

### ✅ Correctness
- **Fixed EXIF extension detection** - Extensions like "JPEG", "Matroska" are now normalized to "jpg", "mkv" for proper categorization

### 🛡️ Safety
- **Added INPUT==OUTPUT guard** - Prevents confusing behavior when using `ACTION=mv` with same input/output directory

### 📝 Code Quality
- **Clarified variable scope** - Declared `clean_dt`, `datetime`, and `year_month` at function top for clarity

### 📖 Documentation
- **Updated README** - Clarified that `-i` and `-o` have defaults rather than being strictly required
- **Added mode preset note** - Explained that presets only apply when options are at default values

---

## [2.0.0] - 2025-12-02

### 🎯 Major Features
- **Two modes**: Simple (fast checksum renaming) and Advanced (full-featured organization)
- **Multiple hash algorithms**: SHA1, SHA256, SHA512, MD5
- **Flexible naming formats**: hash, hash_ext, date_hash_ext
- **Multiple organization methods**: none, extension, category, date, category_date
- **Docker support**: Dockerfile and Makefile for containerized execution
- **Rich CLI**: Comprehensive command-line options with --help and --version

### 🔄 Integration
- Combined best features from organize_and_dedup and checksum-file-renamer branches
- Maintained all bug fixes from v1.0.1
- Implemented recommendations from ChatGPT and Gemini code reviews

### 📦 Backward Compatibility
- v1.0 usage patterns still work
- Legacy two-argument format supported: `./script.sh input_dir output_dir`

---

## [1.0.0] - 2025-12-01

### Initial Release
- File organization by category and date
- Archive extraction (ZIP, RAR, 7Z, TAR.*)
- SHA256-based deduplication
- EXIF metadata extraction for date organization
- Copy or move operations
- Comprehensive logging
