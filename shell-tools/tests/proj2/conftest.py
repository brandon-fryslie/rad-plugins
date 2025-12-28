"""
Pytest configuration and fixtures for proj2 tests.

This module provides shared fixtures and test configuration for testing
the proj2 (p2z) project navigation command.
"""

import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Generator, List

import pytest


@pytest.fixture
def temp_dir() -> Generator[Path, None, None]:
    """Create a temporary directory for test isolation."""
    temp_path = Path(tempfile.mkdtemp(prefix="proj2-test-"))
    try:
        yield temp_path
    finally:
        shutil.rmtree(temp_path, ignore_errors=True)


@pytest.fixture
def projects_dir(temp_dir: Path) -> Path:
    """Create a projects directory for testing."""
    proj_dir = temp_dir / "projects"
    proj_dir.mkdir(parents=True, exist_ok=True)
    return proj_dir


@pytest.fixture
def multiple_projects_dirs(temp_dir: Path) -> List[Path]:
    """Create multiple projects directories for testing."""
    dirs = [
        temp_dir / "projects1",
        temp_dir / "projects2",
        temp_dir / "projects3",
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)
    return dirs


@pytest.fixture
def sample_project(projects_dir: Path, tmp_path: Path) -> Path:
    """Create a sample project with git repo (function-scoped for isolation)."""
    # Use tmp_path for test isolation - each test gets a clean project
    proj = tmp_path / "sample-project"
    proj.mkdir(parents=True, exist_ok=True)

    # Initialize git repo
    subprocess.run(
        ["git", "init"],
        cwd=proj,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True
    )
    subprocess.run(
        ["git", "config", "user.name", "Test User"],
        cwd=proj,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True
    )
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=proj,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True
    )

    # Create initial commit
    readme = proj / "README.md"
    readme.write_text("# Sample Project\n")
    subprocess.run(
        ["git", "add", "README.md"],
        cwd=proj,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True
    )
    subprocess.run(
        ["git", "commit", "-m", "Initial commit"],
        cwd=proj,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True
    )

    return proj


@pytest.fixture
def multiple_projects(multiple_projects_dirs: List[Path]) -> List[Path]:
    """Create multiple sample projects across directories."""
    projects = []
    names = [
        ("projects1", "project-alpha"),
        ("projects1", "project-beta"),
        ("projects2", "project-gamma"),
        ("projects2", "project-delta"),
        ("projects3", "project-epsilon"),
    ]

    for dir_name, proj_name in names:
        proj_dir = None
        for d in multiple_projects_dirs:
            if d.name == dir_name:
                proj_dir = d
                break

        if proj_dir is None:
            continue

        proj = proj_dir / proj_name
        proj.mkdir(parents=True, exist_ok=True)

        # Initialize git repo
        subprocess.run(
            ["git", "init"],
            cwd=proj,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )
        subprocess.run(
            ["git", "config", "user.name", "Test User"],
            cwd=proj,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )
        subprocess.run(
            ["git", "config", "user.email", "test@example.com"],
            cwd=proj,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )

        # Create README
        readme = proj / "README.md"
        readme.write_text(f"# {proj_name}\n")
        subprocess.run(
            ["git", "add", "README.md"],
            cwd=proj,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )
        subprocess.run(
            ["git", "commit", "-m", "Initial commit"],
            cwd=proj,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )

        projects.append(proj)

    return projects


@pytest.fixture
def proj2_script_dir() -> Path:
    """Get the path to the proj2 script directory."""
    # The script is in shell-tools/proj2.zsh
    # This file is in shell-tools/tests/proj2/
    current_file = Path(__file__).resolve()
    return current_file.parent.parent.parent  # Go up to shell-tools (tests -> proj2 -> shell-tools)


@pytest.fixture
def zshrc_content(proj2_script_dir: Path, projects_dir: Path) -> str:
    """
    Generate minimal zshrc content for testing proj2.

    This provides a clean zsh environment with proj2 loaded.
    """
    return f"""
# Minimal zshrc for proj2 testing

# Disable compinit for speed
skip_global_compinit=1
zstyle ':completion:*' use-cache 0

# Path setup
typeset -g PATH="$PATH:/usr/local/bin:/usr/bin:/bin"

# Projects directory
export PROJECTS_DIRS="{projects_dir}"

# Source proj2
source "{proj2_script_dir}/proj2.zsh"

# Test marker
export PROJ2_TEST_ENV=1
"""


@pytest.fixture
def zshrc_multiple_dirs(proj2_script_dir: Path, multiple_projects_dirs: List[Path]) -> str:
    """Generate zshrc with multiple project directories."""
    dirs_str = " ".join(str(d) for d in multiple_projects_dirs)
    return f"""
# Minimal zshrc for proj2 testing with multiple directories

skip_global_compinit=1
zstyle ':completion:*' use-cache 0

typeset -g PATH="$PATH:/usr/local/bin:/usr/bin:/bin"

# Multiple project directories (array)
export PROJECTS_DIRS=({dirs_str})

# Source proj2
source "{proj2_script_dir}/proj2.zsh"

export PROJ2_TEST_ENV=1
"""


@pytest.fixture
def git_status_script(proj2_script_dir: Path) -> Path:
    """Get path to the git status helper script."""
    return proj2_script_dir / ".proj2z-git-status.sh"


@pytest.fixture
def filter_script(proj2_script_dir: Path) -> Path:
    """Get path to the filter script."""
    return proj2_script_dir / ".proj2z-filter.sh"


@pytest.fixture
def preview_script(proj2_script_dir: Path) -> Path:
    """Get path to the preview script."""
    return proj2_script_dir / ".proj2z-preview.sh"


@pytest.fixture
def load_status_script(proj2_script_dir: Path) -> Path:
    """Get path to the load status script."""
    return proj2_script_dir / ".proj2z-load-status.sh"


@pytest.fixture
def fzf_installed() -> bool:
    """Check if fzf is installed."""
    result = subprocess.run(
        ["which", "fzf"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    return result.returncode == 0


@pytest.fixture
def tmux_installed() -> bool:
    """Check if tmux is installed."""
    result = subprocess.run(
        ["which", "tmux"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    return result.returncode == 0


@pytest.fixture
def requires_fzf(fzf_installed: bool):
    """Skip test if fzf is not installed."""
    if not fzf_installed:
        pytest.skip("fzf not installed")


@pytest.fixture
def requires_tmux(tmux_installed: bool):
    """Skip test if tmux is not installed."""
    if not tmux_installed:
        pytest.skip("tmux not installed")


def pytest_configure(config):
    """Configure pytest markers."""
    config.addinivalue_line("markers", "slow: marks tests as slow")
    config.addinivalue_line("markers", "tmux: marks tests requiring tmux")
    config.addinivalue_line("markers", "fzf: marks tests requiring fzf")
    config.addinivalue_line("markers", "git: marks tests requiring git")
