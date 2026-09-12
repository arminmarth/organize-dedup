# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.1] — 2026-06-26

### Summary

Massive MIME type expansion based on real-world scan of 88k files in unknown/ and 20k files in archives/.
Added 50+ new MIME types, 5 new categories (email, subtitles, firmware, certs, playlists), removed 3
categories (medical, profiles, cad), and added octet-stream second-pass identification.

### Added — New categories

- **email** — .mbox, .eml, .msg (Outlook) files
- **subtitles** — .srt (SubRip), .vtt (WebVTT) files
- **firmware** — BIOS ROMs, firmware images, disk images (IBM ROM, Genesis, SMS, NES, QEMU, etc.)
- **certs** — PGP keys/signatures, PEM certificates, SSH private keys, DER encoded keys
- **playlists** — .m3u/.m3u8 (MPEG URL) playlist files

### Added — New MIME types (50+)

- Images: JPEG XL, PCX (ZBrush), WMF, EMF, PostScript/EPS
- Videos: MPEG-TS (.ts), WMV, Shockwave Flash (.swf), MXF
- Audio: AMR, WMA, AC3 (Dolby DD)
- Archives: MSI installers, APK (Android), LHa, zlib, compress (.Z), LZMA, ARC, SquashFS
- Executables: ELF object files, DOS executables, Mach-O binaries, WASM
- Documents: OLE2 compound docs, Visio, SketchUp, AutoCAD DXF
- Code: JavaScript, DOS batch, PowerShell, Applesoft BASIC
- Text: gettext .po, NDJSON, INI/config, Windows .reg, TeX, M4
- Data: NumPy, HDF5, FITS, CDF, MATLAB, ICC profiles, Adobe ACO, ETL trace
- Fonts: EOT (Microsoft), Amiga fonts
- Email: mbox, rfc822 (EML), Outlook MSG
- Subtitles: SubRip (SRT), WebVTT
- Firmware: IBM ROM, Genesis/SMS/NES ROM, QEMU disk, floppy images, Linux kernel

### Added — Octet-stream second-pass

When `file --mime-type` reports `application/octet-stream`, a second call to `file -b` checks the
full description for keywords (JavaScript, Python, ELF, DOS executable, BIOS ROM, PCX, Photoshop,
SubRip, ID3, OpenPGP, etc.). This rescues ~21% of octet-stream files from the unknown bucket.

### Changed

- **DICOM** moved from `medical` → `images` (1 file doesn't justify a category)
- **ICC profiles** moved from `profiles` → `data`
- **DXF** moved from `cad` → `documents`
- **APK** categorized as `archives` (was unknown)
- **MSI** categorized as `archives` (was unknown)
- Test suite expanded from 68 → 87 tests

### Removed

- `medical` category (DICOM → images)
- `profiles` category (ICC → data)
- `cad` category (DXF → documents)

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