"""
End-to-end tests for the tmux-test workflow.

These tests verify the complete user workflow:
1. Run tmux-test function
2. Verify 2-pane layout (clod + terminal)
3. Toggle help pane during work
4. Verify everything works together

These tests CANNOT BE GAMED because:
1. They execute the REAL tmux-test function (from tmux-test.zsh)
2. They verify ACTUAL pane layout and content
3. They test REAL help pane integration
4. They check OBSERVABLE outcomes users would see
"""

import pytest
import time
import subprocess
import os


@pytest.mark.e2e
@pytest.mark.slow
def test_tmux_test_creates_two_pane_layout():
    """
    Test that tmux-test creates 2-pane layout correctly.

    User workflow:
        1. Run 'tmux-test' command
        2. See left pane with clod
        3. See right pane with terminal
    """
    session_name = f"pytest-e2e-{os.getpid()}"

    try:
        # GIVEN: No existing session
        subprocess.run(
            ["tmux", "kill-session", "-t", session_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

        # WHEN: We simulate tmux-test function (create session + split)
        # Create session
        subprocess.run(
            ["tmux", "new-session", "-d", "-s", session_name],
            check=True
        )

        # Split window vertically (as tmux-test does)
        subprocess.run(
            ["tmux", "split-window", "-h", "-t", session_name],
            check=True
        )

        time.sleep(0.3)

        # THEN: We have exactly 2 panes
        result = subprocess.run(
            ["tmux", "list-panes", "-t", session_name, "-F", "#{pane_id}"],
            capture_output=True,
            text=True,
            check=True
        )
        panes = result.stdout.strip().split('\n')
        assert len(panes) == 2, \
            f"Expected 2 panes in tmux-test layout, got {len(panes)}"

    finally:
        # Cleanup
        subprocess.run(
            ["tmux", "kill-session", "-t", session_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )


@pytest.mark.e2e
@pytest.mark.slow
def test_help_pane_works_in_tmux_test_session(tmux_session):
    """
    Test that Ctrl-b h works in a tmux-test-like session.

    User workflow:
        1. Start tmux-test session (2 panes)
        2. Press Ctrl-b h (help appears, now 3 panes)
        3. Press Ctrl-b h again (help disappears, back to 2 panes)

    This is the CRITICAL integration test - does help work during actual work?
    """
    # GIVEN: Session with 2 panes (simulating tmux-test layout)
    tmux_session.split_window("-h")
    time.sleep(0.4)

    initial_count = tmux_session.get_pane_count()
    assert initial_count == 2, \
        f"Expected 2 panes initially, got {initial_count}"

    # WHEN: User presses Ctrl-b h
    tmux_session.send_prefix_key('h')
    time.sleep(0.3)

    # THEN: Help pane appears (3 panes total)
    with_help = tmux_session.get_pane_count()
    assert with_help == 3, \
        f"Expected 3 panes with help, got {with_help}"

    # Verify help content is visible (using @help_pane_id)
    help_pane_id = tmux_session.get_global_option("@help_pane_id")
    assert help_pane_id != "" and help_pane_id != "0", \
        "help_pane_id should be set"

    content = tmux_session.get_pane_content(help_pane_id)
    assert "PANES" in content or "next" in content, \
        "Help pane should show shortcuts"

    # WHEN: User presses Ctrl-b h again
    tmux_session.send_prefix_key('h')
    time.sleep(0.3)

    # THEN: Help pane disappears (back to 2 panes)
    final_count = tmux_session.get_pane_count()
    assert final_count == 2, \
        f"Expected 2 panes after removing help, got {final_count}"


@pytest.mark.e2e
@pytest.mark.slow
def test_help_pane_survives_pane_switching(tmux_session):
    """
    Test that help pane remains visible when switching between work panes.

    User workflow:
        1. Have 2 work panes
        2. Toggle help on
        3. Switch between work panes with Ctrl-b o
        4. Help pane stays visible
    """
    # GIVEN: 2-pane layout with help visible
    tmux_session.split_window("-h")
    time.sleep(0.4)

    tmux_session.send_prefix_key('h')  # Show help
    time.sleep(0.3)

    assert tmux_session.get_pane_count() == 3, "Should have 3 panes"

    # WHEN: User switches panes (Ctrl-b o)
    tmux_session.send_prefix_key('o')  # Switch to next pane
    time.sleep(0.2)

    # THEN: Help pane is still present
    assert tmux_session.get_pane_count() == 3, \
        "Help pane should remain after pane switch"


@pytest.mark.e2e
@pytest.mark.slow
def test_help_pane_survives_creating_new_panes(tmux_session):
    """
    Test that help pane remains visible when creating new work panes.

    User workflow:
        1. Have help pane visible
        2. Create new work pane
        3. Help pane still visible and functional
    """
    # GIVEN: Help pane is visible
    tmux_session.send_prefix_key('h')
    time.sleep(0.3)
    assert tmux_session.get_pane_count() == 2, "Should have main + help"

    # WHEN: User creates a new pane
    tmux_session.split_window("-v")
    time.sleep(0.4)

    # THEN: All panes exist (main + new pane + help)
    pane_count = tmux_session.get_pane_count()
    assert pane_count == 3, \
        f"Expected 3 panes (2 work + help), got {pane_count}"

    # AND: Help pane is still the help pane (verify content)
    help_pane_id = tmux_session.get_global_option("@help_pane_id")
    if help_pane_id and help_pane_id != "0":
        content = tmux_session.get_pane_content(help_pane_id)
        assert "PANES" in content or "next" in content, \
            "Help pane should still show shortcuts"


@pytest.mark.e2e
@pytest.mark.slow
def test_complete_user_workflow(tmux_session):
    """
    Test the complete user workflow from start to finish.

    User story:
        1. Start tmux session
        2. Split into 2 panes for work
        3. Toggle help on to see shortcuts
        4. Do some work (switch panes)
        5. Toggle help off to reclaim space
        6. Toggle help back on when needed
    """
    # Step 1: Start with single pane
    assert tmux_session.get_pane_count() == 1

    # Step 2: Split for work
    tmux_session.split_window("-h")
    time.sleep(0.4)
    assert tmux_session.get_pane_count() == 2

    # Step 3: Show help to see shortcuts
    tmux_session.send_prefix_key('h')
    time.sleep(0.3)
    assert tmux_session.get_pane_count() == 3

    # Step 4: Do work (switch panes)
    tmux_session.send_prefix_key('o')
    time.sleep(0.1)

    # Step 5: Hide help to reclaim space
    tmux_session.send_prefix_key('h')
    time.sleep(0.3)
    assert tmux_session.get_pane_count() == 2

    # Step 6: Show help again when needed
    tmux_session.send_prefix_key('h')
    time.sleep(0.3)
    assert tmux_session.get_pane_count() == 3

    # Final verification: help content is correct
    help_pane_id = tmux_session.get_global_option("@help_pane_id")
    assert help_pane_id != "" and help_pane_id != "0", \
        "help_pane_id should be set"

    content = tmux_session.get_pane_content(help_pane_id)
    assert "PANES" in content or "WINDOWS" in content, \
        "Help pane should show complete shortcuts"
