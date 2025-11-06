"""
Pytest configuration and shared fixtures for tmux testing.

This file provides reusable fixtures that ensure:
1. Each test gets a clean, isolated tmux session
2. Sessions are always cleaned up (no orphans)
3. Tests can run in parallel without interference
"""

import pytest
import os
from .framework.tmux_session import TmuxSession


@pytest.fixture
def tmux_session():
    """
    Provide a clean tmux session for testing.

    This fixture:
    - Creates a unique tmux session for each test
    - Uses the user's ~/.tmux.conf configuration
    - Automatically cleans up after the test
    - Ensures test isolation (no interference between tests)

    Example:
        def test_help_pane(tmux_session):
            tmux_session.send_prefix_key('h')
            assert tmux_session.get_pane_count() == 2
    """
    # Create session with unique name (includes test name via pytest)
    session = TmuxSession(
        config_file=os.path.expanduser("~/.tmux.conf"),
        width=120,
        height=40,
        timeout=5
    )

    # Yield session to test
    yield session

    # Cleanup (always runs, even if test fails)
    session.cleanup()


@pytest.fixture
def tmux_session_minimal():
    """
    Provide a tmux session with minimal config (no ~/.tmux.conf).

    Useful for testing tmux basics without user customization.
    """
    session = TmuxSession(
        config_file="/dev/null",  # No config file
        width=120,
        height=40,
        timeout=5
    )

    yield session
    session.cleanup()


def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers",
        "slow: marks tests as slow (deselect with '-m \"not slow\"')"
    )
    config.addinivalue_line(
        "markers",
        "keybinding: marks tests that test keybindings"
    )
    config.addinivalue_line(
        "markers",
        "e2e: marks end-to-end workflow tests"
    )
    config.addinivalue_line(
        "markers",
        "integration: marks integration tests"
    )
