# Link Types Guide

## Overview

The `organize-dedup` script supports four action types for handling files: **copy**, **move**, **hardlink**, and **softlink**. Each has different characteristics, use cases, and limitations.

## Action Types Comparison

| Feature | Copy (`cp`) | Move (`mv`) | Hardlink (`hardlink`) | Softlink (`softlink`) |
|---------|-------------|-------------|----------------------|----------------------|
| **Disk Space** | Doubles data | No change | No additional space | Minimal (pointer only) |
| **Original File** | Preserved | Removed | Preserved | Preserved |
| **Same Filesystem** | Not required | Not required | **Required** | Not required |
| **Independent** | Yes | N/A | No (shared inode) | No (points to original) |
| **If Original Deleted** | Unaffected | N/A | Unaffected | **Broken link** |
| **If Content Changes** | Unaffected | N/A | **Both change** | **Both change** |
| **Cross-Platform** | Yes | Yes | Linux/Unix only | Linux/Unix only |

## Detailed Explanations

### Copy (`--action cp`)

**What it does:**
- Creates a complete duplicate of the file
- Original and copy are completely independent

**Use cases:**
- **Backup and archival** - Preserve original files while organizing copies
- **Cross-filesystem organization** - Input and output on different drives/partitions
- **Safety** - Original files remain untouched

**Advantages:**
- ✅ Safe - original files never modified
- ✅ Works across different filesystems
- ✅ Files are independent - changes don't affect each other

**Disadvantages:**
- ❌ Doubles disk space usage
- ❌ Slower for large files
- ❌ If original changes, copy doesn't update

**Example:**
```bash
./organize_and_dedup.sh --action cp -i /unsorted -o /organized
```

---

### Move (`--action mv`)

**What it does:**
- Relocates files to new location
- Original location is emptied

**Use cases:**
- **Permanent reorganization** - Clean up source directory
- **Disk space constraints** - No duplication needed
- **Migration** - Moving files to new structure

**Advantages:**
- ✅ No additional disk space used
- ✅ Fast operation (especially on same filesystem)
- ✅ Clean source directory

**Disadvantages:**
- ❌ Original files are gone
- ❌ Cannot revert easily
- ❌ Risky if script fails mid-process

**Example:**
```bash
./organize_and_dedup.sh --action mv -i /unsorted -o /organized
```

---

### Hardlink (`--action hardlink`)

**What it does:**
- Creates a new directory entry pointing to the same inode
- Both paths reference the exact same data on disk
- File has multiple names but single content

**Use cases:**
- **Dual organization** - Original structure + organized structure, zero space cost
- **Deduplication** - Multiple references to same file without duplication
- **Testing organization** - Try new structure without moving files

**Advantages:**
- ✅ **Zero additional disk space** - both paths share same data
- ✅ Original files preserved in original location
- ✅ Fast operation
- ✅ If either path is deleted, data remains (until all links removed)
- ✅ Automatic synchronization - changes visible in both locations

**Disadvantages:**
- ❌ **Must be on same filesystem** - cannot hardlink across partitions/drives
- ❌ **Changes affect both locations** - editing one changes the other
- ❌ **Checksum changes propagate** - modifying file changes hash in both locations
- ❌ Cannot hardlink directories (files only)
- ❌ Confusing for users unfamiliar with inodes

**Technical details:**
- Both paths point to the same inode number
- File is only truly deleted when link count reaches zero
- `ls -i` shows same inode number for both paths
- `stat` shows link count > 1

**Example:**
```bash
./organize_and_dedup.sh --action hardlink -i /unsorted -o /organized
# Now /unsorted/file.jpg and /organized/images/2024-12/hash.jpg are the SAME file
```

**Verification:**
```bash
ls -i /unsorted/file.jpg /organized/images/2024-12/hash.jpg
# Both show same inode number, e.g., "12345678"
```

---

### Softlink / Symbolic Link (`--action softlink`)

**What it does:**
- Creates a pointer (shortcut) to the original file
- The link itself is a small file containing the path to the target

**Use cases:**
- **Cross-filesystem organization** - Link to files on different drives
- **Dynamic references** - Links update if target is replaced
- **Preserving originals** - Organized structure without moving data

**Advantages:**
- ✅ Works across different filesystems
- ✅ Minimal disk space (just the pointer)
- ✅ Can link to directories
- ✅ Original files preserved
- ✅ Easy to identify as links (`ls -l` shows `->`)

**Disadvantages:**
- ❌ **Broken if original deleted** - link becomes invalid
- ❌ **Changes affect both** - editing through link modifies original
- ❌ Slower access (extra lookup required)
- ❌ Some applications don't follow symlinks
- ❌ Relative vs absolute path considerations

**Technical details:**
- Link is a special file type (not a regular file)
- Contains path to target (absolute or relative)
- `readlink` shows target path
- `ls -l` shows link with `->` arrow

**Example:**
```bash
./organize_and_dedup.sh --action softlink -i /unsorted -o /organized
# Creates /organized/images/2024-12/hash.jpg -> /unsorted/file.jpg
```

**Verification:**
```bash
ls -l /organized/images/2024-12/hash.jpg
# Shows: hash.jpg -> /absolute/path/to/unsorted/file.jpg
```

---

## Use Case Recommendations

### Scenario: Organizing Photos While Keeping Originals

**Best choice: Hardlink** (if same filesystem)
```bash
./organize_and_dedup.sh --action hardlink -i /photos/unsorted -o /photos/organized
```
- Original folder structure preserved
- Organized structure created
- Zero additional space
- Both locations work identically

**Alternative: Softlink** (if different filesystems)
```bash
./organize_and_dedup.sh --action softlink -i /external/photos -o /home/organized
```

---

### Scenario: Fixing Wrong Extensions Without Duplication

**Best choice: Hardlink + --fix-extensions**
```bash
./organize_and_dedup.sh --action hardlink --fix-extensions -i /files -o /fixed
```
- Original files with wrong extensions remain
- Organized files have correct extensions
- Same data, different names, zero space cost

---

### Scenario: Separating Files with Wrong Extensions

**Best choice: Hardlink + --only-mismatched-extensions**
```bash
# First: Extract only mismatched files
./organize_and_dedup.sh --action hardlink --only-mismatched-extensions --fix-extensions -i /files -o /mismatched

# Then: Extract only correct files
./organize_and_dedup.sh --action hardlink --strict-extensions -i /files -o /correct
```
- Two organized folders: one with corrected extensions, one with originally correct files
- Original files preserved
- Zero additional space (all hardlinks)

---

### Scenario: Backup Before Reorganization

**Best choice: Copy first, then move**
```bash
# Step 1: Backup
./organize_and_dedup.sh --action cp -i /important -o /backup

# Step 2: Reorganize
./organize_and_dedup.sh --action mv -i /important -o /organized
```

---

## Important Warnings

### ⚠️ Hardlink Checksum Warning

**Problem:** If you modify a file in one location, the checksum changes in BOTH locations.

**Example:**
```bash
# Create hardlinked organization
./organize_and_dedup.sh --action hardlink -i /photos -o /organized

# Later, edit a photo in /photos
vim /photos/vacation/IMG_001.jpg

# The file in /organized also changes!
# If you run the script again, it will have a DIFFERENT hash
# This could cause it to be treated as a new file
```

**Solution:** Be aware that hardlinks share content. Don't edit files if you want stable hashes.

---

### ⚠️ Softlink Broken Link Warning

**Problem:** If you delete the original file, softlinks break.

**Example:**
```bash
# Create softlinked organization
./organize_and_dedup.sh --action softlink -i /temp -o /organized

# Later, clean up /temp
rm -rf /temp

# Now /organized contains broken links!
ls -l /organized/images/2024-12/hash.jpg
# Shows: hash.jpg -> /temp/file.jpg (broken link)
```

**Solution:** Only use softlinks when originals are permanent, or use hardlinks instead.

---

### ⚠️ Hardlink Filesystem Limitation

**Problem:** Hardlinks only work within the same filesystem.

**Example:**
```bash
# This FAILS if /external is a different partition
./organize_and_dedup.sh --action hardlink -i /external/files -o /home/organized
# Error: "files must be on same filesystem"
```

**Solution:** Check if input and output are on same filesystem:
```bash
df /input /output
# If different "Filesystem" column, use softlink or copy instead
```

---

## Choosing the Right Action

**Use Copy when:**
- You need a true backup
- Input and output are on different filesystems
- You want complete independence between original and organized

**Use Move when:**
- You want to clean up the source directory
- Disk space is limited
- You're confident in the organization structure

**Use Hardlink when:**
- Input and output are on the **same filesystem**
- You want zero additional disk space
- You want to preserve originals while having organized structure
- You understand that changes affect both locations

**Use Softlink when:**
- Input and output are on **different filesystems**
- You want minimal disk space usage
- Original files will remain in place permanently
- You're okay with links breaking if originals are deleted

---

## Advanced Examples

### Example 1: Test Organization with Hardlinks

```bash
# Test organization without committing
./organize_and_dedup.sh --action hardlink -i /photos -o /test_organized

# Review the structure
ls -R /test_organized

# If satisfied, remove test and do real organization
rm -rf /test_organized
./organize_and_dedup.sh --action mv -i /photos -o /organized
```

---

### Example 2: Dual Organization Structures

```bash
# Create two different organizations of the same files
./organize_and_dedup.sh --action hardlink --organize-by extension -i /files -o /by_extension
./organize_and_dedup.sh --action hardlink --organize-by category_date -i /files -o /by_category

# Now you have:
# - /files (original structure)
# - /by_extension (organized by extension)
# - /by_category (organized by category and date)
# All pointing to the same data, zero additional space!
```

---

### Example 3: Separate Correct and Incorrect Extensions

```bash
# Extract files with wrong extensions (and fix them)
./organize_and_dedup.sh --action hardlink --only-mismatched-extensions --fix-extensions \
  -i /files -o /corrected_extensions

# Extract files with correct extensions
./organize_and_dedup.sh --action hardlink --strict-extensions \
  -i /files -o /already_correct

# Now you have:
# - /files (original, untouched)
# - /corrected_extensions (only files that had wrong extensions, now fixed)
# - /already_correct (only files that had correct extensions)
```

---

## Technical Reference

### Inode Explanation

An **inode** is a data structure that stores file metadata (permissions, timestamps, etc.) and pointers to the actual data blocks on disk.

- **Regular file:** One filename → one inode → data blocks
- **Hardlink:** Multiple filenames → same inode → same data blocks
- **Softlink:** One filename → one inode (link) → points to another filename

### Checking Link Types

```bash
# Check if file is a hardlink (link count > 1)
stat filename | grep Links

# Check if file is a softlink
ls -l filename | grep '^l'

# Find all hardlinks to a file
find / -inum $(stat -c %i filename)

# Show inode number
ls -i filename
```

---

## Summary

| Goal | Recommended Action |
|------|-------------------|
| Backup files | `--action cp` |
| Reorganize permanently | `--action mv` |
| Dual structure, same filesystem | `--action hardlink` |
| Dual structure, different filesystem | `--action softlink` |
| Test organization | `--action hardlink` (then delete) |
| Save disk space | `--action hardlink` or `--action softlink` |
| Maximum safety | `--action cp` |

Choose wisely based on your needs!
