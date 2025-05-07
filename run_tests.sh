#!/bin/bash

# Navigate to the test directory
cd "$(dirname "$0")/layzsh" || exit

# Run the tests using ZUnit
zunit test_toggle_layzsh.zunit
