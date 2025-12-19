"""
Pytest configuration and shared fixtures for tmux testing.

Uses ptytest package for real terminal testing.
Fixtures (tmux_session, tmux_session_minimal, tmux_session_factory)
are auto-registered by ptytest's pytest plugin.

Install ptytest: pip install -e ~/code/ptytest
"""

# ptytest auto-registers fixtures via pytest plugin entry point.
# We just need to add any project-specific markers here.


def pytest_configure(config):
    """Configure pytest with project-specific markers."""
    config.addinivalue_line(
        "markers",
        "integration: marks integration tests"
    )
