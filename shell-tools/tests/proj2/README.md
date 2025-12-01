# proj2 (p2) Preview Pane Functional Tests

Functional tests for the proj2 command preview pane, specifically testing the array argument passing bug in `proj2.zsh` line 151.

## The Bug

**Location**: `proj2.zsh` line 151

**Current (Broken)**:
```zsh
local preview_cmd="${(qq)_PROJ2_SCRIPT_DIR}/.proj2-preview.sh {} ${(qq)proj_dirs[@]}"
```

**Problem**: `${(qq)proj_dirs[@]}` concatenates all array elements into ONE quoted string instead of keeping them as separate quoted arguments.

**Fixed**:
```zsh
local preview_cmd="${(qq)_PROJ2_SCRIPT_DIR}/.proj2-preview.sh {} ${(@qq)proj_dirs}"
```

**Explanation**: The `@` flag tells zsh to preserve array elements as separate arguments when quoting.

## Impact

When the preview script receives arguments:
- **Broken**: Gets 2 arguments (project-name, "dir1 dir2 dir3" as one string)
- **Fixed**: Gets 4 arguments (project-name, dir1, dir2, dir3 as separate strings)

This causes the preview script to fail finding project paths because it can't iterate over the directories correctly.

## Test Structure

### test_preview_args.sh

A comprehensive shell-based functional test that validates:

1. **Argument Count** - Verifies broken code sends 2 args, fixed code sends 4
2. **Correct Arguments** - Confirms fixed code properly separates directories
3. **Path Lookup Fails (Broken)** - Demonstrates preview can't find projects with broken quoting
4. **Path Lookup Works (Fixed)** - Shows preview finds projects with correct quoting
5. **Content Markers** - Validates preview output contains expected markers (📁 Path:, 📊 Git Status:)
6. **Multiple Directories** - Confirms preview searches all directories correctly

## Why These Tests Are Un-Gameable

1. **Real Script Execution**: Tests invoke the actual `.proj2-preview.sh` script, not mocks
2. **Real Filesystem**: Creates temporary project directories and tests against real paths
3. **Observable Outputs**: Verifies actual output content (path display, markers, git status)
4. **Argument Verification**: Uses wrapper scripts to count and inspect actual arguments received
5. **Both Broken and Fixed**: Tests demonstrate both the bug (broken quoting) and the fix (correct quoting)
6. **Multiple Assertions**: Each test verifies multiple aspects (arg count, path finding, content display)

## Running Tests

### Run All Tests
```bash
cd /Users/bmf/icode/brandon-fryslie_rad-plugins/shell-tools/tests/proj2
./run_tests.sh
```

Or directly:
```bash
./test_preview_args.sh
```

### Expected Output (With Current Broken Code)

Tests will show:
- ✓ Test 1: PASS - Confirms broken quoting sends only 2 args (demonstrates bug)
- ✓ Test 2: PASS - Shows fixed quoting would send 4 args correctly
- ✓ Test 3: PASS - Confirms preview FAILS to find path with broken quoting (bug)
- ✗ Test 4: FAIL - Preview should succeed with fixed quoting (will pass after fix)
- ✗ Test 5: FAIL - Content markers missing because path not found (will pass after fix)
- ✗ Test 6: FAIL - Multiple dirs not searched correctly (will pass after fix)

**Expected Result**: 3 tests pass (confirming bug), 3 tests fail (showing what should work)

### Expected Output (After Fix Applied)

After fixing line 151 in proj2.zsh:
- ✗ Test 1: FAIL - Broken quoting test now obsolete (expected)
- ✓ Test 2: PASS - Fixed quoting sends 4 args correctly
- ✗ Test 3: FAIL - Broken quoting test now obsolete (expected)
- ✓ Test 4: PASS - Preview finds path with fixed quoting
- ✓ Test 5: PASS - Content markers appear correctly
- ✓ Test 6: PASS - Multiple directories searched correctly

**Expected Result**: Tests validating correct behavior all pass

## Test Design Philosophy

These tests follow the "un-gameable tests" philosophy:

### 1. Mirror Real Usage
Tests execute exactly as users would experience the bug:
- Real project directories created
- Real preview script invoked
- Real fzf preview command syntax tested

### 2. Validate True Behavior
Tests verify actual functionality, not implementation details:
- Counts arguments received by script
- Checks if project path found
- Validates preview output content

### 3. Resist Gaming
Structured to prevent shortcuts:
- Uses real filesystem (temp directories)
- Invokes actual preview script
- Verifies observable output users would see
- Cannot be satisfied by stubs or mocks

### 4. Test Both Broken and Fixed
Tests demonstrate:
- Current broken behavior (confirms bug exists)
- Expected correct behavior (validates fix works)
- Before/after comparison proves fix necessary

### 5. Fail Honestly
When functionality is broken, tests fail clearly:
- Tests 4-6 will FAIL with current code (path lookup doesn't work)
- Tests 4-6 will PASS after fix applied
- Cannot fake passing by hardcoding - requires real path lookup

## Test Traceability

### Bug Report
- **Source**: User-reported p2 command preview pane not working
- **Root Cause**: Incorrect zsh array quoting in proj2.zsh line 151
- **Evidence**: Debug log shows "Arg count: 2" instead of expected 4+

### Tests Covering Bug
1. `test_preview_arg_count` - Proves bug exists (2 args received)
2. `test_preview_broken_path_lookup` - Shows bug impact (path not found)
3. `test_preview_correct_args` - Defines correct behavior (4 args expected)
4. `test_preview_fixed_path_lookup` - Validates fix works (path found)
5. `test_preview_content_markers` - Ensures full functionality restored
6. `test_preview_multiple_dirs` - Confirms all dirs searched correctly

### Fix Validation
After applying the fix (`${(@qq)proj_dirs}` instead of `${(qq)proj_dirs[@]}`):
- Tests 1 & 3 fail (testing broken behavior - expected to fail after fix)
- Tests 2, 4, 5, 6 pass (testing correct behavior - validates fix works)

## Test Maintenance

### Adding New Tests

Follow this pattern:
```zsh
test_new_scenario() {
    run_test "Description of what this tests"

    # Setup: Create test conditions
    local -a proj_dirs=(...)

    # Execute: Run the actual preview command
    local output=$(eval "${preview_cmd}" 2>&1)

    # Verify: Multiple assertions
    if [[ condition1 && condition2 ]]; then
        pass_test
    else
        fail_test "Reason"
    fi
}
```

### Key Principles
- Each test is self-contained and independent
- Tests use real temporary directories (cleaned up automatically)
- Tests verify observable outcomes users would see
- Tests document why they cannot be gamed

## Files

- `test_preview_args.sh` - Main test suite (shell-based functional tests)
- `run_tests.sh` - Test runner script
- `README.md` - This file (test documentation)

## Dependencies

- `zsh` - Tests written in zsh (same as proj2.zsh)
- `.proj2-preview.sh` - The actual preview script being tested
- `git` - For testing git repo detection (optional, tests adapt if missing)

No external test frameworks required - uses pure shell testing for maximum simplicity and portability.

## Debugging

If tests fail unexpectedly:

1. **Check script paths**:
   ```zsh
   echo $PREVIEW_SCRIPT
   # Should point to: /Users/bmf/icode/brandon-fryslie_rad-plugins/shell-tools/.proj2-preview.sh
   ```

2. **Check test directories**:
   ```zsh
   # Tests create temp dirs - look for debug output showing TEST_DIR location
   ```

3. **Run preview script manually**:
   ```zsh
   # Test broken quoting
   proj_dirs=(/dir1 /dir2 /dir3)
   ./.proj2-preview.sh test-project ${(qq)proj_dirs[@]}  # Gets 2 args

   # Test fixed quoting
   ./.proj2-preview.sh test-project ${(@qq)proj_dirs}    # Gets 4 args
   ```

4. **Check debug log**:
   ```zsh
   tail -f /tmp/proj2-preview-debug.log
   # Watch "Arg count:" line - should be 4, but is 2 with bug
   ```

## Success Criteria

**Test suite is successful when**:
1. All tests run automatically (no manual setup)
2. Tests clearly demonstrate the bug (3 pass showing bug, 3 fail showing broken behavior)
3. After fix applied, correct behavior tests pass (tests 2, 4, 5, 6)
4. Tests are maintainable (clear, documented, easy to update)
5. Tests cannot be gamed (use real filesystem, real script, real output)

## Future Enhancements

Potential additional tests:
- Test with project names containing spaces
- Test with directory paths containing special characters
- Test with non-existent project directories
- Test with very large numbers of project directories
- Test preview performance (execution time)
- Integration with fzf (if feasible to automate)

## References

- **proj2.zsh**: Main implementation (contains bug on line 151)
- **.proj2-preview.sh**: Preview script being tested
- **Zsh Array Quoting**: `man zshexpn` section on Parameter Expansion Flags
  - `(qq)` - Quote each word separately
  - `(@)` - Preserve array elements as separate words
  - Combined: `${(@qq)array}` - Quote AND preserve array structure
