#!/usr/bin/env python3
"""
Test runner for proj2 tests.

This script provides convenient ways to run the ptytest-based test suite
for the proj2 (p2z) project navigation command.
"""

import argparse
import subprocess
import sys
from pathlib import Path


def run_pytest(args: list, verbose: bool = False) -> int:
    """Run pytest with the given arguments."""
    cmd = ["python3", "-m", "pytest"]

    if verbose:
        cmd.append("-vv")

    cmd.extend(args)

    print(f"Running: {' '.join(cmd)}\n")
    result = subprocess.run(cmd)
    return result.returncode


def main():
    parser = argparse.ArgumentParser(
        description="Run proj2 tests using pytest and ptytest"
    )

    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output"
    )

    parser.add_argument(
        "-k", "--keyword",
        help="Filter tests by keyword expression"
    )

    parser.add_argument(
        "-m", "--marker",
        help="Filter tests by marker (e.g., 'not slow', 'tmux')"
    )

    parser.add_argument(
        "--fast",
        action="store_true",
        help="Run only fast tests (exclude slow, tmux, fzf tests)"
    )

    parser.add_argument(
        "--ci",
        action="store_true",
        help="Run tests in CI mode (no interactive/PTY tests)"
    )

    parser.add_argument(
        "--list",
        action="store_true",
        help="List all tests without running them"
    )

    parser.add_argument(
        "--cov",
        action="store_true",
        help="Run with coverage reporting (requires pytest-cov)"
    )

    args = parser.parse_args()

    # Build pytest arguments
    pytest_args = []

    if args.list:
        pytest_args.append("--collect-only")

    if args.marker:
        pytest_args.extend(["-m", args.marker])
    elif args.fast:
        pytest_args.extend(["-m", "not slow and not tmux and not fzf"])
    elif args.ci:
        pytest_args.extend(["-m", "not tmux"])

    if args.keyword:
        pytest_args.extend(["-k", args.keyword])

    if args.cov:
        pytest_args.extend([
            "--cov=../../../",
            "--cov-report=term-missing",
            "--cov-report=html"
        ])

    # Run tests
    return run_pytest(pytest_args, verbose=args.verbose)


if __name__ == "__main__":
    sys.exit(main())
