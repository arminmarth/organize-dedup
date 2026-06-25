#!/usr/bin/env python3
"""Generate test data for organize_and_dedup.sh.

Creates a directory tree with realistic files covering the edge cases
identified in GitHub issues #15-#52.

Usage:
    python3 tests/generate_test_data.py /tmp/test_input [--count N] [--seed S]

Covered scenarios:
  - 19 file types with valid MIME headers (images, audio, video, docs, code, text, archives, fonts, db)
  - Duplicate files (same content, different names) → dedup test
  - Wrong extension files → MIME detection test (#37)
  - No-extension files → fallback test
  - Empty files → edge case (#35)
  - tar.gz misnamed as .gz → issue #34
  - Plain .gz named as .tar.gz → false positive check
  - Unicode filenames, spaces, special chars ( ) & +
  - Very long filename (200+ chars)
  - Identical content different extensions (.txt vs .csv)
  - 5 exact duplicate JPEGs → dedup stress test
  - Random nesting depth (0-4 levels)
  - Random dates (2015-2026) via mtime + EXIF (if exiftool installed)
"""

import argparse
import gzip
import io
import json
import os
import random
import shutil
import sqlite3
import struct
import subprocess
import sys
import tarfile
import time
import zipfile
import zlib
from pathlib import Path


# --- Minimal valid file generators (so `file --mime-type` detects correctly) ---

def make_jpeg(path, width=100, height=100):
    with open(path, "wb") as f:
        f.write(b"\xff\xd8")  # SOI
        f.write(b"\xff\xe0")  # APP0
        f.write(struct.pack(">H", 16))
        f.write(b"JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00")
        f.write(b"\xff\xc0")  # SOF0
        f.write(struct.pack(">H", 11))
        f.write(b"\x08")
        f.write(struct.pack(">HH", height, width))
        f.write(b"\x03\x01\x22\x00")
        f.write(b"\xff\xda")  # SOS
        f.write(struct.pack(">H", 8))
        f.write(b"\x03\x01\x22\x00\x3f\x00")
        f.write(b"\x00" * 10)
        f.write(b"\xff\xd9")  # EOI


def make_png(path, width=100, height=100):
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
        chunk = b"IHDR" + ihdr
        f.write(struct.pack(">I", len(ihdr)))
        f.write(chunk)
        f.write(struct.pack(">I", zlib.crc32(chunk) & 0xffffffff))
        raw = b"\x00" + b"\x00" * (width * 3)
        compressed = zlib.compress(raw * height)
        chunk = b"IDAT" + compressed
        f.write(struct.pack(">I", len(compressed)))
        f.write(chunk)
        f.write(struct.pack(">I", zlib.crc32(chunk) & 0xffffffff))
        chunk = b"IEND"
        f.write(struct.pack(">I", 0))
        f.write(chunk)
        f.write(struct.pack(">I", zlib.crc32(chunk) & 0xffffffff))


def make_gif(path, width=100, height=100):
    with open(path, "wb") as f:
        f.write(b"GIF89a")
        f.write(struct.pack("<HH", width, height))
        f.write(b"\x80\x00\x00")
        f.write(b"\x00\x00\x00\xff\xff\xff")
        f.write(b"\x2c")
        f.write(struct.pack("<HHHH", 0, 0, width, height))
        f.write(b"\x00")
        f.write(b"\x02\x02\x4c\x01\x00")
        f.write(b"\x00")
        f.write(b"\x3b")


def make_pdf(path):
    content = (
        b"%PDF-1.4\n"
        b"1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
        b"2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n"
        b"3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n"
        b"xref\n0 4\n"
        b"0000000000 65535 f \n"
        b"0000000009 00000 n \n"
        b"0000000058 00000 n \n"
        b"0000000115 00000 n \n"
        b"trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n190\n%%EOF"
    )
    with open(path, "wb") as f:
        f.write(content)


def make_mp3(path, duration_sec=1):
    with open(path, "wb") as f:
        header = b"\xff\xfb\x90\x64"
        frame_size = 417
        for _ in range(max(1, duration_sec * 38)):
            f.write(header)
            f.write(b"\x00" * (frame_size - 4))


def make_wav(path, duration_sec=1):
    sample_rate = 8000
    num_samples = sample_rate * duration_sec
    data = b"\x00\x00" * num_samples
    with open(path, "wb") as f:
        f.write(b"RIFF")
        f.write(struct.pack("<I", 36 + len(data)))
        f.write(b"WAVE")
        f.write(b"fmt ")
        f.write(struct.pack("<IHHIIHH", 16, 1, 1, sample_rate, sample_rate * 2, 2, 16))
        f.write(b"data")
        f.write(struct.pack("<I", len(data)))
        f.write(data)


def make_mp4(path, duration_sec=1):
    buf = io.BytesIO()

    def write_box(buf, box_type, data):
        buf.write(struct.pack(">I", 8 + len(data)))
        buf.write(box_type)
        buf.write(data)

    ftyp = b"isom\x00\x00\x02\x00isomiso2avc1mp41"
    write_box(buf, b"ftyp", ftyp)
    mvhd = struct.pack(">I", 0) * 4 + b"\x00" * 80
    write_box(buf, b"moov", mvhd)
    with open(path, "wb") as f:
        f.write(buf.getvalue())


def make_zip(path):
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("test.txt", "test content")
        z.writestr("nested/data.json", '{"key": "value"}')


def make_targz(path):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        info = tarfile.TarInfo(name="test.txt")
        info.size = 12
        tar.addfile(info, io.BytesIO(b"test content"))
    with open(path, "wb") as f:
        f.write(buf.getvalue())


def make_gz(path):
    with gzip.open(path, "wb") as f:
        f.write(b"just gzipped text, not a tar")


def make_json(path):
    with open(path, "w") as f:
        json.dump({"name": "test", "value": 42, "items": [1, 2, 3]}, f, indent=2)


def make_csv(path):
    with open(path, "w") as f:
        f.write("name,age,city\nAlice,30,Sydney\nBob,25,Melbourne\n")


def make_html(path):
    with open(path, "w") as f:
        f.write("<!DOCTYPE html>\n<html><head><title>Test</title></head>")
        f.write("<body><h1>Hello</h1></body></html>\n")


def make_xml(path):
    with open(path, "w") as f:
        f.write('<?xml version="1.0"?>\n<root><item>test</item></root>')


def make_python(path):
    with open(path, "w") as f:
        f.write("#!/usr/bin/env python3\n")
        f.write("def hello():\n    print('Hello, World!')\n")
        f.write("if __name__ == '__main__':\n    hello()\n")


def make_bash(path):
    with open(path, "w") as f:
        f.write("#!/bin/bash\necho 'Hello from bash'\n")
        f.write("for i in 1 2 3; do\n  echo $i\ndone\n")


def make_text(path):
    with open(path, "w") as f:
        f.write("This is a plain text file.\nLine 2 here.\n")


def make_ttf(path):
    tables = {
        b"head": b"\x00\x01\x00\x00" + b"\x00" * 54,
        b"cmap": b"\x00\x00\x00\x00" + b"\x00" * 4,
        b"glyf": b"\x00" * 10,
        b"loca": b"\x00\x00\x00\x00",
        b"maxp": b"\x00\x00\x50\x00" + b"\x00" * 28,
    }
    num_tables = len(tables)
    header_size = 12 + num_tables * 16
    offset = header_size
    table_entries = []
    table_data = b""
    for tag, data in tables.items():
        table_entries.append((tag, 0, offset, len(data)))
        padded = data + b"\x00" * ((4 - len(data) % 4) % 4)
        table_data += padded
        offset += len(padded)
    with open(path, "wb") as f:
        f.write(struct.pack(">IHhHH", 0x00010000, num_tables, 256, 8, 1))
        for tag, checksum, off, length in table_entries:
            f.write(tag + struct.pack(">III", checksum, off, length))
        f.write(table_data)


def make_sqlite(path):
    conn = sqlite3.connect(path)
    c = conn.cursor()
    c.execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")
    c.execute("INSERT INTO test (name) VALUES ('Alice'), ('Bob')")
    conn.commit()
    conn.close()


def make_empty(path):
    open(path, "w").close()


def make_js(path):
    with open(path, "w") as f:
        f.write("console.log('hello world');\n")


def make_c(path):
    with open(path, "w") as f:
        f.write('#include <stdio.h>\nint main() { printf("hello\\n"); return 0; }\n')


GENERATORS = {
    "jpg": make_jpeg,
    "png": make_png,
    "gif": make_gif,
    "pdf": make_pdf,
    "mp3": make_mp3,
    "wav": make_wav,
    "mp4": make_mp4,
    "zip": make_zip,
    "tar.gz": make_targz,
    "gz": make_gz,
    "json": make_json,
    "csv": make_csv,
    "html": make_html,
    "xml": make_xml,
    "py": make_python,
    "sh": make_bash,
    "txt": make_text,
    "ttf": make_ttf,
    "sqlite": make_sqlite,
    "js": make_js,
    "c": make_c,
}


def add_exif_date(path, year, month):
    if not shutil.which("exiftool"):
        return False
    day = random.randint(1, 28)
    date_str = f"{year:04d}:{month:02d}:{day:02d} 12:00:00"
    try:
        subprocess.run(
            ["exiftool", "-overwrite_original",
             f"-DateTimeOriginal={date_str}",
             f"-CreateDate={date_str}",
             str(path)],
            capture_output=True, timeout=5
        )
        return True
    except Exception:
        return False


def set_mtime(path, year, month):
    day = random.randint(1, 28)
    timestamp = time.mktime((year, month, day, 12, 0, 0, 0, 0, 0))
    os.utime(path, (timestamp, timestamp))


def generate_test_data(output_dir, count=50, seed=None):
    if seed is not None:
        random.seed(seed)

    root = Path(output_dir)
    if root.exists():
        shutil.rmtree(root)
    root.mkdir(parents=True, exist_ok=True)

    generated = []
    categories = list(GENERATORS.keys())

    # Standard files
    for i in range(count):
        ext = random.choice(categories)
        depth = random.randint(0, 4)
        subdir = root
        for d in range(depth):
            subdir = subdir / f"subdir_{random.randint(0, 3)}"
        subdir.mkdir(parents=True, exist_ok=True)

        year = random.randint(2015, 2026)
        month = random.randint(1, 12)

        if random.random() < 0.1:
            filename = f"tëst_fïle_{i}.{ext}"
        elif random.random() < 0.1:
            filename = f"file with spaces {i}.{ext}"
        else:
            filename = f"file_{i:04d}.{ext}"

        filepath = subdir / filename
        GENERATORS[ext](str(filepath))

        if ext in ("jpg", "png", "gif") and random.random() < 0.5:
            add_exif_date(filepath, year, month)
        else:
            set_mtime(filepath, year, month)

        generated.append(filepath)

    # Duplicates
    dup_count = max(5, count // 10)
    for i in range(dup_count):
        if not generated:
            break
        source = random.choice(generated)
        if not source.exists():
            continue
        ext = source.suffix.lstrip(".")
        depth = random.randint(0, 3)
        subdir = root
        for d in range(depth):
            subdir = subdir / f"dup_dir_{d}"
        subdir.mkdir(parents=True, exist_ok=True)

        if random.random() < 0.3:
            dest = subdir / f"duplicate_{i}.{ext}"
        elif random.random() < 0.5:
            wrong_ext = random.choice(["txt", "bin", "dat"])
            dest = subdir / f"wrong_ext_{i}.{wrong_ext}"
        else:
            dest = subdir / f"no_ext_{i}"

        shutil.copy2(source, dest)
        generated.append(dest)

    # Edge cases
    for i in range(3):
        p = root / f"empty_{i}.txt"
        make_empty(p)
        generated.append(p)

    p = root / "README"
    make_text(str(p))
    generated.append(p)

    # tar.gz misnamed as .gz (issue #34)
    p = root / "misnamed_as_gz.gz"
    make_targz(str(p))
    generated.append(p)

    # Plain .gz named as .tar.gz (false positive)
    p = root / "plain_gz_as_targz.tar.gz"
    make_gz(str(p))
    generated.append(p)

    # Very long filename
    p = root / ("x" * 200 + ".txt")
    make_text(str(p))
    generated.append(p)

    # Special chars
    for name in ["file(1).txt", "file&special.txt", "file+plus.txt"]:
        p = root / name
        make_text(str(p))
        generated.append(p)

    # Identical content, different extensions
    shared_content = "name,age\nAlice,30\n"
    for ext in ["txt", "csv"]:
        p = root / f"shared_content.{ext}"
        with open(p, "w") as f:
            f.write(shared_content)
        generated.append(p)

    # 5 exact duplicate JPEGs
    img_source = root / "canonical.jpg"
    make_jpeg(str(img_source))
    for i in range(5):
        dest = root / "photos" / f"img_copy_{i}.jpg"
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(img_source, dest)
        generated.append(dest)

    total = sum(1 for _ in root.rglob("*") if _.is_file())
    print(f"Generated {total} files in {output_dir}")
    return total


def main():
    parser = argparse.ArgumentParser(description="Generate test data for organize_and_dedup.sh")
    parser.add_argument("output_dir", help="Directory to generate test files in")
    parser.add_argument("--count", type=int, default=50, help="Number of random files (default: 50)")
    parser.add_argument("--seed", type=int, default=None, help="Random seed for reproducibility")
    args = parser.parse_args()
    generate_test_data(args.output_dir, count=args.count, seed=args.seed)
    return 0


if __name__ == "__main__":
    sys.exit(main())