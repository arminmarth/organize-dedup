#!/bin/bash
# Test runner for organize-dedup
# Runs all test suites and reports results

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT="$REPO_DIR/organize_and_dedup.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test result tracking
declare -a FAILED_TEST_NAMES

echo "=========================================="
echo "organize-dedup Test Suite"
echo "=========================================="
echo ""

# Function to run a test
run_test() {
    local test_name="$1"
    local test_script="$2"
    
    echo -n "Running: $test_name ... "
    ((TOTAL_TESTS++))
    
    if bash "$test_script" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED_TESTS++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED_TESTS++))
        FAILED_TEST_NAMES+=("$test_name")
        return 1
    fi
}

# Function to run test with output
run_test_verbose() {
    local test_name="$1"
    local test_script="$2"
    
    echo "=========================================="
    echo "Test: $test_name"
    echo "=========================================="
    ((TOTAL_TESTS++))
    
    if bash "$test_script"; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED_TESTS++))
        echo ""
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED_TESTS++))
        FAILED_TEST_NAMES+=("$test_name")
        echo ""
        return 1
    fi
}

# Check if script exists
if [[ ! -f "$SCRIPT" ]]; then
    echo -e "${RED}Error: Script not found at $SCRIPT${NC}"
    exit 1
fi

# Check if verbose mode
VERBOSE=false
if [[ "$1" == "-v" ]] || [[ "$1" == "--verbose" ]]; then
    VERBOSE=true
fi

echo "Script: $SCRIPT"
echo "Test directory: $SCRIPT_DIR"
echo ""

# Run unit tests
if [[ -d "$SCRIPT_DIR/unit" ]]; then
    echo "=========================================="
    echo "Unit Tests"
    echo "=========================================="
    for test_file in "$SCRIPT_DIR/unit"/*.sh; do
        if [[ -f "$test_file" ]]; then
            test_name=$(basename "$test_file" .sh)
            if [[ "$VERBOSE" == true ]]; then
                run_test_verbose "$test_name" "$test_file"
            else
                run_test "$test_name" "$test_file"
            fi
        fi
    done
    echo ""
fi

# Run integration tests
if [[ -d "$SCRIPT_DIR/integration" ]]; then
    echo "=========================================="
    echo "Integration Tests"
    echo "=========================================="
    for test_file in "$SCRIPT_DIR/integration"/*.sh; do
        if [[ -f "$test_file" ]]; then
            test_name=$(basename "$test_file" .sh)
            if [[ "$VERBOSE" == true ]]; then
                run_test_verbose "$test_name" "$test_file"
            else
                run_test "$test_name" "$test_file"
            fi
        fi
    done
    echo ""
fi

# Print summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [[ $FAILED_TESTS -gt 0 ]]; then
    echo ""
    echo "Failed tests:"
    for test_name in "${FAILED_TEST_NAMES[@]}"; do
        echo -e "  ${RED}✗${NC} $test_name"
    done
fi

echo ""

# Exit with appropriate code
if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
