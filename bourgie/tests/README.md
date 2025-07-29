# Bourgie Theme Test Suite

This directory contains comprehensive tests for the Bourgie oh-my-posh theme plugin.

## Test Structure

```
tests/
├── README.md                    # This file
├── run-tests.sh                 # Main test runner script
├── test-framework.sh            # Testing framework utilities
├── unit/                        # Unit tests
│   ├── test-plugin-functions.sh # Tests for individual zsh functions
│   ├── test-environment.sh      # Environment variable tests
│   └── test-config-parser.sh    # Configuration parsing tests
├── integration/                 # Integration tests
│   ├── test-wizard.sh           # Interactive wizard tests
│   ├── test-ohmp-config.sh      # oh-my-posh configuration tests
│   └── test-theme-rendering.sh  # Full theme rendering tests
├── fixtures/                    # Test data and mock files
│   ├── mock-git-repo/           # Mock git repository for testing
│   ├── test-configs/            # Sample configuration files
│   └── expected-outputs/        # Expected test outputs
└── coverage/                    # Test coverage reports
```

## Running Tests

### Run All Tests
```bash
./tests/run-tests.sh
```

### Run Specific Test Categories
```bash
./tests/run-tests.sh unit          # Unit tests only
./tests/run-tests.sh integration   # Integration tests only
./tests/run-tests.sh wizard        # Wizard tests only
```

### Run Individual Test Files
```bash
./tests/unit/test-plugin-functions.sh
./tests/integration/test-wizard.sh
```

## Test Framework

The test suite uses a custom zsh testing framework that provides:

- **Assertions**: `assert_equals`, `assert_contains`, `assert_not_empty`, etc.
- **Mocking**: Mock external commands and environment variables
- **Fixtures**: Reusable test data and configurations
- **Coverage**: Track function and line coverage
- **Reporting**: Colored output with detailed failure information

## Test Categories

### Unit Tests
- Individual function behavior
- Environment variable handling
- Configuration parsing
- Error handling and edge cases

### Integration Tests
- Full theme initialization
- oh-my-posh configuration validation
- Interactive wizard functionality
- Git integration and status display

### Regression Tests
- Template parsing errors (fixed issues)
- Color visibility problems
- Git information display accuracy
- Debug logging functionality

## Test Environment

Tests are designed to run in isolated environments with:
- Temporary directories for file operations
- Mocked external dependencies (git, oh-my-posh, etc.)
- Clean environment variables
- Predictable test data

## Coverage Goals

- **Functions**: 100% of exported functions tested
- **Branches**: 90%+ branch coverage for critical paths
- **Edge Cases**: All error conditions and edge cases covered
- **Integration**: Full wizard and theme rendering workflows tested