# organize-dedup

A focused CLI tool for sorting unlabeled files into a clean structure by type and ensuring unique names via content hashes.

## What it does

- **Sorts files by type** using extensions (images, videos, documents, archives, etc.).
- **Renames files by hash** to avoid collisions and make names consistent.
- **Optionally deduplicates** by skipping files with the same content.

## Repository contents

This repository intentionally contains only the core script, this README, and the license to keep the focus on sorting unlabeled files.

## Prerequisites

**Debian/Ubuntu:**
```bash
sudo apt-get install coreutils file
```

**macOS:**
```bash
brew install coreutils
```

## Quick start

```bash
# organize the current directory into ./export
./organize_and_dedup.sh -i . -o ./export
```

## Usage

```bash
./organize_and_dedup.sh -i /path/to/input -o /path/to/output
```

### Common flags

| Option | Description |
|--------|-------------|
| `-i, --input-dir` | Input directory (defaults to current directory) |
| `-o, --output-dir` | Output directory (defaults to `./export`) |
| `--organize-by` | `extension` to group by extension or `none` for flat output |
| `--naming-format` | `hash_ext` for `<hash>.<ext>` filenames |
| `--deduplicate` | `yes` (default) or `no` to keep all files |
| `-v, --verbose` | Verbose output |

### Examples

```bash
# group by extension with hash-based names
./organize_and_dedup.sh --organize-by extension --naming-format hash_ext -i /files -o /sorted

# flat output, still deduplicated
./organize_and_dedup.sh --organize-by none -i /files -o /flat
```

## License

MIT. See [LICENSE](LICENSE).
