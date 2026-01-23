# AGENTS.md - GitHub Tools Repository Guidelines

This document provides guidelines for AI agents working on this Bash scripts repository for GitHub repository management.

## Build, Lint, and Test Commands

### Building Scripts
```bash
# Make all scripts executable
chmod +x *.sh

# Verify scripts are executable
ls -la *.sh
```

### Linting
```bash
# Install shellcheck for syntax checking
# Ubuntu/Debian: sudo apt-get install shellcheck
# macOS: brew install shellcheck

# Lint all scripts
shellcheck *.sh

# Lint a specific script
shellcheck script-name.sh

# Lint with additional checks (warnings, style)
shellcheck -x *.sh  # Allow external sources
shellcheck -s bash *.sh  # Specify bash dialect
```

### Testing
```bash
# Manual testing - run scripts with dry-run mode where available
# Most scripts support environment variables for testing

# Test a specific script (example with mock data)
OWNER="testuser" REPOS="test-repo" bash script-name.sh

# Test GitHub API calls without actual execution
# Use gh api commands directly for validation
gh api "repos/testuser/test-repo" --jq '.name'

# For automated testing, consider bats framework
# Install: https://github.com/bats-core/bats-core
# Example test structure:
# test/test_script.bats

# Run all tests
bats test/

# Run specific test file
bats test/script-name.bats

# Run single test
bats test/script-name.bats -f "test_function_name"
```

### Development Workflow
```bash
# 1. Make changes to script
# 2. Run shellcheck
shellcheck script-name.sh

# 3. Test with mock data
OWNER="testuser" REPOS="test-repo" bash script-name.sh

# 4. Verify GitHub CLI authentication
gh auth status

# 5. Test API calls manually
gh api "repos/testuser/test-repo/branches" --jq '.[].name'
```

## Code Style Guidelines

### Script Structure

All scripts must follow this consistent structure:

```bash
#!/usr/bin/env bash
# script-name.sh
# Summary: Brief description of what the script does
#
# Prerequisites:
#  - Required tools and authentication
#
# Usage:
#  OWNER="username" bash script-name.sh
#  OWNER="username" REPOS="repo1,repo2" bash script-name.sh
#
# Environment variables:
#  - OWNER: GitHub user/org (default: "username")
#  - REPOS: Comma-separated list of repos

set -euo pipefail

# === CONFIGURATION ===
OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}

# === FUNCTIONS ===
usage() {
    echo "Usage: ${0##*/} [options]"
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message"
    exit 1
}

error() {
    echo "ERROR: $*" >&2
    exit 1
}

warning() {
    echo "WARNING: $*" >&2
}

# === MAIN LOGIC ===
# Script implementation here

echo "Script completed successfully"
```

### File Organization

- **Shebang**: Always use `#!/usr/bin/env bash`
- **Header Comments**: Include summary, prerequisites, usage examples, and environment variables
- **Configuration Section**: Group all environment variable defaults at the top
- **Functions Section**: Define helper functions before main logic
- **Main Logic**: Process repositories in a loop with clear progress indicators
- **Exit Status**: Use appropriate exit codes (0 for success, 1 for errors)

### Naming Conventions

#### Script Files
- **Format**: `number-description.sh` (e.g., `1-gh-setup-dev-branches.sh`)
- **Prefix**: Sequential numbers for logical ordering
- **Description**: Hyphen-separated, descriptive action words
- **Extension**: Always `.sh`

#### Variables
- **Environment Variables**: `UPPERCASE_WITH_UNDERSCORES` (e.g., `OWNER`, `REPOS`)
- **Local Variables**: `lowercase_with_underscores` (e.g., `repo_name`, `default_branch`)
- **Arrays**: `UPPERCASE_ARRAY` (e.g., `REPOS_TO_PROCESS`)
- **Constants**: `UPPERCASE_CONSTANTS` (e.g., `RULESET_NAME`)

#### Functions
- **Format**: `lowercase_with_underscores` (e.g., `process_repository`, `validate_input`)
- **Purpose**: Single responsibility, clear naming
- **Prefix**: Avoid unnecessary prefixes (no `fn_` or `func_`)

### Error Handling

```bash
# Always use strict mode
set -euo pipefail

# -e: Exit on any command failure
# -u: Exit on undefined variables
# -o pipefail: Exit on pipeline failures

# Handle errors gracefully
if ! command_exists "gh"; then
    error "GitHub CLI (gh) is not installed. Install from https://cli.github.com"
fi

# Validate required environment variables
if [ -z "${OWNER:-}" ]; then
    error "OWNER environment variable is required"
fi

# Check API responses
if ! response=$(gh api "repos/$repo" 2>/dev/null); then
    warning "Failed to fetch repository info for $repo"
    continue
fi
```

### GitHub API Usage

```bash
# Authentication check
gh auth status >/dev/null || error "GitHub CLI not authenticated. Run 'gh auth login'"

# Safe API calls with error handling
if ! default_branch=$(gh api "repos/$repo" --jq '.default_branch' 2>/dev/null); then
    warning "Could not determine default branch for $repo"
    continue
fi

# Batch operations with rate limiting consideration
for repo in "${REPOS[@]}"; do
    echo "Processing $repo..."
    # Add sleep if needed for rate limiting
    # sleep 1
done

# JSON processing with jq
repo_count=$(gh repo list "$OWNER" --json nameWithOwner -q 'length')
archived=$(gh api "repos/$repo" --jq '.archived')
```

### Input Validation and Security

```bash
# Validate repository names
validate_repo_name() {
    local repo="$1"
    if [[ ! "$repo" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
        error "Invalid repository name format: $repo (expected: owner/repo)"
    fi
}

# Sanitize inputs
clean_input() {
    local input="$1"
    # Remove leading/trailing whitespace
    input="${input#"${input%%[![:space:]]*}"}"
    input="${input%"${input##*[![:space:]]}"}"
    echo "$input"
}

# Process comma-separated lists safely
IFS=',' read -r -a REPOS_ARRAY <<< "$REPOS"
for r in "${REPOS_ARRAY[@]}"; do
    r=$(clean_input "$r")
    validate_repo_name "$r"
    REPOS_TO_PROCESS+=("$r")
done
```

### Logging and Output

```bash
# Consistent progress indicators
echo "=========================================="
echo "Processing $repo"
echo "=========================================="

# Status messages
echo "  → Creating branch $DEV_BRANCH from default branch"
echo "  → $DEV_BRANCH created"
echo "  → $DEV_BRANCH already exists"

# Error reporting
echo "ERROR: Failed to create ruleset (Validation error likely). Check the JSON payload."

# Success confirmation
echo "All done! $DEV_BRANCH exists across ${#REPOS[@]} repositories for $OWNER."
```

### Documentation Standards

```bash
# Header comment format
#!/usr/bin/env bash
# script-name.sh
# Summary: One-line description of script purpose
#
# Prerequisites:
#  - Required tools, permissions, and setup
#  - Authentication requirements
#
# Usage:
#  Basic usage example
#  Advanced usage with all options
#
# Environment variables:
#  - VAR_NAME: Description and default value
#  - ANOTHER_VAR: Description and expected format
#
# Examples:
#  OWNER="myorg" bash script-name.sh
#  REPOS="repo1,repo2" OWNER="myorg" bash script-name.sh
```

### Dependencies and Prerequisites

- **GitHub CLI**: Assume `gh` is available and authenticated
- **External Tools**: `jq` for JSON processing (commonly available)
- **Permissions**: Scripts require appropriate GitHub permissions
- **Rate Limiting**: Consider GitHub API rate limits in batch operations

### Code Comments

```bash
# Use comments for complex logic
# Group related operations
# === CONFIGURATION ===  # Section headers
# === MAIN LOGIC ===

# Inline comments for non-obvious operations
mapfile -t REPOS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public)  # Fetch public repos

# Avoid obvious comments
# count = count + 1  # Increment counter (unnecessary)
count=$((count+1))  # Increment success counter
```

### Testing Guidelines

- **Manual Testing**: Always test with mock data before production use
- **Environment Variables**: Use test values that don't affect real repositories
- **API Validation**: Test GitHub API calls independently
- **Error Scenarios**: Test failure cases and edge conditions
- **Cleanup**: Ensure test repositories can be safely modified

### Security Considerations

- **Input Validation**: Never trust user input, validate all parameters
- **API Tokens**: Use `gh auth login`, never hardcode tokens
- **Permissions**: Scripts require specific GitHub permissions - document them
- **Destructive Operations**: Warn about irreversible actions (deleting rulesets, etc.)
- **Audit Trail**: Log all API operations for debugging

This document ensures consistent, maintainable, and secure Bash scripting practices across the repository.</content>
<parameter name="filePath">/home/y/MY_PROJECTS/tools/AGENTS.md