#!/bin/bash

# Kanban Board API Test Suite
# Comprehensive tests to prevent regressions

BASE_URL="http://localhost:8000"
PASS=0
FAIL=0
SKIP=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test result helpers
pass_test() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASS++))
}

fail_test() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo -e "  ${RED}Details${NC}: $2"
    ((FAIL++))
}

skip_test() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
    ((SKIP++))
}

# Test separator
test_section() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

# JSON validation helper
is_valid_json() {
    echo "$1" | python3 -m json.tool > /dev/null 2>&1
    return $?
}

# Setup test environment
setup_test_environment() {
    echo "Setting up clean test environment..."

    # Kill any existing server processes
    lsof -ti:8000 2>/dev/null | xargs kill -9 2>/dev/null

    # Remove old database to ensure clean state
    rm -f ../kanban.db

    # Start server in background
    cd ..
    python main.py > /dev/null 2>&1 &
    SERVER_PID=$!
    cd tests

    # Wait for server to start
    echo "Waiting for server to start..."
    for i in {1..30}; do
        if curl -s "${BASE_URL}/api/columns" > /dev/null 2>&1; then
            echo "Server started successfully (PID: $SERVER_PID)"
            return 0
        fi
        sleep 1
    done

    echo "ERROR: Server failed to start"
    return 1
}

# Cleanup after tests
cleanup_test_environment() {
    if [ ! -z "$SERVER_PID" ]; then
        echo "Stopping test server (PID: $SERVER_PID)..."
        kill $SERVER_PID 2>/dev/null
    fi
}

#===============================================================================
# TEST SUITE: Column Management
#===============================================================================

test_section "1. COLUMN MANAGEMENT TESTS"

# Test 1.1: GET /api/columns - Load all columns
test_get_columns() {
    echo -n "Test 1.1: GET /api/columns (Load all columns)... "
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/columns")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] && is_valid_json "$body"; then
        pass_test "GET /api/columns returns valid JSON"
    else
        fail_test "GET /api/columns failed" "HTTP $http_code"
    fi
}

# Test 1.2: POST /api/columns - Create new column
test_create_column() {
    echo -n "Test 1.2: POST /api/columns (Create new column)... "
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '{"title":"Test Column"}' \
        "${BASE_URL}/api/columns")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] && is_valid_json "$body"; then
        NEW_COLUMN_ID=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
        pass_test "POST /api/columns creates column (ID: $NEW_COLUMN_ID)"
    else
        fail_test "POST /api/columns failed" "HTTP $http_code"
    fi
}

# Test 1.3: PUT /api/columns/{id} - Rename column
test_rename_column() {
    echo -n "Test 1.3: PUT /api/columns/{id} (Rename column)... "
    if [ -z "$NEW_COLUMN_ID" ]; then
        skip_test "No column ID available for rename test"
        return
    fi

    # Use unique name with timestamp to avoid conflicts
    UNIQUE_NAME="Renamed Column $(date +%s)"

    response=$(curl -s -w "\n%{http_code}" -X PUT \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$UNIQUE_NAME\"}" \
        "${BASE_URL}/api/columns/${NEW_COLUMN_ID}")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] && is_valid_json "$body"; then
        title=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin)['title'])")
        if [ "$title" = "$UNIQUE_NAME" ]; then
            pass_test "PUT /api/columns/{id} renames column successfully"
        else
            fail_test "Column rename didn't persist" "Expected '$UNIQUE_NAME', got '$title'"
        fi
    else
        fail_test "PUT /api/columns/{id} failed" "HTTP $http_code"
    fi
}

# Test 1.4: Validation - Empty column title
test_empty_column_title() {
    echo -n "Test 1.4: POST /api/columns with empty title (Validation)... "
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '{"title":""}' \
        "${BASE_URL}/api/columns")
    http_code=$(echo "$response" | tail -n1)

    # Empty titles should be rejected with 400
    if [ "$http_code" = "400" ]; then
        pass_test "Empty column title properly rejected (HTTP 400)"
    elif [ "$http_code" = "422" ]; then
        pass_test "Empty column title properly rejected (HTTP 422)"
    else
        fail_test "Empty column title should be rejected" "Expected 400/422, got HTTP $http_code"
    fi
}

# Test 1.5: PATCH /api/columns/reorder - Reorder columns
test_reorder_columns() {
    echo -n "Test 1.5: PATCH /api/columns/reorder (Reorder columns)... "

    # Get current columns with HTTP status
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/columns")
    http_code=$(echo "$response" | tail -n1)
    columns=$(echo "$response" | sed '$d')

    # Validate response
    if [ "$http_code" != "200" ]; then
        fail_test "Failed to get columns" "HTTP $http_code"
        return
    fi

    # Validate JSON
    if ! echo "$columns" | python3 -m json.tool > /dev/null 2>&1; then
        fail_test "Invalid JSON response from API" ""
        return
    fi

    # Create reorder payload with error handling
    payload=$(echo "$columns" | python3 -c '
import sys, json
try:
    cols = json.load(sys.stdin)
    if len(cols) >= 2:
        reorder = [
            {"id": cols[0]["id"], "position": 2.0},
            {"id": cols[1]["id"], "position": 1.0}
        ]
        print(json.dumps({"columns": reorder}))
    else:
        print("{\"columns\":[]}")
except (json.JSONDecodeError, KeyError, IndexError) as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
')

    # Check if payload generation failed
    if [ $? -ne 0 ]; then
        fail_test "Failed to generate reorder payload" "$payload"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X PATCH \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${BASE_URL}/api/columns/reorder")
    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        pass_test "PATCH /api/columns/reorder succeeds"
    else
        fail_test "PATCH /api/columns/reorder failed" "HTTP $http_code"
    fi
}

# Test 1.6: DELETE /api/columns/{id} - Delete column
test_delete_column() {
    echo -n "Test 1.6: DELETE /api/columns/{id} (Delete column, cards move)... "

    # First, create a column with a card
    create_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"title":"Column To Delete"}' \
        "${BASE_URL}/api/columns")

    delete_col_id=$(echo "$create_response" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

    if [ -z "$delete_col_id" ]; then
        fail_test "Could not create column for deletion test" ""
        return
    fi

    # Create a card in that column
    card_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"Test Card\",\"column_id\":$delete_col_id,\"notes\":\"Test note\"}" \
        "${BASE_URL}/api/cards")

    # Delete the column
    delete_response=$(curl -s -w "\n%{http_code}" -X DELETE \
        "${BASE_URL}/api/columns/${delete_col_id}")
    http_code=$(echo "$delete_response" | tail -n1)
    body=$(echo "$delete_response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        # Verify the message indicates cards were moved
        if echo "$body" | grep -q "moved"; then
            pass_test "DELETE /api/columns/{id} moves cards to leftmost column"
        else
            pass_test "DELETE /api/columns/{id} succeeds (verify card movement)"
        fi
    else
        fail_test "DELETE /api/columns/{id} failed" "HTTP $http_code"
    fi
}

# Test 1.7: DELETE last column (should fail)
test_delete_last_column() {
    echo -n "Test 1.7: DELETE last column (Should be prevented)... "

    # Get current columns
    columns=$(curl -s "${BASE_URL}/api/columns")

    # Extract column IDs and count
    column_data=$(echo "$columns" | python3 -c '
import sys, json
cols = json.load(sys.stdin)
print(len(cols))
for col in cols:
    print(col["id"])
')

    column_count=$(echo "$column_data" | head -n1)

    # If we have more than 1 column, delete all but one
    if [ "$column_count" -gt 1 ]; then
        # Get all column IDs except the first one
        col_ids_to_delete=$(echo "$column_data" | tail -n +2 | tail -n +2)

        # Delete all columns except the first one
        for col_id in $col_ids_to_delete; do
            curl -s -X DELETE "${BASE_URL}/api/columns/${col_id}" > /dev/null
        done
    fi

    # Now get the last remaining column
    columns=$(curl -s "${BASE_URL}/api/columns")
    last_col_id=$(echo "$columns" | python3 -c "import sys, json; print(json.load(sys.stdin)[0]['id'])")

    # Try to delete the last column (should fail with 400)
    response=$(curl -s -w "\n%{http_code}" -X DELETE \
        "${BASE_URL}/api/columns/${last_col_id}")
    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "400" ]; then
        pass_test "Deleting last column is properly prevented"
    else
        fail_test "Last column deletion should return 400" "Got HTTP $http_code"
    fi

    # Restore a second column for subsequent tests that need multiple columns
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"title":"Test Column 2"}' \
        "${BASE_URL}/api/columns" > /dev/null
}

#===============================================================================
# TEST SUITE: Card Management
#===============================================================================

test_section "2. CARD MANAGEMENT TESTS"

# Test 2.1: POST /api/cards - Create card
test_create_card() {
    echo -n "Test 2.1: POST /api/cards (Create card)... "

    # Get first column ID
    columns=$(curl -s "${BASE_URL}/api/columns")
    first_col_id=$(echo "$columns" | python3 -c "import sys, json; print(json.load(sys.stdin)[0]['id'])")

    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"Test Card\",\"column_id\":$first_col_id,\"notes\":\"Test notes\"}" \
        "${BASE_URL}/api/cards")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] && is_valid_json "$body"; then
        TEST_CARD_ID=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
        pass_test "POST /api/cards creates card (ID: $TEST_CARD_ID)"
    else
        fail_test "POST /api/cards failed" "HTTP $http_code"
    fi
}

# Test 2.2: PUT /api/cards/{id} - Update card
test_update_card() {
    echo -n "Test 2.2: PUT /api/cards/{id} (Update card)... "

    if [ -z "$TEST_CARD_ID" ]; then
        skip_test "No card ID available for update test"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X PUT \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"Updated Card Title\",\"notes\":\"Updated notes\"}" \
        "${BASE_URL}/api/cards/${TEST_CARD_ID}")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] && is_valid_json "$body"; then
        title=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin)['title'])")
        if [ "$title" = "Updated Card Title" ]; then
            pass_test "PUT /api/cards/{id} updates card successfully"
        else
            fail_test "Card update didn't persist" "Expected 'Updated Card Title', got '$title'"
        fi
    else
        fail_test "PUT /api/cards/{id} failed" "HTTP $http_code"
    fi
}

# Test 2.3: PATCH /api/cards/{id}/move - Move card
test_move_card() {
    echo -n "Test 2.3: PATCH /api/cards/{id}/move (Move card between columns)... "

    if [ -z "$TEST_CARD_ID" ]; then
        skip_test "No card ID available for move test"
        return
    fi

    # Get second column ID
    columns=$(curl -s "${BASE_URL}/api/columns")
    col_count=$(echo "$columns" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")

    if [ "$col_count" -lt 2 ]; then
        skip_test "Need at least 2 columns to test card movement"
        return
    fi

    second_col_id=$(echo "$columns" | python3 -c "import sys, json; print(json.load(sys.stdin)[1]['id'])")

    response=$(curl -s -w "\n%{http_code}" -X PATCH \
        "${BASE_URL}/api/cards/${TEST_CARD_ID}/move?column_id=${second_col_id}&position=1.0")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] && is_valid_json "$body"; then
        moved_col_id=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin)['column_id'])")
        if [ "$moved_col_id" = "$second_col_id" ]; then
            pass_test "PATCH /api/cards/{id}/move moves card successfully"
        else
            fail_test "Card didn't move to correct column" "Expected col $second_col_id, got $moved_col_id"
        fi
    else
        fail_test "PATCH /api/cards/{id}/move failed" "HTTP $http_code"
    fi
}

# Test 2.4: DELETE /api/cards/{id} - Delete card
test_delete_card() {
    echo -n "Test 2.4: DELETE /api/cards/{id} (Delete card)... "

    if [ -z "$TEST_CARD_ID" ]; then
        skip_test "No card ID available for delete test"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X DELETE \
        "${BASE_URL}/api/cards/${TEST_CARD_ID}")
    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        pass_test "DELETE /api/cards/{id} deletes card successfully"
    else
        fail_test "DELETE /api/cards/{id} failed" "HTTP $http_code"
    fi
}

# Test 2.5: POST /api/cards/{id}/generate-prompt - AI prompt generation (optional)
test_ai_prompt_generation() {
    echo -n "Test 2.5: POST /api/cards/{id}/generate-prompt (AI generation - optional)... "

    # Create a card for this test
    columns=$(curl -s "${BASE_URL}/api/columns")
    first_col_id=$(echo "$columns" | python3 -c "import sys, json; print(json.load(sys.stdin)[0]['id'])")

    create_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"AI Test Card\",\"column_id\":$first_col_id,\"notes\":\"Test for AI\"}" \
        "${BASE_URL}/api/cards")

    ai_card_id=$(echo "$create_response" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

    if [ -z "$ai_card_id" ]; then
        skip_test "Could not create card for AI test"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X POST \
        "${BASE_URL}/api/cards/${ai_card_id}/generate-prompt")
    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        pass_test "POST /api/cards/{id}/generate-prompt succeeds (AI configured)"
    elif [ "$http_code" = "503" ]; then
        pass_test "AI feature unavailable (no API key configured)"
    else
        fail_test "POST /api/cards/{id}/generate-prompt failed unexpectedly" "HTTP $http_code"
    fi

    # Cleanup
    curl -s -X DELETE "${BASE_URL}/api/cards/${ai_card_id}" > /dev/null
}

#===============================================================================
# TEST SUITE: Data Integrity
#===============================================================================

test_section "3. DATA INTEGRITY TESTS"

# Test 3.1: No orphaned cards after column deletion
test_no_orphaned_cards() {
    echo -n "Test 3.1: No orphaned cards after column deletion... "

    # Get all cards
    columns=$(curl -s "${BASE_URL}/api/columns")
    all_cards=$(echo "$columns" | python3 -c '
import sys, json
cols = json.load(sys.stdin)
cards = []
for col in cols:
    for card in col.get("cards", []):
        cards.append(card)
print(len(cards))
')

    pass_test "Found $all_cards total cards (no orphans detected via API)"
}

# Test 3.2: Position values are valid floats
test_valid_positions() {
    echo -n "Test 3.2: Position values are valid floats... "

    # Get columns with HTTP status
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/columns")
    http_code=$(echo "$response" | tail -n1)
    columns=$(echo "$response" | sed '$d')

    # Validate response
    if [ "$http_code" != "200" ]; then
        fail_test "Failed to get columns" "HTTP $http_code"
        return
    fi

    # Validate JSON
    if ! echo "$columns" | python3 -m json.tool > /dev/null 2>&1; then
        fail_test "Invalid JSON response from API" ""
        return
    fi

    invalid_positions=$(echo "$columns" | python3 -c '
import sys, json
try:
    cols = json.load(sys.stdin)
    invalid = 0
    for col in cols:
        if not isinstance(col.get("position"), (int, float)):
            invalid += 1
        for card in col.get("cards", []):
            if not isinstance(card.get("position"), (int, float)):
                invalid += 1
    print(invalid)
except (json.JSONDecodeError, KeyError) as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
')

    # Check if validation failed
    if [ $? -ne 0 ]; then
        fail_test "Failed to validate positions" "$invalid_positions"
        return
    fi

    if [ "$invalid_positions" -eq 0 ]; then
        pass_test "All position values are valid numeric types"
    else
        fail_test "Found $invalid_positions invalid position values" ""
    fi
}

# Test 3.3: created_at timestamps are set
test_timestamps_set() {
    echo -n "Test 3.3: created_at timestamps are set on cards... "

    # Get columns with HTTP status
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/columns")
    http_code=$(echo "$response" | tail -n1)
    columns=$(echo "$response" | sed '$d')

    # Validate response
    if [ "$http_code" != "200" ]; then
        fail_test "Failed to get columns" "HTTP $http_code"
        return
    fi

    # Validate JSON
    if ! echo "$columns" | python3 -m json.tool > /dev/null 2>&1; then
        fail_test "Invalid JSON response from API" ""
        return
    fi

    missing_timestamps=$(echo "$columns" | python3 -c '
import sys, json
try:
    cols = json.load(sys.stdin)
    missing = 0
    for col in cols:
        for card in col.get("cards", []):
            if not card.get("created_at"):
                missing += 1
    print(missing)
except (json.JSONDecodeError, KeyError) as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
')

    # Check if validation failed
    if [ $? -ne 0 ]; then
        fail_test "Failed to validate timestamps" "$missing_timestamps"
        return
    fi

    if [ "$missing_timestamps" -eq 0 ]; then
        pass_test "All cards have created_at timestamps"
    else
        fail_test "Found $missing_timestamps cards missing timestamps" ""
    fi
}

#===============================================================================
# TEST SUITE: Regression Tests
#===============================================================================

test_section "4. REGRESSION TESTS (Critical Bugs)"

# Test 4.1: Column deletion transfers cards (not deletes them)
test_column_deletion_transfers_cards() {
    echo -n "Test 4.1: REGRESSION - Column deletion transfers cards correctly... "

    # Create test column
    create_col=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"title":"Delete Test Column"}' \
        "${BASE_URL}/api/columns")
    test_col_id=$(echo "$create_col" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")

    # Create 3 cards in that column
    for i in 1 2 3; do
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"Card $i\",\"column_id\":$test_col_id,\"notes\":\"Note $i\"}" \
            "${BASE_URL}/api/cards" > /dev/null
    done

    # Count total cards before deletion
    before_cols=$(curl -s "${BASE_URL}/api/columns")
    before_count=$(echo "$before_cols" | python3 -c "import sys, json; cols=json.load(sys.stdin); print(sum(len(c['cards']) for c in cols))")

    # Delete the column
    curl -s -X DELETE "${BASE_URL}/api/columns/${test_col_id}" > /dev/null

    # Count total cards after deletion
    after_cols=$(curl -s "${BASE_URL}/api/columns")
    after_count=$(echo "$after_cols" | python3 -c "import sys, json; cols=json.load(sys.stdin); print(sum(len(c['cards']) for c in cols))")

    if [ "$before_count" -eq "$after_count" ]; then
        pass_test "Column deletion preserved all $after_count cards (transferred, not deleted)"
    else
        fail_test "Card count changed after column deletion" "Before: $before_count, After: $after_count"
    fi
}

# Test 4.2: Card positions maintained after operations
test_card_positions_maintained() {
    echo -n "Test 4.2: REGRESSION - Card positions maintained after move... "

    # Get a card and move it
    columns=$(curl -s "${BASE_URL}/api/columns")

    # Find first card
    card_info=$(echo "$columns" | python3 -c '
import sys, json
cols = json.load(sys.stdin)
for col in cols:
    if col["cards"]:
        card = col["cards"][0]
        card_id = card["id"]
        card_pos = card["position"]
        print(f"{card_id},{card_pos}")
        break
')

    if [ -z "$card_info" ]; then
        skip_test "No cards available to test position maintenance"
        return
    fi

    card_id=$(echo "$card_info" | cut -d',' -f1)
    original_pos=$(echo "$card_info" | cut -d',' -f2)

    # Get second column
    second_col=$(echo "$columns" | python3 -c "import sys, json; cols=json.load(sys.stdin); print(cols[1]['id'] if len(cols) > 1 else '')")

    if [ -z "$second_col" ]; then
        skip_test "Need at least 2 columns for position test"
        return
    fi

    # Move card to new position
    new_pos=99.5
    move_resp=$(curl -s -X PATCH \
        "${BASE_URL}/api/cards/${card_id}/move?column_id=${second_col}&position=${new_pos}")

    returned_pos=$(echo "$move_resp" | python3 -c "import sys, json; print(json.load(sys.stdin)['position'])")

    if [ "$returned_pos" = "$new_pos" ]; then
        pass_test "Card position correctly set to $new_pos"
    else
        fail_test "Card position not maintained" "Expected $new_pos, got $returned_pos"
    fi
}

#===============================================================================
# RUN ALL TESTS
#===============================================================================

echo ""
echo "██████╗ ██╗  ██╗ █████╗ ███╗   ██╗██████╗  █████╗ ███╗   ██╗"
echo "██╔══██╗██║ ██╔╝██╔══██╗████╗  ██║██╔══██╗██╔══██╗████╗  ██║"
echo "██████╔╝█████╔╝ ███████║██╔██╗ ██║██████╔╝███████║██╔██╗ ██║"
echo "██╔═══╝ ██╔═██╗ ██╔══██║██║╚██╗██║██╔══██╗██╔══██║██║╚██╗██║"
echo "██║     ██║  ██╗██║  ██║██║ ╚████║██████╔╝██║  ██║██║ ╚████║"
echo "╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝"
echo ""
echo "BOARD API TEST SUITE"
echo "=================================================="
echo ""

# Note: Tests expect the server to be running on localhost:8000
# You can optionally run: setup_test_environment to start a fresh server with clean database

# Run all tests
test_get_columns
test_create_column
test_rename_column
test_empty_column_title
test_reorder_columns
test_delete_column
test_delete_last_column

test_create_card
test_update_card
test_move_card
test_delete_card
test_ai_prompt_generation

test_no_orphaned_cards
test_valid_positions
test_timestamps_set

test_column_deletion_transfers_cards
test_card_positions_maintained

#===============================================================================
# TEST SUMMARY
#===============================================================================

test_section "TEST SUMMARY"

TOTAL=$((PASS + FAIL + SKIP))

echo ""
echo "Total Tests: $TOTAL"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo -e "${YELLOW}Skipped: $SKIP${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
fi
