# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] — 2026-06-26

### Summary

Major release: 17 bug fixes, 3 new features, 68-test bats suite, and real CI.
This is a breaking change for anyone relying on the `skipped` counter being
always zero or the absence of the `copied` counter in the summary output.

### Added

- **`--dry-run` / `-n`**: preview mode — no filesystem modifications (#20)
- **`--quiet` / `-q`**: suppress per-file log output, summary only (#21)
- **`--maxdepth N`**: limit recursion depth (#23)
- **Preflight hardlink check** — warns if output filesystem doesn't support hardlinks (#33)
- **`copied` counter** in summary output — tracks files copied instead of hardlinked (#25)
- **macOS tool detection** — checks for `gstat`/`gdate` from coreutils (#52)
- **bats test suite** (68 tests) covering CLI, file detection, dedup, edge cases, and issue regressions (#22)
- **Test data generator** (`tests/generate_test_data.py`) with 21 file types, valid MIME headers, seeded reproducibility
- **CI workflow** — GitHub Actions runs bats test suite on every push/PR
- **Expanded MIME type coverage** — 100+ types across 15 categories (#37, #39)
- **Filename-based fallback** for code files reported as `text/plain` by libmagic (#37)

### Fixed

- **#15**: `skipped` counter now increments for unreadable files and hash failures
- **#16**: `cleanup_on_interrupt` uses exit 130 for SIGINT, 143 for SIGTERM (separate handlers)
- **#25**: Copy fallback now warns loudly with `WARNING:` prefix and `COPIED, not hardlinked` message
- **#30**: `find` uses `-L` to follow symlinked input directories
- **#31**: Counters initialized before trap is set (fixes unbound variable on Ctrl-C during startup)
- **#34**: tar.gz files saved with `.tar.gz` extension — uses `file -bz` to decompress and verify tar content
- **#37**: Python, Go, Rust, YAML, TOML, Markdown, and other code files correctly classified
- **#38**: exiftool called per-tag in priority order (DateTimeOriginal → CreateDate → MediaCreateDate)
- **#39**: RPM, Android APK, YAML, TOML, Markdown, CSS, SQL, and other missing MIME types added
- **#41**: `find` commands use `--` before user-supplied paths (prevents dash-prefixed paths crashing)
- **#45**: MIME type lowercased before case matching (`mime="${mime,,}"`)
- **#47**: Input/output paths canonicalized via `realpath` before comparison (handles symlinks, trailing dots)
- **#48**: Pre-existing non-hash-named files in output are now hashed and deduped against
- **#49**: Removed unreachable `tgz` branch from `normalize_extension`, restored in correct location
- **#51**: `seen_hashes` stores flag (`1`) not file path (prevents stale path references)
- **#52**: macOS detection via `uname` — requires `gstat`/`gdate` from coreutils

### Changed

- Version bumped to 0.9.0
- Usage line updated to show options: `Usage: organize_and_dedup.sh [options] <input_dir> <output_dir>`
- Summary output now includes `copied: N` count
- Interrupt/terminate messages now include `copied: $copied`
- README.md fully rewritten with options table, examples, output structure, and supported types
- CONTRIBUTING.md expanded with testing instructions and code style guidelines

### Review feedback addressed

- Hardlink preflight probe uses unique `mktemp`-style names (not fixed names)
- `--maxdepth` validates positive integer before passing to `find`
- Dry-run mode skips `mkdir -p` (no filesystem modification during preview)
- tar.gz detection uses `file -bz` (decompress) instead of gzip origin metadata
- Code-file filename fallback runs inside `text/plain` case (before generic `txt text`)

## [1.0.0] — 2025

Initial release.

- Recursive file scanning with MIME-based type detection
- SHA-256 deduplication with hardlinking
- Category/YYYY-MM output structure
- EXIF date extraction (optional exiftool)
- Cross-platform stat handling (GNU/BSD)
- Output directory exclusion from scan