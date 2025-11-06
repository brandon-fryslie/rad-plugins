"""
Test Ctrl-b h keybinding (help pane toggle).

This test CANNOT BE GAMED because:
1. It sends REAL keystroke bytes (\\x02h) to a REAL tmux process
2. It verifies ACTUAL pane count changes via tmux list-panes
3. It checks REAL pane content from the terminal
4. It validates REAL pane height using tmux display-message
5. No mocks, no stubs - only real observable outcomes

If this test passes, Ctrl-b h ACTUALLY WORKS in production.
If it fails, the keybinding is broken.
"""

import pytest
import time


@pytest.mark.keybinding
def test_ctrl_b_h_creates_help_pane(tmux_session):
    """
    Test that Ctrl-b h creates a help pane.

    User workflow:
        1. Start tmux session (1 pane initially)
        2. Press Ctrl-b h
        3. See help pane appear at bottom (now 2 panes)

    This test verifies the ACTUAL keybinding, not the toggle script.
    """
    # GIVEN: A fresh tmux session with 1 pane
    initial_pane_count = tmux_session.get_pane_count()
    assert initial_pane_count == 1, \
        f"Expected 1 initial pane, got {initial_pane_count}"

    # WHEN: User presses Ctrl-b h
    tmux_session.send_prefix_key('h')

    # THEN: Help pane appears (pane count increases to 2)
    final_pane_count = tmux_session.get_pane_count()
    assert final_pane_count == 2, \
        f"Expected 2 panes after Ctrl-b h, got {final_pane_count}"


@pytest.mark.keybinding
def test_ctrl_b_h_help_pane_correct_height(tmux_session):
    """
    Test that help pane has correct height (5 lines).

    The help pane is designed to be 5 lines tall to show shortcuts
    without taking too much screen space.
    """
    # GIVEN: Tmux session with help pane visible
    tmux_session.send_prefix_key('h')
    time.sleep(0.2)  # Wait for pane creation

    # WHEN: We check the help pane height (from @help_pane_id)
    help_pane_id = tmux_session.get_global_option("@help_pane_id")
    assert help_pane_id != "" and help_pane_id != "0", \
        "help_pane_id should be set"

    help_pane_height = tmux_session.get_pane_height(help_pane_id)

    # THEN: Help pane is exactly 5 lines tall
    assert help_pane_height == 5, \
        f"Expected help pane height 5, got {help_pane_height}"


@pytest.mark.keybinding
def test_ctrl_b_h_help_pane_shows_content(tmux_session):
    """
    Test that help pane displays the correct shortcut content.

    This verifies we're not just creating an empty pane - the help
    script must actually run and display the shortcuts.
    """
    # GIVEN: Tmux session with help pane visible
    tmux_session.send_prefix_key('h')
    time.sleep(0.3)  # Wait for help script to render

    # WHEN: We capture the help pane content (from @help_pane_id)
    help_pane_id = tmux_session.get_global_option("@help_pane_id")
    assert help_pane_id != "" and help_pane_id != "0", \
        "help_pane_id should be set"

    content = tmux_session.get_pane_content(help_pane_id)

    # THEN: Help content contains expected shortcut categories
    # (These strings come from ~/.tmux-help-pane.sh)
    assert "PANES" in content, \
        "Help pane should show 'PANES' section"
    assert "WINDOWS" in content, \
        "Help pane should show 'WINDOWS' section"

    # Verify specific shortcuts are documented
    assert "next" in content or "onext" in content, \
        "Help pane should document next pane shortcut"

    # Check for "zoom" handling word wrapping by removing newlines
    content_no_newlines = content.replace("\n", "")
    assert "zoom" in content_no_newlines, \
        "Help pane should document zoom shortcut"


@pytest.mark.keybinding
def test_ctrl_b_h_toggles_help_pane_off(tmux_session):
    """
    Test that pressing Ctrl-b h again removes the help pane.

    User workflow:
        1. Press Ctrl-b h (help appears)
        2. Press Ctrl-b h again (help disappears)

    This is the toggle behavior - verifies state tracking works.
    """
    # GIVEN: Tmux session with help pane visible
    tmux_session.send_prefix_key('h')
    time.sleep(0.2)
    assert tmux_session.get_pane_count() == 2, \
        "Help pane should be visible"

    # WHEN: User presses Ctrl-b h again
    tmux_session.send_prefix_key('h')
    time.sleep(0.2)

    # THEN: Help pane is removed (back to 1 pane)
    final_pane_count = tmux_session.get_pane_count()
    assert final_pane_count == 1, \
        f"Expected help pane removed (1 pane), got {final_pane_count}"


@pytest.mark.keybinding
def test_ctrl_b_h_toggle_multiple_times(tmux_session):
    """
    Test that help pane can be toggled multiple times reliably.

    This catches race conditions or state corruption bugs.
    """
    # Toggle on/off 5 times
    for i in range(5):
        # Toggle ON
        tmux_session.send_prefix_key('h')
        time.sleep(0.15)
        pane_count_on = tmux_session.get_pane_count()
        assert pane_count_on == 2, \
            f"Cycle {i+1}: Expected 2 panes when help ON, got {pane_count_on}"

        # Toggle OFF
        tmux_session.send_prefix_key('h')
        time.sleep(0.15)
        pane_count_off = tmux_session.get_pane_count()
        assert pane_count_off == 1, \
            f"Cycle {i+1}: Expected 1 pane when help OFF, got {pane_count_off}"


@pytest.mark.keybinding
def test_ctrl_b_h_help_pane_id_tracking(tmux_session):
    """
    Test that @help_pane_id global variable is set correctly.

    The toggle script uses @help_pane_id to track which pane is the help pane.
    This test verifies the state management works.
    """
    # GIVEN: Fresh session (no help pane)
    help_pane_id_empty = tmux_session.get_global_option("@help_pane_id")
    assert help_pane_id_empty == "" or help_pane_id_empty == "0", \
        "help_pane_id should be empty initially"

    # WHEN: Help pane is created
    tmux_session.send_prefix_key('h')
    time.sleep(0.2)

    # THEN: @help_pane_id is set to the new pane's ID
    help_pane_id = tmux_session.get_global_option("@help_pane_id")
    assert help_pane_id != "" and help_pane_id != "0", \
        "help_pane_id should be set after creating help pane"

    # Verify it matches an actual pane
    pane_ids = tmux_session.get_pane_ids()
    assert help_pane_id in pane_ids, \
        f"help_pane_id '{help_pane_id}' should be in pane list {pane_ids}"

    # WHEN: Help pane is removed
    tmux_session.send_prefix_key('h')
    time.sleep(0.2)

    # THEN: @help_pane_id is cleared
    help_pane_id_after = tmux_session.get_global_option("@help_pane_id")
    assert help_pane_id_after == "" or help_pane_id_after == "0", \
        f"help_pane_id should be cleared after removing help pane, got '{help_pane_id_after}'"


@pytest.mark.keybinding
def test_ctrl_b_h_works_with_existing_panes(tmux_session):
    """
    Test that help pane toggle works when multiple panes exist.

    User workflow:
        1. Split window to create 2 panes
        2. Press Ctrl-b h (help appears, now 3 panes)
        3. Press Ctrl-b h again (help disappears, back to 2 panes)

    This tests that help toggle doesn't interfere with user panes.
    """
    # GIVEN: Session with 2 user panes
    tmux_session.split_window("-h")
    time.sleep(0.4)

    initial_count = tmux_session.get_pane_count()
    assert initial_count == 2, \
        f"Expected 2 panes after split, got {initial_count}"

    # WHEN: Help pane is toggled on
    tmux_session.send_prefix_key('h')
    time.sleep(0.2)

    # THEN: Pane count is 3 (2 user + 1 help)
    with_help = tmux_session.get_pane_count()
    assert with_help == 3, \
        f"Expected 3 panes (2 user + help), got {with_help}"

    # WHEN: Help pane is toggled off
    tmux_session.send_prefix_key('h')
    time.sleep(0.2)

    # THEN: Pane count returns to 2 (help removed, user panes intact)
    after_toggle = tmux_session.get_pane_count()
    assert after_toggle == 2, \
        f"Expected 2 panes (user panes only), got {after_toggle}"
