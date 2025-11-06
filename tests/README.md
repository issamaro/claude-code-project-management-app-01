# Kanban API Test Suite

Comprehensive automated testing suite for the Project Management Kanban Board application.

## Overview

This test suite validates all API endpoints, data integrity, and prevents regression issues. It includes 17 automated tests covering column management, card management, data integrity, and specific regression tests.

**Important**: Tests now use a separate test database (`kanban.test.db`) so your production data in `kanban.db` is never affected during testing.

## Prerequisites

- **Server Running**: The FastAPI application must be running on `http://localhost:8000`
- **curl**: Command-line tool for HTTP requests (pre-installed on macOS/Linux)
- **jq**: JSON processor for validation (install with `brew install jq` on macOS)
- **bash**: Unix shell (pre-installed on macOS/Linux)

## Quick Start

```bash
# 1. Start the application server (from project root)
python main.py

# 2. In a new terminal, run the test suite
cd tests
chmod +x test_kanban_api.sh
./test_kanban_api.sh
```

## Test Categories

### 1. Column Management Tests (7 tests)

- **Test 1.1**: GET /api/columns - Load all columns
- **Test 1.2**: POST /api/columns - Create new column
- **Test 1.3**: PUT /api/columns/{id} - Rename column
- **Test 1.4**: PUT /api/columns/{id} - Reject empty title (validation)
- **Test 1.5**: PATCH /api/columns/reorder - Reorder columns
- **Test 1.6**: DELETE /api/columns/{id} - Delete column
- **Test 1.7**: DELETE last column - Prevent deletion (validation)

### 2. Card Management Tests (5 tests)

- **Test 2.1**: POST /api/cards - Create new card
- **Test 2.2**: PUT /api/cards/{id} - Update card title and notes
- **Test 2.3**: PATCH /api/cards/{id}/move - Move card between columns
- **Test 2.4**: DELETE /api/cards/{id} - Delete card
- **Test 2.5**: POST /api/cards/{id}/generate-prompt - AI prompt generation

### 3. Data Integrity Tests (3 tests)

- **Test 3.1**: Verify no orphaned cards (all cards belong to valid columns)
- **Test 3.2**: Verify position values are valid (non-negative floats)
- **Test 3.3**: Verify timestamps are set on all cards

### 4. Regression Tests (2 tests)

- **Test 4.1**: Column deletion transfers cards (doesn't delete them)
  - Tests the fix for the bug where deleting a column was removing cards
  - Verifies cards are moved to the leftmost column instead
- **Test 4.2**: Card positions maintained after move
  - Ensures position values are preserved correctly during drag-and-drop

## Understanding Test Output

The test suite uses colored output for easy visual parsing:

- **✓ PASS** (Green): Test passed successfully
- **✗ FAIL** (Red): Test failed with error details
- **⊘ SKIP** (Yellow): Test skipped (e.g., AI tests when API key not set)

### Example Output

```
========================================
Kanban API Test Suite
========================================
Base URL: http://localhost:8000
Starting tests...

----------------------------------------
1. Column Management Tests
----------------------------------------
✓ PASS: GET /api/columns returns valid JSON
✓ PASS: POST /api/columns creates new column
✓ PASS: PUT /api/columns/{id} renames column
✓ PASS: Empty column title rejected (HTTP 400)
✓ PASS: PATCH /api/columns/reorder updates order
✓ PASS: DELETE /api/columns/{id} removes column
✓ PASS: Cannot delete last column (HTTP 400)

========================================
Test Summary
========================================
Total Tests: 17
Passed: 16
Failed: 0
Skipped: 1

✓ All tests passed!
```

## Exit Codes

- **0**: All tests passed
- **1**: One or more tests failed

Use exit codes in CI/CD pipelines:
```bash
./test_kanban_api.sh
if [ $? -eq 0 ]; then
    echo "Tests passed, proceeding with deployment"
else
    echo "Tests failed, blocking deployment"
    exit 1
fi
```

## Test Data Management

### Separate Test Database

The test suite uses a **separate test database** (`kanban.test.db`) that is completely independent from your production database (`kanban.db`). This means:

- ✅ Your real cards and columns are NEVER affected by tests
- ✅ Tests can run without worrying about data loss
- ✅ You can inspect test data without affecting production

The test script automatically:
1. Sets `DATABASE_URL=sqlite:///./kanban.test.db` environment variable
2. Deletes the old test database before each run
3. Creates a fresh test database with default columns
4. Runs all tests against the test database

### Test Data Created

The test suite creates temporary test data:
- Columns named "Test Column [timestamp]"
- Cards named "Test Card [timestamp]"

**Note**: Tests do NOT clean up test data automatically. This allows inspection after test runs. To clean up the test database:

```bash
# Delete the test database (from project root)
rm kanban.test.db

# Your production database (kanban.db) remains untouched
```

### Manual Testing with Test Database

If you want to manually test with the test database without affecting production:

```bash
# Set environment variable and start server
export DATABASE_URL="sqlite:///./kanban.test.db"
python main.py

# In another terminal, interact with the test database
# When done, restart without the environment variable to use production database
```

## Troubleshooting

### Server Not Running
```
Error: Failed to connect to http://localhost:8000
```
**Solution**: Start the server first with `python main.py`

### jq Not Installed
```
Error: jq: command not found
```
**Solution**: Install jq with `brew install jq` (macOS) or `apt-get install jq` (Linux)

### Port Already in Use
```
Error: Address already in use
```
**Solution**: Kill existing processes on port 8000:
```bash
lsof -ti:8000 | xargs kill -9
```

### AI Tests Skipped
```
⊘ SKIP: POST /api/cards/{id}/generate-prompt - AI not available
```
**Solution**: Set `ANTHROPIC_API_KEY` in `.env` file to enable AI features

## Adding New Tests

To add a new test to the suite:

1. **Add Test Function**:
```bash
test_my_new_feature() {
    echo -n "Test X.X: Description... "

    # Make API request
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/your-endpoint")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    # Validate response
    if [ "$http_code" = "200" ] && is_valid_json "$body"; then
        pass_test "Test passed"
    else
        fail_test "Test failed" "HTTP $http_code"
    fi
}
```

2. **Call Test Function** in appropriate section:
```bash
echo "----------------------------------------"
echo "X. My New Feature Tests"
echo "----------------------------------------"
test_my_new_feature
```

3. **Update This Documentation** with test description

## Coverage Areas

### API Endpoints Tested
- ✅ GET /api/columns
- ✅ POST /api/columns
- ✅ PUT /api/columns/{id}
- ✅ DELETE /api/columns/{id}
- ✅ PATCH /api/columns/reorder
- ✅ POST /api/cards
- ✅ PUT /api/cards/{id}
- ✅ PATCH /api/cards/{id}/move
- ✅ DELETE /api/cards/{id}
- ✅ POST /api/cards/{id}/generate-prompt

### Validation Tested
- ✅ Empty column titles rejected (400)
- ✅ Last column cannot be deleted (400)
- ✅ Invalid column IDs return 404
- ✅ JSON response structure validated
- ✅ HTTP status codes verified

### Data Integrity Tested
- ✅ No orphaned cards after operations
- ✅ Position values are valid floats
- ✅ Timestamps are set correctly
- ✅ Foreign key relationships maintained

### Regression Coverage
- ✅ Column deletion transfers cards (fix for delete-orphan bug)
- ✅ Card positions maintained during moves
- ✅ Column order persistence

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Test Kanban API

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          sudo apt-get install -y jq

      - name: Start server in background
        run: |
          python main.py &
          sleep 5

      - name: Run tests
        run: |
          cd tests
          chmod +x test_kanban_api.sh
          ./test_kanban_api.sh
```

## Best Practices

1. **Run tests before commits**: Catch issues early
2. **Run tests after pulling changes**: Verify compatibility
3. **Add regression tests**: When fixing bugs, add tests to prevent recurrence
4. **Keep test data clean**: Periodically reset the test database
5. **Monitor test execution time**: Slow tests may indicate performance issues

## Future Enhancements

Planned test improvements:
- [ ] Automated test data cleanup
- [ ] Performance benchmarking tests
- [ ] Concurrent operation tests
- [ ] Browser automation tests (Selenium/Playwright)
- [ ] Load testing with multiple concurrent users
- [ ] Database migration tests

## Support

For issues or questions about the test suite:
1. Check troubleshooting section above
2. Verify server is running on correct port
3. Review test output for specific error messages
4. Check that all prerequisites are installed
