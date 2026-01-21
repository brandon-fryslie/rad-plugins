"""
Test zaw-rad-docker-image ZLE widget (Option+Shift+< keybinding).

This test verifies the fix for "bad set of key/value pairs for associative array" error.
"""

import pytest
import time
from ptytest import Keys


# Option+Shift+< sends ESC <
OPT_SHIFT_LT = Keys.meta('<')

# Common escape sequences for zaw navigation
ESC = Keys.ESCAPE
ENTER = Keys.ENTER
CTRL_C = Keys.CTRL_C
CTRL_G = Keys.CTRL_G


@pytest.mark.zle
@pytest.mark.zaw
def test_zaw_docker_image_activates_without_error(tmux_session):
    """
    Test that Option+Shift+< activates zaw-rad-docker-image without errors.

    This test verifies the bug fix for:
        zaw-src-rad-docker-image:26: bad set of key/value pairs for associative array
    """
    # Wait for shell to fully initialize
    time.sleep(0.5)

    # WHEN: User presses Option+Shift+<
    tmux_session.send_raw(OPT_SHIFT_LT, delay=0.5)

    # THEN: Check that the bug error does NOT appear
    content = tmux_session.get_pane_content()

    # Check that the bug error does NOT appear
    assert "bad set of key/value pairs" not in content, \
        f"Bug still present! Error message found in output:\n{content}"

    assert "associative array" not in content, \
        f"Bug still present! Error message found in output:\n{content}"

    # Clean up: close zaw with Escape or Ctrl-G
    tmux_session.send_raw(ESC, delay=0.2)
    tmux_session.send_raw(CTRL_G, delay=0.2)
