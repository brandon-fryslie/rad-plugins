#!/usr/bin/env zsh

# Setup script for mock git repository used in tests

REPO_DIR="${0:A:h}"

cd "$REPO_DIR"

# Initialize git repository
git init

# Configure git user for testing
git config user.name "Test User"
git config user.email "test@example.com"

# Create initial commit
echo "# Mock Git Repository for Testing" > README.md
echo "" >> README.md
echo "This is a mock git repository used for testing the Bourgie theme." >> README.md
echo "It contains sample commits, branches, and git states for comprehensive testing." >> README.md

git add README.md
git commit -m "Initial commit"

# Create a few more commits to simulate history
echo "" >> README.md
echo "## Features" >> README.md
echo "- Sample git history" >> README.md
echo "- Multiple branches" >> README.md
echo "- Stash examples" >> README.md

git add README.md
git commit -m "Add features section"

# Create a new branch
git checkout -b feature/test-branch

echo "" >> README.md
echo "## Testing Branch" >> README.md
echo "This content is on the feature branch." >> README.md

git add README.md
git commit -m "Add testing branch content"

# Go back to main and create merge scenario
git checkout main

echo "" >> README.md
echo "## Main Branch Updates" >> README.md
echo "This content is on main branch." >> README.md

git add README.md
git commit -m "Update main branch"

# Create some uncommitted changes
echo "" >> README.md
echo "## Uncommitted Changes" >> README.md
echo "This represents working directory changes." >> README.md

# Create staged changes
echo "test file" > test.txt
git add test.txt

# Create a stash
git stash push -m "Test stash entry"

echo "Mock git repository setup complete!"
echo "Repository location: $REPO_DIR"
echo "Commits: $(git rev-list --count HEAD)"
echo "Branches: $(git branch -l | wc -l)"
echo "Stashes: $(git stash list | wc -l)"