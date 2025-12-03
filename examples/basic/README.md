# Basic Examples

This directory contains basic usage examples for organize-dedup.

## Example 1: Simple Copy and Organize

```bash
# Create test files
mkdir -p input
echo "Document 1" > input/doc1.txt
echo "Document 2" > input/doc2.pdf
echo "Image data" > input/photo.jpg

# Run organize-dedup
../organize_and_dedup.sh --action cp -i input -o output

# Check results
ls -R output/
```

## Example 2: Move Files

```bash
# Move files instead of copy
../organize_and_dedup.sh --action mv -i input -o output

# Original input directory is now empty
```

## Example 3: Organize by Extension Only

```bash
# Organize by extension, flat naming
../organize_and_dedup.sh --organize-by extension --naming-format hash_ext -i input -o output
```

## Run All Basic Examples

```bash
./run_examples.sh
```
