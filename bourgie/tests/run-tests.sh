#!/usr/bin/env zsh

# Bourgie Theme Test Runner
# Comprehensive test suite runner with reporting and coverage

set -e  # Exit on error

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
TESTS_DIR="$SCRIPT_DIR"

# Test categories
UNIT_TESTS=("test-plugin-functions.sh" "test-environment.sh")
INTEGRATION_TESTS=("test-ohmp-config.sh" "test-wizard.sh")

# Test results
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
FAILED_TEST_FILES=()

# Configuration
VERBOSE=false
COVERAGE=false
STOP_ON_FAILURE=false
TEST_PATTERN=""
OUTPUT_FORMAT="console"  # console, junit, json

# Parse command line arguments
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -c|--coverage)
                COVERAGE=true
                shift
                ;;
            -s|--stop-on-failure)
                STOP_ON_FAILURE=true
                shift
                ;;
            -p|--pattern)
                TEST_PATTERN="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            unit)
                RUN_UNIT_ONLY=true
                shift
                ;;
            integration)
                RUN_INTEGRATION_ONLY=true
                shift
                ;;
            wizard)
                RUN_WIZARD_ONLY=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help message
function show_help() {
    echo -e "${CYAN}Bourgie Theme Test Runner${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] [CATEGORY]"
    echo ""
    echo -e "${YELLOW}Categories:${NC}"
    echo "  unit          Run only unit tests"
    echo "  integration   Run only integration tests"
    echo "  wizard        Run only wizard tests"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  -v, --verbose         Enable verbose output"
    echo "  -c, --coverage        Generate coverage report"
    echo "  -s, --stop-on-failure Stop on first test failure"
    echo "  -p, --pattern PATTERN Run tests matching pattern"
    echo "  -o, --output FORMAT   Output format (console, junit, json)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0                    # Run all tests"
    echo "  $0 unit               # Run unit tests only"
    echo "  $0 -v -c              # Run all tests with verbose output and coverage"
    echo "  $0 -p plugin          # Run tests matching 'plugin' pattern"
}

# Print header
function print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                          🧪 Bourgie Theme Test Suite                            ║${NC}"
    echo -e "${CYAN}║                         Comprehensive Testing Framework                          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Project Directory: ${PROJECT_DIR}${NC}"
    echo -e "${BLUE}Test Directory:    ${TESTS_DIR}${NC}"
    echo -e "${BLUE}Date:              $(date)${NC}"
    echo ""
}

# Check prerequisites
function check_prerequisites() {
    echo -e "${BLUE}🔍 Checking Prerequisites...${NC}"
    
    # Check if zsh is available
    if ! command -v zsh >/dev/null 2>&1; then
        echo -e "${RED}❌ zsh is required but not installed${NC}"
        return 1
    fi
    
    # Check if project files exist
    if [[ ! -f "$PROJECT_DIR/bourgie.plugin.zsh" ]]; then
        echo -e "${RED}❌ bourgie.plugin.zsh not found in project directory${NC}"
        return 1
    fi
    
    if [[ ! -f "$PROJECT_DIR/posh-config.yaml" ]]; then
        echo -e "${RED}❌ posh-config.yaml not found in project directory${NC}"
        return 1
    fi
    
    # Check if test framework exists
    if [[ ! -f "$TESTS_DIR/test-framework.sh" ]]; then
        echo -e "${RED}❌ test-framework.sh not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites met${NC}"
    echo ""
}

# Run a single test file
function run_test_file() {
    local test_file="$1"
    local test_path="$2"
    local category="$3"
    
    echo -e "${MAGENTA}📋 Running: $category/$test_file${NC}"
    
    # Check if test file exists
    if [[ ! -f "$test_path" ]]; then
        echo -e "${RED}❌ Test file not found: $test_path${NC}"
        ((TOTAL_FAILED++))
        FAILED_TEST_FILES+=("$category/$test_file (file not found)")
        return 1
    fi
    
    # Make test file executable
    chmod +x "$test_path"
    
    # Run the test
    local output
    local exit_code
    
    if [[ "$VERBOSE" == "true" ]]; then
        # Run with full output
        "$test_path"
        exit_code=$?
    else
        # Capture output and show summary
        output=$("$test_path" 2>&1)
        exit_code=$?
        
        # Parse test results from output
        local passed=$(echo "$output" | grep -o "✅ Passed: [0-9]*" | grep -o "[0-9]*" || echo "0")
        local failed=$(echo "$output" | grep -o "❌ Failed: [0-9]*" | grep -o "[0-9]*" || echo "0")
        local skipped=$(echo "$output" | grep -o "⏭️  Skipped: [0-9]*" | grep -o "[0-9]*" || echo "0")
        
        ((TOTAL_PASSED += passed))
        ((TOTAL_FAILED += failed))
        ((TOTAL_SKIPPED += skipped))
        
        if [[ $exit_code -eq 0 ]]; then
            echo -e "${GREEN}  ✅ Passed: $passed, Failed: $failed, Skipped: $skipped${NC}"
        else
            echo -e "${RED}  ❌ Passed: $passed, Failed: $failed, Skipped: $skipped${NC}"
            FAILED_TEST_FILES+=("$category/$test_file")
            
            # Show failure details if verbose or stop on failure
            if [[ "$VERBOSE" == "true" ]] || [[ "$STOP_ON_FAILURE" == "true" ]]; then
                echo -e "${RED}Failure output:${NC}"
                echo "$output"
            fi
        fi
    fi
    
    echo ""
    
    # Stop on failure if requested
    if [[ $exit_code -ne 0 ]] && [[ "$STOP_ON_FAILURE" == "true" ]]; then
        echo -e "${RED}🛑 Stopping on first failure${NC}"
        exit 1
    fi
    
    return $exit_code
}

# Run unit tests
function run_unit_tests() {
    echo -e "${YELLOW}🔬 Running Unit Tests${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for test_file in "${UNIT_TESTS[@]}"; do
        # Skip if pattern doesn't match
        if [[ -n "$TEST_PATTERN" ]] && [[ "$test_file" != *"$TEST_PATTERN"* ]]; then
            continue
        fi
        
        run_test_file "$test_file" "$TESTS_DIR/unit/$test_file" "unit"
    done
}

# Run integration tests
function run_integration_tests() {
    echo -e "${YELLOW}🔧 Running Integration Tests${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for test_file in "${INTEGRATION_TESTS[@]}"; do
        # Skip if pattern doesn't match
        if [[ -n "$TEST_PATTERN" ]] && [[ "$test_file" != *"$TEST_PATTERN"* ]]; then
            continue
        fi
        
        run_test_file "$test_file" "$TESTS_DIR/integration/$test_file" "integration"
    done
}

# Generate coverage report
function generate_coverage() {
    if [[ "$COVERAGE" != "true" ]]; then
        return
    fi
    
    echo -e "${BLUE}📊 Generating Coverage Report${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local coverage_dir="$TESTS_DIR/coverage"
    mkdir -p "$coverage_dir"
    
    # Simple function coverage analysis
    local plugin_file="$PROJECT_DIR/bourgie.plugin.zsh"
    local functions_total=0
    local functions_tested=0
    
    # Count total functions
    functions_total=$(grep -c "^function " "$plugin_file" || echo "0")
    
    # Count tested functions (simple heuristic based on test files)
    local test_files=("$TESTS_DIR"/unit/*.sh "$TESTS_DIR"/integration/*.sh)
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            # Look for function calls in test files
            local tested_funcs=$(grep -o "_bourgie_[a-zA-Z_]*\|bourgie_[a-zA-Z_]*" "$test_file" 2>/dev/null | sort -u | wc -l)
            ((functions_tested += tested_funcs))
        fi
    done
    
    # Avoid division by zero and double counting
    if [[ $functions_total -gt 0 ]]; then
        functions_tested=$((functions_tested > functions_total ? functions_total : functions_tested))
        local coverage_percent=$(( (functions_tested * 100) / functions_total ))
        
        echo "📋 Coverage Summary:"
        echo "  Total Functions: $functions_total"
        echo "  Tested Functions: $functions_tested"
        echo "  Coverage: ${coverage_percent}%"
        
        # Save coverage report
        {
            echo "# Bourgie Theme Test Coverage Report"
            echo "Generated: $(date)"
            echo ""
            echo "## Summary"
            echo "- Total Functions: $functions_total"
            echo "- Tested Functions: $functions_tested"
            echo "- Coverage Percentage: ${coverage_percent}%"
            echo ""
            echo "## Function Analysis"
            grep "^function " "$plugin_file" | sed 's/^function /- /' | sed 's/() {//'
        } > "$coverage_dir/coverage-report.md"
        
        echo "📁 Coverage report saved to: $coverage_dir/coverage-report.md"
    else
        echo "⚠️  Could not determine function coverage"
    fi
    
    echo ""
}

# Print final summary
function print_summary() {
    echo -e "${CYAN}📊 Test Results Summary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local total_tests=$((TOTAL_PASSED + TOTAL_FAILED + TOTAL_SKIPPED))
    
    echo -e "${GREEN}✅ Passed:  $TOTAL_PASSED${NC}"
    echo -e "${RED}❌ Failed:  $TOTAL_FAILED${NC}"
    echo -e "${YELLOW}⏭️  Skipped: $TOTAL_SKIPPED${NC}"
    echo -e "${BLUE}📋 Total:   $total_tests${NC}"
    
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed Test Files:${NC}"
        for failed_file in "${FAILED_TEST_FILES[@]}"; do
            echo -e "${RED}  ❌ $failed_file${NC}"
        done
    fi
    
    echo ""
    
    # Calculate success rate
    if [[ $total_tests -gt 0 ]]; then
        local success_rate=$(( (TOTAL_PASSED * 100) / total_tests ))
        echo -e "${BLUE}Success Rate: ${success_rate}%${NC}"
    fi
    
    echo ""
    
    if [[ $TOTAL_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}💥 Some tests failed!${NC}"
        return 1
    fi
}

# Main execution
function main() {
    parse_args "$@"
    
    print_header
    check_prerequisites || exit 1
    
    # Determine which tests to run
    if [[ "$RUN_UNIT_ONLY" == "true" ]]; then
        run_unit_tests
    elif [[ "$RUN_INTEGRATION_ONLY" == "true" ]]; then
        run_integration_tests
    elif [[ "$RUN_WIZARD_ONLY" == "true" ]]; then
        run_test_file "test-wizard.sh" "$TESTS_DIR/integration/test-wizard.sh" "integration"
    else
        # Run all tests
        run_unit_tests
        run_integration_tests
    fi
    
    generate_coverage
    
    local exit_code=0
    print_summary || exit_code=1
    
    exit $exit_code
}

# Run main function with all arguments
main "$@"