# Tmux Automated Test Suite

Comprehensive automated testing for tmux keybindings and ZLE widgets using **ptytest** - a real terminal testing framework.

## Overview

This test suite verifies that tmux keybindings and ZLE widgets **actually work** by:
- Spawning **real tmux processes** (not mocks)
- Sending **actual keystroke bytes** (Ctrl-b h = `\x02h`)
- Verifying **observable outcomes** (pane counts, content, status bars)
- Testing **complete user workflows** end-to-end

**These tests cannot be gamed.** They fail if the actual functionality is broken.

## Installation

```bash
cd shell-tools/tests

# Create virtual environment
uv venv

# Activate and install dependencies (including ptytest)
source .venv/bin/activate
uv pip install -r requirements-test.txt
```

**Note:** ptytest is installed from `~/code/ptytest`. To install it locally first:
```bash
cd ~/code/ptytest
uv pip install -e .
```

## Running Tests

```bash
# Activate virtual environment (if not already active)
source .venv/bin/activate

# Run all tests
pytest

# Run only keybinding tests
pytest -m keybinding

# Run only ZLE widget tests
pytest -m zle

# Run only zaw-related tests
pytest -m zaw

# Run only fast tests (skip slow E2E tests)
pytest -m "not slow"

# Run specific test file
pytest tests/keybindings/test_help_keybinding.py
pytest tests/zle/test_zaw_rad_dev.py

# Run with verbose output
pytest -v

# Run specific test
pytest tests/zle/test_zaw_rad_dev.py::test_zaw_rad_dev_activates_without_error
```

## Test Structure

```
tests/
├── conftest.py                      # Pytest config (uses ptytest fixtures)
├── requirements-test.txt            # Test dependencies including ptytest
├── keybindings/
│   └── test_help_keybinding.py      # Ctrl-b h keybinding tests
├── zle/
│   └── test_zaw_rad_dev.py          # ZLE widget tests (Option+Shift+D)
├── e2e/
│   └── test_tmux_test_workflow.py   # End-to-end workflow tests
└── README.md                        # This file
```

## Test Categories

### Keybinding Tests (`@pytest.mark.keybinding`)
Test individual tmux keybindings by sending real keystrokes:
- `test_ctrl_b_h_creates_help_pane` - Ctrl-b h shows help
- `test_ctrl_b_h_toggles_help_pane_off` - Ctrl-b h hides help
- `test_ctrl_b_h_help_pane_correct_height` - Help pane is 5 lines
- `test_ctrl_b_h_help_pane_shows_content` - Help shows shortcuts

### ZLE Widget Tests (`@pytest.mark.zle`, `@pytest.mark.zaw`)
Test zsh ZLE widgets by sending escape sequences to the shell:
- `test_zaw_rad_dev_activates_without_error` - Option+Shift+D opens zaw without errors
- `test_zaw_rad_dev_shows_plugin_list` - Shows list of rad-shell plugins
- `test_zaw_rad_dev_can_be_dismissed` - Can close with Escape
- `test_zaw_rad_dev_multiple_activations` - Works reliably on repeated use

### End-to-End Tests (`@pytest.mark.e2e`, `@pytest.mark.slow`)
Test complete user workflows from start to finish:
- `test_help_pane_works_in_tmux_test_session` - Help works in 2-pane layout
- `test_help_pane_survives_pane_switching` - Help persists across pane switches
- `test_complete_user_workflow` - Full workflow: start → work → help → finish

## How It Works

This test suite uses **ptytest**, a real terminal testing framework built on pexpect and tmux.

### Using ptytest

```python
import pytest
from ptytest import Keys

@pytest.mark.keybinding
def test_example(tmux_session):
    # Send Ctrl-b h (tmux prefix + key)
    tmux_session.send_prefix_key('h')

    # Verify pane count
    assert tmux_session.get_pane_count() == 2

    # Verify content
    content = tmux_session.get_pane_content()
    assert "PANES" in content
```

### Key Methods

- `send_prefix_key(key)` - Send Ctrl-b + key as real bytes (tmux keybindings)
- `send_raw(sequence)` - Send raw escape sequences to the shell (ZLE widgets)
- `send_keys(keys, literal)` - Send keys via tmux send-keys command
- `get_pane_count()` - Get number of panes via tmux list-panes
- `get_pane_content(pane_id)` - Capture real terminal output
- `get_pane_height(pane_id)` - Get pane height in lines
- `get_status_bar()` - Capture status bar text
- `verify_text_appears(text, timeout)` - Wait for text to appear

### Keys Helper

ptytest provides a `Keys` class with escape sequence constants:

```python
from ptytest import Keys

# Common keys
Keys.ESCAPE      # \x1b
Keys.ENTER       # \r
Keys.CTRL_C      # \x03
Keys.CTRL_G      # \x07

# Arrow keys
Keys.UP, Keys.DOWN, Keys.LEFT, Keys.RIGHT

# Helper methods
Keys.ctrl('c')   # Returns Ctrl-C sequence
Keys.meta('d')   # Returns Meta-D (Option-D on Mac)
```

### Fixtures (from ptytest)

ptytest auto-registers these fixtures via pytest plugin:

- `tmux_session` - Clean tmux session with user config (~/.tmux.conf)
- `tmux_session_minimal` - Clean tmux session with no config
- `tmux_session_factory` - Factory for creating multiple sessions

Each fixture:
- Creates isolated session with unique name
- Uses pytest's automatic cleanup (even if test fails)
- Ensures no interference between tests

## Why These Tests Are Un-Gameable

### 1. Real Processes
Tests spawn **actual tmux processes** using pexpect. No mocks can fake this.

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
```

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

### Adding a ZLE Widget Test

```python
import pytest
import time
from ptytest import Keys

# Define key sequences
OPT_SHIFT_D = Keys.meta('D')  # ESC D (Option+Shift+D)
ESC = Keys.ESCAPE
CTRL_G = Keys.CTRL_G

@pytest.mark.zle
def test_my_zle_widget(tmux_session):
    """Test a ZLE widget by sending escape sequences."""
    # Wait for shell to initialize
    time.sleep(0.5)

    # Send escape sequence to trigger widget
    tmux_session.send_raw(OPT_SHIFT_D, delay=0.5)

    # Verify widget activated (check terminal output)
    content = tmux_session.get_pane_content()
    assert "expected output" in content

    # Dismiss widget
    tmux_session.send_raw(ESC, delay=0.2)
    tmux_session.send_raw(CTRL_G, delay=0.2)
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

### ptytest Not Found
```bash
# Ensure ptytest is installed
cd ~/code/ptytest
uv pip install -e .

# Then install test requirements
cd /path/to/shell-tools/tests
source .venv/bin/activate
uv pip install -r requirements-test.txt
```

### Pexpect Errors
- Ensure pexpect is installed (included in ptytest dependencies)
- Check Python version (requires 3.8+)
- Verify virtual environment is activated

## Design Philosophy

This test suite follows the "un-gameable tests" philosophy:

1. **Mirror Real Usage** - Tests execute exactly as users would
2. **Validate True Behavior** - Tests verify actual functionality, not implementation details
3. **Resist Gaming** - Tests prevent shortcuts, workarounds, or cheating
4. **Few but Critical** - Focus on high-value tests that cover essential user journeys
5. **Fail Honestly** - When functionality is broken, tests fail clearly

## Contributing

When adding tests:
1. Use `tmux_session` fixture (automatic cleanup)
2. Add appropriate markers: `@pytest.mark.keybinding`, `@pytest.mark.zle`, `@pytest.mark.e2e`
3. Add `@pytest.mark.slow` for tests >2 seconds
4. Write descriptive docstrings explaining the user workflow
5. Verify multiple observable outcomes (not just one assertion)
6. Use `from ptytest import Keys` for escape sequences

## License

Same as parent project.
