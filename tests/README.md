# Tests

Automated test suite for organize-dedup.

## Running Tests

```bash
# Run all tests
./run_tests.sh

# Run with verbose output
./run_tests.sh --verbose

# Run individual test
bash integration/test_hardlink.sh
```

## Test Structure

```
tests/
├── run_tests.sh           # Main test runner
├── integration/           # Integration tests
│   ├── test_basic_copy.sh
│   ├── test_hardlink.sh
│   ├── test_softlink.sh
│   ├── test_extension_correction.sh
│   ├── test_only_mismatched.sh
│   └── test_deduplication.sh
└── unit/                  # Unit tests (future)
```

## Test Coverage

- ✅ Basic copy operation
- ✅ Hardlink creation
- ✅ Softlink creation
- ✅ Extension correction
- ✅ Only mismatched extensions
- ✅ Deduplication

## Adding New Tests

1. Create test script in `integration/`
2. Make executable: `chmod +x test_name.sh`
3. Follow existing format
4. Run test suite to verify

## CI/CD

Tests run automatically on:
- Every push to main
- Every pull request
- Nightly builds

See `.github/workflows/test.yml`
