# Examples

Real-world usage examples and demonstrations for organize-dedup.

## Directory Structure

```
examples/
├── basic/                 # Basic usage examples
├── advanced/              # Advanced features
├── link_types/            # Hardlink and softlink examples
└── extension_correction/  # Extension correction examples
```

## Quick Start

### Basic Copy and Organize

```bash
cd basic/
# Follow instructions in basic/README.md
```

### Link Types (Hardlink/Softlink)

```bash
cd link_types/
# Follow instructions in link_types/README.md
```

### Extension Correction

```bash
cd extension_correction/
# Follow instructions in extension_correction/README.md
```

## Example Categories

### Basic Examples
- Simple copy and organize
- Move files
- Organize by extension
- Organize by category

### Link Types Examples
- Hardlink: Dual organization, zero space
- Softlink: Cross-filesystem organization
- Separate correct and incorrect extensions

### Extension Correction Examples
- Report mode: Audit files
- Fix mode: Auto-correct extensions
- Strict mode: Only correct files
- Only mismatched: Only wrong files
- Workflow: Audit → Review → Fix

### Advanced Examples
- Custom organization methods
- Hash algorithm selection
- Archive extraction
- Deduplication strategies

## Running Examples

Each example directory contains:
- `README.md` - Detailed instructions
- Sample commands
- Expected results
- Verification steps

## Contributing Examples

To add a new example:
1. Create directory under appropriate category
2. Add README.md with clear instructions
3. Include sample commands and expected output
4. Test the example
5. Submit pull request

## Support

For questions or issues with examples:
- Open an issue: https://github.com/arminmarth/organize-dedup/issues
- Check documentation: https://github.com/arminmarth/organize-dedup
