#!/usr/bin/env python3
"""
Recursively find all files sourced from a shell configuration file.

This tool traces through shell configuration files (zsh, bash) and finds all
files that are sourced, handling various shell syntax patterns and special cases.
"""

import re
import os
import sys
from pathlib import Path
from collections import deque


# Pattern to match source commands: source, \., or bare .
SOURCE_PATTERN = re.compile(r'(?:^|\s|[;&|]+)\s*(source|\\\.|\.)\s+([^\s;&|#]+)')


def expand_path(path_str, current_file):
    """
    Expand shell path variables to absolute paths.

    Handles:
    - zsh ${0:a:h} (current script directory)
    - ${VAR:-default} parameter expansion
    - $VAR and ~ expansion
    - Unresolved variables (tries to infer from context)
    """
    # Handle zsh-specific ${0:a:h} (current script's directory)
    path_str = path_str.replace('${0:a:h}', str(current_file.parent))

    # Handle shell parameter expansion ${VAR:-default}
    param_match = re.search(r'\$\{([^}:]+):-([^}]+)\}', path_str)
    if param_match:
        var_name, default_val = param_match.groups()
        replacement = os.environ.get(var_name, default_val)
        path_str = path_str[:param_match.start()] + replacement + path_str[param_match.end():]

    # Expand $VAR and ~
    path_str = os.path.expandvars(path_str)
    path_str = os.path.expanduser(path_str)

    # If still contains unresolved variables, try to infer from context
    if '$' in path_str:
        var_match = re.search(r'\$\{?[\w_]+\}?/(.*)', path_str)
        if var_match:
            subpath = var_match.group(1)
            inferred = current_file.parent / subpath
            if inferred.exists():
                return inferred
            return None  # Can't resolve

    # Convert to Path and handle relative paths
    result = Path(path_str)
    if not result.is_absolute():
        result = current_file.parent / result

    return result


def add_zgenom_init(current_file, visited, queue):
    """Add zgenom's indirect init file if we encounter zgenom.zsh."""
    if current_file.name != 'zgenom.zsh':
        return

    zgenom_init = Path.home() / '.zgenom' / 'sources' / 'init.zsh'
    if not zgenom_init.exists():
        return

    zgenom_resolved = zgenom_init.resolve()
    if zgenom_resolved not in visited:
        visited.add(zgenom_resolved)
        queue.append((zgenom_resolved, zgenom_init))


def extract_sourced_paths(file_path):
    """
    Extract all sourced file paths from a shell script.

    Returns a list of path strings found in source/. commands.
    """
    paths = []

    try:
        with open(file_path, 'r') as f:
            for line in f:
                # Skip comments
                if line.strip().startswith('#'):
                    continue

                # Find all source commands in this line
                for match in SOURCE_PATTERN.finditer(line):
                    path_str = match.group(2).strip('\'"')
                    paths.append(path_str)

    except Exception as e:
        print(f"Error reading {file_path}: {e}", file=sys.stderr)

    return paths


def find_sourced(start_file):
    """
    Find all files sourced from start_file using breadth-first search.

    Prints each sourced file (excluding the start file) to stdout.
    """
    start_file = Path(start_file).expanduser()
    start_resolved = start_file.resolve()

    if not start_resolved.is_file():
        print(f"Error: {start_file} is not a file", file=sys.stderr)
        return

    print(f"Finding sourced files in: {start_file}", file=sys.stderr)

    # Track visited files by resolved path to avoid cycles
    visited = {start_resolved}

    # Queue of (resolved_path, display_path) tuples
    # display_path is None for the start file (which we don't print)
    queue = deque([(start_resolved, None)])

    while queue:
        current_resolved, current_display = queue.popleft()

        # Print this file (but not the starting file)
        if current_display is not None:
            print(current_display)

        # Special case: zgenom uses an indirect init file
        add_zgenom_init(current_resolved, visited, queue)

        # Extract all sourced paths from this file
        for path_str in extract_sourced_paths(current_resolved):
            # Expand path variables
            sourced_path = expand_path(path_str, current_resolved)

            # Skip if we couldn't resolve the path
            if sourced_path is None or not sourced_path.exists():
                continue

            # Add to queue if not already visited
            sourced_resolved = sourced_path.resolve()
            if sourced_resolved not in visited:
                visited.add(sourced_resolved)
                queue.append((sourced_resolved, sourced_path))


if __name__ == '__main__':
    input_file = sys.argv[1] if len(sys.argv) > 1 else '~/.zshrc'
    find_sourced(input_file)
