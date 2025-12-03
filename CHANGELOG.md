# CHANGELOG

All notable changes to this project will be documented in this file.

## [2.2.0] - 2025-12-03

### ✨ New Features

#### Link Support
- **Hardlink action** (`--action hardlink`) - Create hard links for zero-copy organization
  - Same data, multiple names, zero additional disk space
  - Original files preserved in original location
  - Must be on same filesystem (partition/drive)
  - Changes propagate to both locations (shared inode)
  
- **Softlink action** (`--action softlink`) - Create symbolic links
  - Works across different filesystems
  - Minimal disk space (just pointer)
  - Broken if original deleted
  - Changes propagate to both locations

- **Action aliases** - Support for `ln`, `symlink`, `ln-s` as aliases

#### Extension Filtering
- **--only-mismatched-extensions** flag - Process ONLY files with wrong extensions
  - Reverse of `--strict-extensions`
  - Enables separating correct and incorrect files into different folders
  - Perfect for organizing files that need extension correction
  - Use with `--fix-extensions` to correct them

### 📝 Documentation
- **LINK_TYPES.md** - Comprehensive guide to link types
  - Detailed comparison of cp, mv, hardlink, softlink
  - Use cases and examples
  - Important warnings and limitations
  - Technical details (inodes, filesystems)
  
- **README updates** - Link types section with quick comparison table
- **Help text updates** - Improved action descriptions

### 📦 Use Cases Enabled
- Dual organization structures with zero disk space
- Separate correct and incorrect extension files
- Cross-filesystem organization with softlinks
- Test organization without moving files

---

## [2.1.2] - 2025-12-03

### ✨ UX Improvements
- **Simplified flag syntax** - Extension correction flags now work like `--verbose` (no value needed)
  - Use `--fix-extensions` instead of `--fix-extensions yes`
  - Use `--strict-extensions` instead of `--strict-extensions yes`
  - Use `--report-extensions` instead of `--report-extensions yes`
  - Old syntax still works for backward compatibility

### 🐛 Bug Fixes
- **Fixed report → fix workflow** - `--report-extensions` no longer adds hashes to deduplication registry
  - Previously: Running `--report-extensions` then `--fix-extensions` would skip all files as duplicates
  - Now: Report mode doesn't pollute the hash registry, allowing subsequent processing
  - Enables proper workflow: audit first, then fix

### 📝 Documentation
- Updated all examples to use simplified flag syntax
- Updated help text to reflect new usage
- README examples updated throughout

---

## [2.1.1] - 2025-12-03

### 🐛 Bug Fixes
- **Fixed "unbound variable" error** - Changed MIME type lookup to use `${MIME_TO_EXT[$mime_type]:-}` instead of direct array access
  - Now compatible with Bash 4.2+ (previous fix required Bash 4.3+)
  - Gracefully handles unknown MIME types by falling back to current extension
  - Prevents script crashes when encountering MIME types not in mapping table

### 📝 Documentation
- **Improved help text** for extension correction options
  - Clarified that options require 'yes' or 'no' value
  - Changed `BOOL` to `yes|no` for better clarity
  - Added usage examples for extension correction in help text
  - Added note about value requirement

### 🧪 Testing
- Verified fix with Office Open XML documents (.docx, .xlsx, .pptx)
- Tested with unknown MIME types (application/octet-stream)
- Confirmed fallback behavior works correctly

---

## [2.1.0] - 2025-12-03

### ✨ New Features
- **Extension Correction** - Detect and fix wrong file extensions using MIME type detection
  - `--fix-extensions` - Automatically correct extensions based on file content
  - `--strict-extensions` - Skip files with incorrect extensions
  - `--report-extensions` - Generate mismatch report without processing
  - Supports 100+ file types (documents, archives, images, video, audio, code, configs)
  - Uses `file --mime-type` for accurate content detection
  - Generates CSV report: `extension_mismatches.csv`

### 📊 Statistics
- **Extension correction tracking** - New counters in summary output:
  - `Extensions corrected` - Number of files with corrected extensions
  - `Extension mismatches detected` - Total mismatches found

### 📝 Reporting
- **CSV mismatch report** - Detailed report of extension mismatches:
  - Columns: original_path, current_ext, detected_ext, mime_type, hash, action
  - Generated when any extension correction flag is used
  - Path shown in completion summary

### 🔧 Implementation
- Added `detect_correct_extension()` function with comprehensive MIME type mapping
- Integrated extension detection into `process_file()` workflow
- Extension correction works in both simple and advanced modes
- Deduplication correctly handles files with different extensions
- File content integrity preserved during correction

### 🧪 Testing
All test cases passed:
- ✅ Report mode detects mismatches without processing
- ✅ Fix mode corrects extensions and preserves content
- ✅ Strict mode skips files with wrong extensions
- ✅ Duplicate handling works with extension correction
- ✅ Simple mode compatibility verified
- ✅ Binary file detection (gzip, etc.) works correctly

### 📚 Documentation
- Updated README.md with extension correction features
- Added examples for all three modes
- Documented CSV report format
- Added use cases and supported file types

---

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
