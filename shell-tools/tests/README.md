# Tmux Automated Test Suite

Comprehensive automated testing for tmux keybindings and workflows using Python + pexpect.

## Overview

This test suite verifies that tmux keybindings **actually work** by:
- Spawning **real tmux processes** (not mocks)
- Sending **actual keystroke bytes** (Ctrl-b h = `\x02h`)
- Verifying **observable outcomes** (pane counts, content, status bars)
- Testing **complete user workflows** end-to-end

**These tests cannot be gamed.** They fail if the actual functionality is broken.

## Installation

```bash
# Create virtual environment
uv venv

# Install test dependencies
source .venv/bin/activate
uv pip install -r requirements-test.txt
```

## Running Tests

```bash
# Activate virtual environment (if not already active)
source .venv/bin/activate

# Run all tests
pytest

# Run only keybinding tests
pytest -m keybinding

# Run only fast tests (skip slow E2E tests)
pytest -m "not slow"

# Run specific test file
pytest tests/keybindings/test_help_keybinding.py

# Run with verbose output
pytest -v

# Run specific test
pytest tests/keybindings/test_help_keybinding.py::test_ctrl_b_h_creates_help_pane
```

## Test Structure

```
tests/
├── conftest.py                 # Pytest fixtures and configuration
├── framework/
│   ├── tmux_session.py        # TmuxSession class for real tmux control
│   └── assertions.py          # Custom assertions (future)
├── keybindings/
│   └── test_help_keybinding.py # Ctrl-b h keybinding tests (P0)
├── e2e/
│   └── test_tmux_test_workflow.py # End-to-end workflow tests (P0)
└── README.md                   # This file
```

## Test Categories

### Keybinding Tests (`@pytest.mark.keybinding`)
Test individual tmux keybindings by sending real keystrokes:
- `test_ctrl_b_h_creates_help_pane` - Ctrl-b h shows help
- `test_ctrl_b_h_toggles_help_pane_off` - Ctrl-b h hides help
- `test_ctrl_b_h_help_pane_correct_height` - Help pane is 5 lines
- `test_ctrl_b_h_help_pane_shows_content` - Help shows shortcuts

### End-to-End Tests (`@pytest.mark.e2e`, `@pytest.mark.slow`)
Test complete user workflows from start to finish:
- `test_help_pane_works_in_tmux_test_session` - Help works in 2-pane layout
- `test_help_pane_survives_pane_switching` - Help persists across pane switches
- `test_complete_user_workflow` - Full workflow: start → work → help → finish

## How It Works

### TmuxSession Class

The `TmuxSession` class provides a clean API for testing:

```python
from tests.framework.tmux_session import TmuxSession

def test_example(tmux_session):
    # Send Ctrl-b h
    tmux_session.send_prefix_key('h')

    # Verify pane count
    assert tmux_session.get_pane_count() == 2

    # Verify content
    content = tmux_session.get_pane_content()
    assert "PANES" in content
```

### Key Methods

- `send_prefix_key(key)` - Send Ctrl-b + key as real bytes
- `get_pane_count()` - Get number of panes via tmux list-panes
- `get_pane_content(pane_id)` - Capture real terminal output
- `get_pane_height(pane_id)` - Get pane height in lines
- `get_status_bar()` - Capture status bar text
- `verify_text_appears(text, timeout)` - Wait for text to appear

### Fixtures

The `conftest.py` provides reusable fixtures:

- `tmux_session` - Clean tmux session with user config (~/.tmux.conf)
- `tmux_session_minimal` - Clean tmux session with no config

Each fixture:
- Creates isolated session with unique name
- Uses pytest's automatic cleanup (even if test fails)
- Ensures no interference between tests

## Why These Tests Are Un-Gameable

### 1. Real Processes
Tests spawn **actual tmux processes** using pexpect. No mocks can fake this.

```python
# This creates a REAL tmux session
session = TmuxSession()
```

### 2. Real Keystrokes
Tests send **literal bytes** to tmux. The keybinding MUST work.

```python
# Sends actual Ctrl-b h bytes (\x02h) to tmux process
session.send_prefix_key('h')
```

### 3. Observable Outcomes
Tests verify **externally observable results** using tmux commands:

```python
# Uses 'tmux list-panes' - cannot be faked
pane_count = session.get_pane_count()

# Uses 'tmux capture-pane' - reads actual terminal output
content = session.get_pane_content()
```

### 4. Multiple Assertions
Each test verifies multiple aspects to prevent partial implementations:

```python
# Not just "pane created" - also check height, content, state
assert session.get_pane_count() == 2
assert session.get_pane_height(help_pane) == 5
assert "PANES" in session.get_pane_content(help_pane)
assert session.get_global_option("@help_pane_id") != ""
```

### 5. State Verification
Tests verify state changes persist correctly:

```python
# Verify toggle OFF clears state
session.send_prefix_key('h')  # Toggle off
assert session.get_global_option("@help_pane_id") == ""
```

## Test Coverage

Current test coverage (Sprint 1 - P0 complete):

| Category | Tests Written | Status |
|----------|--------------|--------|
| Keybinding tests (Ctrl-b h) | 8 | ✅ Complete |
| E2E workflow tests | 5 | ✅ Complete |
| **TOTAL** | **13** | ✅ P0 Complete |

### Future Test Coverage (Sprint 2+)

| Category | Tests Planned | Priority |
|----------|--------------|----------|
| All keybindings (20+) | 20+ | P1 |
| Status bar verification | 6 | P1 |
| Integration tests | 5 | P1 |
| Persistence tests | 4 | P1 |
| Edge cases | 11 | P2 |
| Performance tests | 7 | P2 |

## Adding New Tests

### Adding a Keybinding Test

```python
import pytest

@pytest.mark.keybinding
def test_ctrl_b_o_switches_panes(tmux_session):
    """Test Ctrl-b o switches to next pane."""
    # Create 2 panes
    tmux_session.send_keys("tmux split-window -h", literal=False)
    tmux_session.send_keys("Enter", literal=False)
    time.sleep(0.2)

    # Send Ctrl-b o
    tmux_session.send_prefix_key('o')

    # Verify pane switched (check active pane)
    # ... add assertions ...
```

### Adding an E2E Test

```python
import pytest

@pytest.mark.e2e
@pytest.mark.slow
def test_my_workflow(tmux_session):
    """Test a complete user workflow."""
    # Setup
    # ... create initial state ...

    # Execute workflow
    # ... perform user actions ...

    # Verify outcomes
    # ... check multiple observable results ...
```

## Troubleshooting

### Tests Fail with "tmux: command not found"
Install tmux: `brew install tmux`

### Tests Hang or Timeout
- Check if tmux sessions are orphaned: `tmux ls`
- Kill old test sessions: `tmux kill-session -t pytest-tmux-*`
- Increase timeout in pytest.ini

### Tests Pass Locally but Fail in CI
- Ensure tmux is installed in CI environment
- Use explicit terminal dimensions (already configured)
- Check tmux version compatibility

### Pexpect Errors
- Ensure pexpect is installed: `uv pip install pexpect`
- Check Python version (requires 3.8+)
- Verify virtual environment is activated

## Design Philosophy

This test suite follows the "un-gameable tests" philosophy:

1. **Mirror Real Usage** - Tests execute exactly as users would
2. **Validate True Behavior** - Tests verify actual functionality, not implementation details
3. **Resist Gaming** - Tests prevent shortcuts, workarounds, or cheating
4. **Few but Critical** - Focus on high-value tests that cover essential user journeys
5. **Fail Honestly** - When functionality is broken, tests fail clearly

## Traceability

### STATUS Report Gaps Addressed

| Gap | Test(s) |
|-----|---------|
| Ctrl-b h never verified | `test_ctrl_b_h_creates_help_pane` |
| No keystroke automation | All tests use `send_prefix_key()` |
| No integration testing | `test_help_pane_works_in_tmux_test_session` |
| Help pane persistence | `test_help_pane_survives_pane_switching` |
| Toggle state tracking | `test_ctrl_b_h_help_pane_id_tracking` |

### PLAN Items Validated

| Item | Test(s) |
|------|---------|
| P0-1: pexpect installation | Framework uses pexpect throughout |
| P0-2: Ctrl-b h test | All keybinding tests |
| P0-3: Keybinding framework | `TmuxSession` class |
| P0-4: E2E framework | All e2e tests |

## Next Steps

Sprint 2 will add:
- Tests for all 20+ keybindings (P1-1)
- Status bar command echo verification (P1-2)
- Full help popup test (P1-3)
- More integration tests (P1-5)
- Persistence tests (P1-6)

See `PLAN-2025-11-06-003740.md` for full roadmap.

## Contributing

When adding tests:
1. Use `tmux_session` fixture (automatic cleanup)
2. Add `@pytest.mark.keybinding` or `@pytest.mark.e2e`
3. Add `@pytest.mark.slow` for tests >2 seconds
4. Write descriptive docstrings explaining the user workflow
5. Verify multiple observable outcomes (not just one assertion)
6. Add comments explaining why test is un-gameable

## License

Same as parent project.
