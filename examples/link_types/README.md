# Link Types Examples

Demonstrations of hardlink and softlink functionality.

## Example 1: Hardlink - Dual Organization, Zero Space

```bash
#!/bin/bash
# Create test files
mkdir -p photos/vacation photos/family
echo "Vacation photo 1" > photos/vacation/IMG_001.jpg
echo "Vacation photo 2" > photos/vacation/IMG_002.jpg
echo "Family photo 1" > photos/family/IMG_003.jpg

# Create organized structure with hardlinks (zero additional space)
../../organize_and_dedup.sh --action hardlink -i photos -o organized

# Verify both structures exist
ls -R photos/
ls -R organized/

# Check inode numbers (should be the same)
ls -i photos/vacation/IMG_001.jpg
find organized -name "*IMG_001*" -exec ls -i {} \;

# Check link count (should be 2)
stat photos/vacation/IMG_001.jpg | grep Links
```

**Result:** You now have two directory structures (original + organized) pointing to the same data, using zero additional disk space!

## Example 2: Softlink - Cross-Filesystem Organization

```bash
#!/bin/bash
# Simulate external drive (different filesystem)
mkdir -p /tmp/external_drive/files
mkdir -p /home/user/organized

# Create test files on "external drive"
echo "External file 1" > /tmp/external_drive/files/doc1.txt
echo "External file 2" > /tmp/external_drive/files/doc2.pdf

# Create organized structure with softlinks
../../organize_and_dedup.sh --action softlink -i /tmp/external_drive/files -o /home/user/organized

# Verify softlinks
ls -l /home/user/organized/documents/*/
# Shows: filename -> /tmp/external_drive/files/original_file
```

**Result:** Organized structure with symbolic links pointing to files on external drive.

## Example 3: Separate Correct and Incorrect Extensions

```bash
#!/bin/bash
# Create test files with mixed extensions
mkdir -p mixed_files
echo "Text content" > mixed_files/document.jpg  # Wrong extension
echo "More text" > mixed_files/readme.txt      # Correct extension
echo "Data file" > mixed_files/data.xyz        # Wrong extension

# Extract files with wrong extensions (and fix them)
../../organize_and_dedup.sh --action hardlink --only-mismatched-extensions --fix-extensions \
  -i mixed_files -o corrected_extensions

# Extract files with correct extensions
../../organize_and_dedup.sh --action hardlink --strict-extensions \
  -i mixed_files -o already_correct

# Check results
echo "Original files:"
ls mixed_files/

echo -e "\nCorrected extensions:"
find corrected_extensions -type f ! -name ".*" ! -name "*.csv" ! -name "*.log"

echo -e "\nAlready correct:"
find already_correct -type f ! -name ".*" ! -name "*.csv" ! -name "*.log"
```

**Result:** Three directories:
- `mixed_files/` - Original files untouched
- `corrected_extensions/` - Only files that had wrong extensions (now fixed)
- `already_correct/` - Only files that already had correct extensions

All using zero additional disk space (hardlinks)!

## Important Notes

### Hardlink Limitations
- **Must be on same filesystem** - Check with `df /input /output`
- **Changes propagate** - Editing one location affects the other
- **Checksum changes** - If you modify a file, hash changes in both locations

### Softlink Limitations
- **Broken if original deleted** - Links become invalid
- **Changes propagate** - Editing through link modifies original
- **Relative vs absolute paths** - Script uses absolute paths for reliability

## Verification Commands

```bash
# Check if files are hardlinked (same inode)
ls -i file1 file2

# Check link count
stat -c "%h" filename

# Check if file is a softlink
ls -l filename | grep "^l"

# Show softlink target
readlink filename

# Find all hardlinks to a file
find / -inum $(stat -c %i filename) 2>/dev/null
```
