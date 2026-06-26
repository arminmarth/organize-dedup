# organize-dedup

`organize_and_dedup.sh` is a single-purpose shell script that scans an input
folder, detects each file's real type by content (not filename), and hardlinks
it into a clean, deduplicated output structure.

The output layout is:

```
<output_dir>/<category>/<YYYY-MM>/<SHA256>.<ext>
```

## What the script does

- **Recursively scans files** in the input directory (follows symlinks).
- **Detects type by content** using `file --mime-type`, not filenames.
- **Falls back to filename extension** for code files that libmagic reports as
  `text/plain` (Go, Rust, TOML, Markdown, YAML, etc.).
- **Normalizes extensions** (e.g. `jpeg` → `jpg`, `tgz` → `tar.gz`).
- **Buckets by category**: `images`, `videos`, `audio`, `documents`, `archives`,
  `text`, `code`, `fonts`, `databases`, `executables`, `profiles`, `medical`,
  `data`, `cad`, `config`, or `unknown`.
- **Groups by month** using EXIF timestamps (DateTimeOriginal → CreateDate →
  MediaCreateDate priority), falling back to filesystem timestamps.
- **Names by SHA-256** and **hardlinks** into the output folder so duplicates
  collapse to a single target path.
- **Deduplicates against pre-existing output files** — any file already in the
  output directory is hashed and checked, regardless of naming convention.
- **Preflight hardlink check** — warns if the output filesystem doesn't support
  hardlinks (files will be copied instead).
- **Handles edge cases**: empty files, files with no extension, Unicode
  filenames, spaces, special characters, and very long filenames.

## Requirements

- `file`, `sha256sum`, `stat`/`gstat`, `date` (GNU coreutils)
- Bash 4.0+ (for associative arrays)

On macOS, install GNU coreutils:

```bash
brew install coreutils
```

This provides `gstat` and `gdate`. The script detects macOS and requires them
automatically.

Optional:

- `exiftool` for more accurate photo/video timestamps (checked at startup, not
  required).

## Usage

```bash
./organize_and_dedup.sh [options] <input_dir> <output_dir>
```

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message |
| `-v`, `--version` | Show version |
| `-n`, `--dry-run` | Preview without modifying the filesystem |
| `-q`, `--quiet` | Suppress per-file log output (summary only) |
| `--maxdepth N` | Limit recursion depth (positive integer) |

### Examples

```bash
# Organize ~/Downloads into ~/MediaArchive
./organize_and_dedup.sh ~/Downloads ~/MediaArchive

# Preview what would happen without making changes
./organize_and_dedup.sh --dry-run ~/Downloads ~/MediaArchive

# Limit to 2 levels deep
./organize_and_dedup.sh --maxdepth 2 ~/Downloads ~/MediaArchive

# Quiet mode — summary only
./organize_and_dedup.sh --quiet ~/Downloads ~/MediaArchive
```

### Output structure

```
MediaArchive/
├── images/
│   ├── 2024-03/
│   │   └── A1B2C3...SHA256.jpg
│   └── 2024-06/
│       └── D4E5F6...SHA256.png
├── documents/
│   └── 2024-01/
│       └── F7G8H9...SHA256.pdf
├── audio/
│   └── 2024-05/
│       └── I1J2K3...SHA256.mp3
└── ...
```

## Notes

- The script hardlinks files. Ensure the output directory is on the same
  filesystem as the input for hardlinks to work. If it's not, the script warns
  and falls back to copying (tracked separately in the summary).
- If the output directory is inside the input directory, it is excluded from
  the scan to avoid recursion. Paths are canonicalized via `realpath` before
  comparison, so symlinks and trailing dots don't bypass this check.
- Re-running the script on the same input/output is safe — all files will be
  detected as duplicates (idempotent).
- The `skipped` counter tracks unreadable files and hash computation failures.
- The `copied` counter tracks files that were copied instead of hardlinked.

## Supported file types

The script detects and categorizes 100+ MIME types across these categories:

- **Images**: JPEG, PNG, GIF, WebP, TIFF, AVIF, BMP, SVG, ICO, HEIC, RAW (CR2/CR3/RAF/RW2/...), PSD, and more
- **Videos**: MP4, MOV, AVI, MKV, WebM, MPEG, 3GP, FLV, and more
- **Audio**: MP3, WAV, FLAC, AAC, M4A, OGG, AIFF, and more
- **Documents**: PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX, RTF, ODT/ODS/ODP, EPUB, MOBI, and more
- **Archives**: ZIP, 7Z, RAR, TAR, GZ, TAR.GZ, BZ2, XZ, ISO, DEB, JAR, RPM, and more
- **Code**: Python, JavaScript/TypeScript, Go, Rust, Ruby, Java, C/C++, Bash, Perl, PHP, and more
- **Text**: JSON, CSV, HTML, XML, YAML, TOML, Markdown, CSS, SQL, and more
- **Fonts**: TTF, OTF, WOFF/WOFF2, and more
- **Databases**: SQLite
- **Other**: Medical (DICOM), CAD (DXF), ICC profiles, pcap captures, executables

## Testing

The repo includes a bats test suite and a test data generator:

```bash
# Install bats
sudo apt-get install -y bats

# Generate test data
python3 tests/generate_test_data.py /tmp/test_input --count 80 --seed 42

# Run the script against it
bash organize_and_dedup.sh /tmp/test_input /tmp/test_output

# Run the test suite
bats tests/
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

This project is open source. See the repository for license details.