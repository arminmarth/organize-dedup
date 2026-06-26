# Contributing

Thanks for contributing!

## Development

1. Fork the repository and create a feature branch.
2. Make focused changes with clear commit messages.
3. Run the test suite: `bats tests/`
4. Open a pull request describing what changed and why.

## Pull Requests

- Keep PRs focused — one logical change per PR
- Include testing notes
- Link related issues where possible
- Update tests for any behavioural change

## Testing

The project uses [bats](https://github.com/bats-core/bats-core) for bash testing.

### Running tests

```bash
# Install bats (Debian/Ubuntu)
sudo apt-get install -y bats

# Install exiftool (optional, enables EXIF-related tests)
sudo apt-get install -y libimage-exiftool-perl

# Run the full test suite
bats tests/
```

### Test structure

- `tests/organize_and_dedup.bats` — main test suite (68 tests)
- `tests/generate_test_data.py` — generates realistic test files with valid MIME headers
- `tests/test_helper.bash` — shared helper functions

### Writing new tests

1. Add a `@test "description" { ... }` block to `tests/organize_and_dedup.bats`
2. Use `setup` and `teardown` for temp directories (already defined)
3. For new file types, add a generator function to `generate_test_data.py`
4. Tests that document known bugs should assert the current (buggy) behaviour
   and include a comment explaining the issue number

### Test data generator

```bash
# Generate 80 files with a fixed seed (reproducible)
python3 tests/generate_test_data.py /tmp/test_input --count 80 --seed 42

# Generate with a different seed
python3 tests/generate_test_data.py /tmp/test_input --count 200 --seed 99
```

The generator creates files with valid magic bytes so `file --mime-type`
detects them correctly. It covers 21 file types, duplicates, wrong extensions,
Unicode filenames, empty files, tar.gz edge cases, and more.

## CI

GitHub Actions runs the bats test suite on every push and PR. The workflow is
defined in `.github/workflows/ci.yml`.

## Code style

- Bash 4.0+ compatible (use associative arrays, `${var,,}` etc.)
- No external dependencies beyond coreutils + optional exiftool
- Use `set -uo pipefail`
- Quote all variable expansions: `"$var"` not `$var`
- Use `--` before paths in commands: `mkdir -p -- "$dir"`