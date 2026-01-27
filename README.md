# organize-dedup

`organize_and_dedup.sh` is a single-purpose shell script that scans an input
folder, detects each file's real type, and hardlinks it into a clean,
deduplicated output structure. The output layout is:

```
<output_dir>/<category>/<YYYY-MM>/<SHA256>.<ext>
```

## What the script does

- **Recursively scans files** in the input directory.
- **Detects type by content** using `file --mime-type`, not filenames.
- **Normalizes extensions** (for example `jpeg` → `jpg`, `tiff` → `tiff`).
- **Buckets by category** such as `images`, `videos`, `audio`, `documents`,
  `archives`, `text`, `executables`, or `unknown`.
- **Groups by month** using EXIF timestamps when available, falling back to
  filesystem timestamps.
- **Names by SHA-256** and **hardlinks** into the output folder so duplicates
  collapse to a single target path.
- **Skips duplicates** when the output filename already exists.

## Requirements

The script expects these commands to be available:

- `file`, `sha256sum`, `stat`/`gstat`, `date` (GNU coreutils; on macOS install
  `coreutils` to get `gdate` and `gstat` for GNU-style flags)

Optional:

- `exiftool` for more accurate photo/video timestamps.

## Usage

```bash
./organize_and_dedup.sh <input_dir> <output_dir>
```

```bash
./organize_and_dedup.sh --version
```

### Example

```bash
# organize ~/Downloads into ~/MediaArchive
./organize_and_dedup.sh ~/Downloads ~/MediaArchive
```

## Notes

- The script hardlinks files. Ensure the output directory is on the same
  filesystem as the input for hardlinks to work.
- If the output directory is inside the input directory, it is excluded from
  the scan to avoid recursion.
