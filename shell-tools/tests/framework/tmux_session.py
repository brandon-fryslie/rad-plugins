"""
TmuxSession: Real tmux session management for automated testing.

This framework uses REAL tmux processes and sends REAL keystrokes as bytes.
Tests cannot be gamed with mocks - they verify actual tmux behavior.

Key Design Principles:
1. Use real tmux subprocess (via pexpect), NOT mocks
2. Send actual keystroke bytes (Ctrl-b h = '\\x02h')
3. Verify observable outcomes (pane count, content, status bar)
4. Enforce cleanup (no orphaned sessions)
5. Provide helpful error messages when tests fail

Important: When testing pane operations, use split_window() instead of
send_keys("tmux split-window"), as the latter tries to run nested tmux
which doesn't work reliably.
"""

import os
import time
import subprocess
import pexpect
from typing import Optional, List


class TmuxSession:
    """
    Manages a real tmux session for testing.

    This class spawns an actual tmux process and allows sending
    real keystrokes, verifying pane states, and capturing output.

    Example:
        session = TmuxSession(session_name="test-session")
        try:
            # Send Ctrl-b h
            session.send_prefix_key('h')

            # Verify help pane appeared
            assert session.get_pane_count() == 2

            # Verify content
            content = session.get_pane_content()
            assert "PANES" in content
        finally:
            session.cleanup()
    """

    PREFIX_KEY = '\x02'  # Ctrl-b as character

    def __init__(
        self,
        session_name: Optional[str] = None,
        config_file: Optional[str] = None,
        width: int = 120,
        height: int = 40,
        timeout: int = 5
    ):
        """
        Create and attach to a real tmux session.

        Args:
            session_name: Unique session name (auto-generated if None)
            config_file: Path to tmux config (defaults to ~/.tmux.conf)
            width: Terminal width in characters
            height: Terminal height in characters
            timeout: Default timeout for operations in seconds
        """
        self.session_name = session_name or f"pytest-tmux-{os.getpid()}-{int(time.time())}"
        self.config_file = config_file or os.path.expanduser("~/.tmux.conf")
        self.width = width
        self.height = height
        self.timeout = timeout
        self.process: Optional[pexpect.spawn] = None
        self._is_cleaned_up = False

        # Ensure no existing session with this name
        self._kill_existing_session()

        # Start tmux session
        self._start_session()

    def _kill_existing_session(self):
        """Kill any existing session with our name (cleanup from failed tests)."""
        subprocess.run(
            ["tmux", "kill-session", "-t", self.session_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

    def _start_session(self):
        """
        Spawn a real tmux session.

        Creates a DETACHED session first, then attaches to it with pexpect.
        This ensures the shell inside tmux initializes properly and can accept
        commands via send-keys, while still allowing raw keystroke injection
        via pexpect for testing keybindings.
        """
        # Step 1: Create a DETACHED tmux session
        # This allows the shell to initialize properly
        cmd = [
            "tmux",
            "-f", self.config_file,  # Use specified config
            "new-session",
            "-d",  # DETACHED - this is the key fix!
            "-s", self.session_name,  # Session name
            "-x", str(self.width),    # Width
            "-y", str(self.height),   # Height
        ]

        subprocess.run(cmd, check=True)

        # Wait for session to be fully created
        time.sleep(0.3)

        # Verify session exists
        if not self._session_exists():
            raise RuntimeError(f"Failed to create tmux session: {self.session_name}")

        # Wait for shell to be ready
        self._wait_for_shell_ready()

        # Step 2: Attach to the session with pexpect
        # This allows us to send raw keystrokes for testing keybindings
        self.process = pexpect.spawn(
            "tmux",
            ["-f", self.config_file, "attach", "-t", self.session_name],
            encoding='utf-8',
            timeout=self.timeout,
            dimensions=(self.height, self.width)
        )

        # Wait for attach to complete
        time.sleep(0.2)

    def _wait_for_shell_ready(self, max_attempts: int = 10):
        """
        Wait for the shell inside tmux to be ready to accept commands.

        The shell needs time to initialize before send_keys() commands
        will work properly. We test this by sending a marker command
        and waiting for its OUTPUT to appear (not just the typed command).
        """
        marker = f"__READY_{os.getpid()}__"

        for attempt in range(max_attempts):
            # Send a simple echo command with a unique marker
            subprocess.run(
                ["tmux", "send-keys", "-t", self.session_name, f"echo {marker}", "C-m"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

            # Wait a bit for the command to execute
            time.sleep(0.15)

            # Check if marker appears in pane content (on its own line, indicating execution)
            content = self.get_pane_content(include_history=False)
            lines = content.split('\n')

            # Look for marker on a line by itself (not part of "echo __READY__")
            for line in lines:
                if marker in line and 'echo' not in line:
                    # Shell executed the command! It's ready.
                    # Clear the pane to remove the marker
                    subprocess.run(
                        ["tmux", "send-keys", "-t", self.session_name, "clear", "C-m"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )
                    time.sleep(0.1)
                    return

            # Wait before next attempt
            time.sleep(0.1)

        # If we can't confirm shell is ready, proceed anyway
        # (some shells or configs might not display the marker)

    def _session_exists(self) -> bool:
        """Check if our tmux session exists."""
        result = subprocess.run(
            ["tmux", "has-session", "-t", self.session_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        return result.returncode == 0

    def send_prefix_key(self, key: str, delay: float = 0.15):
        """
        Send Ctrl-b + key to tmux (the real keybinding).

        This sends ACTUAL bytes to the tmux process, triggering
        the real keybinding handlers. Cannot be faked with mocks.

        Args:
            key: The key to press after Ctrl-b (e.g., 'h' for Ctrl-b h)
            delay: Delay after keystroke for tmux to process (seconds)

        Example:
            session.send_prefix_key('h')  # Sends Ctrl-b h
            session.send_prefix_key('o')  # Sends Ctrl-b o
        """
        if not self.process:
            raise RuntimeError("Session not started")

        # Send Ctrl-b (prefix) then key
        # When encoding='utf-8' is set, pexpect expects strings, not bytes
        self.process.send(self.PREFIX_KEY)
        time.sleep(0.05)  # Small delay between prefix and key

        # Send the key
        self.process.send(key)

        # Wait for tmux to process the keystroke
        time.sleep(delay)

    def send_keys(self, keys: str, delay: float = 0.15, literal: bool = False):
        """
        Send literal keys to the currently active pane using tmux send-keys.

        This is more reliable than using pexpect for complex commands.
        Now properly executes commands in the shell because the session
        was created in detached mode.

        NOTE: For creating panes during tests, use split_window() instead,
        as send_keys("tmux split-window") tries to run nested tmux which
        doesn't work reliably.

        Args:
            keys: Keys to send
            delay: Delay after sending (seconds). Default 0.15s to ensure
                  commands have time to execute.
            literal: If True, send keys without executing (no Enter key).
                    If False (default), execute the command by adding Enter.
        """
        cmd = ["tmux", "send-keys", "-t", self.session_name]

        if literal:
            # Send keys without executing (for typing text)
            cmd.extend(["-l", keys])
        else:
            # Send keys and execute (add Enter)
            cmd.extend([keys, "C-m"])

        subprocess.run(cmd, check=True)
        time.sleep(delay)

    def split_window(self, direction: str = "-h", target_pane: Optional[int] = None):
        """
        Split a pane in the session.

        This method controls tmux from OUTSIDE the session (using subprocess),
        not from inside (which would require nested tmux). Use this instead of
        send_keys("tmux split-window") in tests.

        Args:
            direction: "-h" for horizontal (left/right), "-v" for vertical (top/bottom)
            target_pane: Pane number to split (None = current pane)

        Example:
            session.split_window("-h")  # Split horizontally (left/right)
            session.split_window("-v")  # Split vertically (top/bottom)
        """
        target = f"{self.session_name}:{target_pane}" if target_pane else self.session_name

        result = subprocess.run(
            ["tmux", "split-window", direction, "-t", target],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            raise RuntimeError(f"Failed to split window: {result.stderr}")

        # Wait for pane to be ready
        time.sleep(0.2)

    def get_pane_count(self) -> int:
        """
        Get the number of panes in the session.

        This uses tmux's real pane listing - cannot be mocked.

        Returns:
            Number of panes currently in the session
        """
        result = subprocess.run(
            ["tmux", "list-panes", "-t", self.session_name, "-F", "#{pane_id}"],
            capture_output=True,
            text=True,
            check=True
        )
        panes = result.stdout.strip().split('\n') if result.stdout.strip() else []
        return len(panes)

    def get_pane_ids(self) -> List[str]:
        """Get list of pane IDs in the session."""
        result = subprocess.run(
            ["tmux", "list-panes", "-t", self.session_name, "-F", "#{pane_id}"],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip().split('\n') if result.stdout.strip() else []

    def get_pane_content(self, pane_id: Optional[str] = None, include_history: bool = True) -> str:
        """
        Capture the visible content of a pane.

        This reads the ACTUAL terminal output - cannot be faked.

        Args:
            pane_id: Specific pane ID (e.g., "%1"), or None for current pane
            include_history: If True, capture scrollback history (last 1000 lines).
                           If False, only capture visible screen content.

        Returns:
            Text content of the pane (visible content or with history)
        """
        # Pane IDs starting with % are absolute, use them directly
        target = pane_id if pane_id else self.session_name

        # Build command with proper argument order
        if include_history:
            # Capture scrollback history: tmux capture-pane -t TARGET -p -S -1000
            cmd = ["tmux", "capture-pane", "-t", target, "-p", "-S", "-1000"]
        else:
            # Capture only visible content: tmux capture-pane -t TARGET -p
            cmd = ["tmux", "capture-pane", "-t", target, "-p"]

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout

    def get_pane_height(self, pane_id: Optional[str] = None) -> int:
        """Get the height of a pane in lines."""
        # Pane IDs starting with % are absolute, use them directly
        target = pane_id if pane_id else self.session_name

        result = subprocess.run(
            ["tmux", "display-message", "-t", target, "-p", "#{pane_height}"],
            capture_output=True,
            text=True,
            check=True
        )
        return int(result.stdout.strip())

    def get_status_bar(self) -> str:
        """
        Capture the status bar content.

        This reads the ACTUAL status bar - verifies real tmux state.

        Returns:
            Status bar text
        """
        result = subprocess.run(
            ["tmux", "display-message", "-t", self.session_name, "-p",
             "#{status-left}#{status-right}"],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()

    def verify_text_appears(self, text: str, timeout: float = 2.0, pane_id: Optional[str] = None) -> bool:
        """
        Wait for text to appear in a pane.

        Args:
            text: Text to search for
            timeout: How long to wait (seconds)
            pane_id: Specific pane to check, or None for current pane

        Returns:
            True if text appears within timeout, False otherwise
        """
        start_time = time.time()
        while time.time() - start_time < timeout:
            content = self.get_pane_content(pane_id)
            if text in content:
                return True
            time.sleep(0.1)
        return False

    def get_global_option(self, option: str) -> str:
        """Get a tmux global option value."""
        result = subprocess.run(
            ["tmux", "show", "-gv", option],
            capture_output=True,
            text=True
        )
        return result.stdout.strip() if result.returncode == 0 else ""

    def set_global_option(self, option: str, value: str):
        """Set a tmux global option."""
        subprocess.run(
            ["tmux", "set", "-g", option, value],
            check=True
        )

    def cleanup(self):
        """
        Clean up the tmux session.

        MUST be called to prevent orphaned sessions.
        Use try/finally or pytest fixtures to ensure this is called.

        This method also clears global tmux variables to prevent pollution
        between test sessions.
        """
        if self._is_cleaned_up:
            return

        self._is_cleaned_up = True

        # Close pexpect process
        if self.process:
            try:
                self.process.close(force=True)
            except:
                pass

        # Clear global variables before killing session
        # This prevents state pollution between test runs
        subprocess.run(
            ["tmux", "set", "-g", "@help_pane_id", ""],
            stderr=subprocess.DEVNULL
        )

        # Kill tmux session (this is the real cleanup)
        subprocess.run(
            ["tmux", "kill-session", "-t", self.session_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

    def __enter__(self):
        """Context manager support."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager cleanup."""
        self.cleanup()
        return False
