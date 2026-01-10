

# GitHub Tools Repository

Use at Your Own Risk
This is experimental/beta software. It may contain bugs or cause unexpected behavior.
No warranties are provided. Use entirely at your own discretion and risk.

A collection of Bash scripts to automate GitHub repository management and security configuration across multiple repositories using the GitHub CLI (`gh`).

## Prerequisites

- **GitHub CLI**: Install from [cli.github.com](https://cli.github.com)
- **Authentication**: Run `gh auth login` and authenticate with your GitHub account
- **Token Scopes**: 
  - `repo` (for public repos)
  - `read:org` (for organization data)
  - `admin:repo_hook` (for repository webhooks)
- **Permissions**: Admin or write access to target repositories

---

## Scripts Overview

### 1. `1-gh-setup-dev-branches.sh`
**Purpose**: Creates a consistent development branch across multiple repositories.

Creates a `dev` branch (or custom name via `DEV_BRANCH`) from each repository's default branch. Useful for establishing a standard branching strategy across your project landscape.

**Quick Start**:
```bash
# Process public repos
bash 1-gh-setup-dev-branches.sh

# Target specific owner
OWNER="username" bash 1-gh-setup-dev-branches.sh
```

**Configuration**:
- `OWNER`: GitHub user or org name (default: `"username"` — override via env)
- `DEV_BRANCH`: Branch name to create (default: `"dev"`)
- `REPOS_TO_PROCESS`: Specific repos to target; if empty, fetches public repos from GitHub

**What It Does**:
1. Fetches repositories for the specified owner (public or public+private)
2. For each repo, checks if `DEV_BRANCH` exists
3. If missing, creates it from the repository's default branch
4. Reports success or skips if branch already exists

---

### 2. `2-gh-delete-ruleset-branches.sh`
**Purpose**: Deletes all repository rulesets (branch protection rules).

Rulesets define branch protection policies (require PR reviews, block deletions, etc.). Use this script to reset protection policies or prepare for fresh configuration.

**⚠️ Warning**: This script **permanently deletes** all rulesets. Use with caution!

**Quick Start**:
```bash
# Process public repos
bash 2-gh-delete-ruleset-branches.sh

# Target specific owner
OWNER="username" bash 2-gh-delete-ruleset-branches.sh
```

**Configuration**:
- `OWNER`: GitHub user or org name (default: `"username"` — override via env)

**What It Does**:
1. Fetches repositories for the specified owner
2. For each repo, fetches all ruleset IDs
3. Deletes each ruleset
4. Reports success/error for each deletion

---

### 3. `3-gh-setup-ruleset-branches.sh`
**Purpose**: Creates a `dev` branch and sets up repository rulesets with branch protection.

Combines branch creation with ruleset setup. Enforces branch protection policies (require PR reviews, block force pushes, etc.) while allowing repository admins to bypass rules when needed.

**Quick Start**:
```bash
# Process public repos
bash 3-gh-setup-ruleset-branches.sh

# Target specific owner
OWNER="username" bash 3-gh-setup-ruleset-branches.sh

# Target single repo
REPOS="username/my-repo" bash 3-gh-setup-ruleset-branches.sh

# Target multiple repos
REPOS="username/repo1,username/repo2" bash 3-gh-setup-ruleset-branches.sh
```

**Configuration**:
- `OWNER`: GitHub user or org name (default: `"username"` — override via env)
- `REPOS`: Specific repo(s) to target; supports single, comma-separated, or empty (fetch public repos)

**What It Does**:
1. Creates `dev` branch from default branch (if not exists)
2. Deletes any existing ruleset with name `"protect-default-branch"`
3. Creates new ruleset with:
   - **Enforcement**: Active (not advisory)
   - **Target**: Default branch (`~DEFAULT_BRANCH`)
   - **Rules**:
     - Require pull requests (with dismissal of stale reviews on push)
     - Require code owner review
     - Block deletions
     - Block non-fast-forward pushes
   - **Bypass**: Repository admins (ID 5) can always bypass

**Ruleset Details**:
- Protects the default branch (main/master) and `dev` branch
- Blocks direct pushes; requires PR-based merges
- Requires at least one approval
- Automatically dismiss stale reviews when new commits pushed
- Admin users can bypass all rules

---

### 4. `4-gh-disable-codeql.sh`
**Purpose**: Disables CodeQL code scanning across multiple repositories.

Disables CodeQL default setup and optionally removes custom CodeQL workflow files from specified repositories.

**Quick Start**:
```bash
# Disable CodeQL for specific repos
REPOS="repo1 repo2 repo3" OWNER="username" bash 4-gh-disable-codeql.sh

# Disable CodeQL for all public repos and delete workflows
FETCH_ALL_REPOS=true OWNER="username" DELETE_CODEQL_WORKFLOW=true bash 4-gh-disable-codeql.sh

# Interactive mode (prompt before each change)
PROMPT_BEFORE_API=true REPOS="repo1" OWNER="username" bash 4-gh-disable-codeql.sh
```

**Configuration**:
- `OWNER`: GitHub user or org name (default: `"username"` — override via env)
- `REPOS`: Space-separated list of repo names (no owner prefix)
- `FETCH_ALL_REPOS`: Fetch all public repos from GitHub instead of using REPOS list (default: `false`)
- `PROMPT_BEFORE_API`: Interactive mode; prompt before each API call (default: `false`)
- `DELETE_CODEQL_WORKFLOW`: Also delete `.github/workflows/codeql-analysis.yml` files (default: `false`)

**What It Does**:

1. **Disable CodeQL Default Setup**:
   - Sets CodeQL state to "not-configured" via GitHub API
   - Only affects repositories where CodeQL is currently enabled

2. **Optional Workflow Deletion**:
   - Removes custom CodeQL workflow files if `DELETE_CODEQL_WORKFLOW=true`
   - Commits the deletion with message "chore: remove CodeQL workflow"

**Notes**:
- Existing CodeQL alerts remain until manually dismissed
- If issues persist, disable manually in repository settings under Code security and analysis → Code scanning

---

### 5. `5-gh-copilot-code-review.sh`
**Purpose**: Configures GitHub Copilot Code Review rulesets for automated PR analysis.

Sets up rulesets to enforce Copilot-powered code reviews and static analysis on pull requests targeting the default branch. Admins can bypass rules when needed for emergency deployments.

**Quick Start**:
```bash
# Configure all public repos
FETCH_ALL_REPOS=true OWNER="username" bash 5-gh-copilot-code-review.sh

# Target single repo
REPOS="username/my-repo" bash 5-gh-copilot-code-review.sh

# Target multiple repos
REPOS="username/repo1,username/repo2" bash 5-gh-copilot-code-review.sh

# Interactive mode (confirm before each change)
PROMPT_BEFORE_API=true FETCH_ALL_REPOS=true OWNER="username" bash 5-gh-copilot-code-review.sh
```

**Configuration**:
- `OWNER`: GitHub user or org name (default: `"username"` — override via env)
- `REPOS`: Specific repo(s) to target; supports single, comma-separated, or empty (fetch public repos)
- `FETCH_ALL_REPOS`: Fetch all public repos from GitHub instead of hardcoded list (default: `false`)
- `PROMPT_BEFORE_API`: Interactive mode; prompt before each API call (default: `false`)
- `RULESET_NAME`: Name of the Copilot ruleset (default: `"copilot-code-review-default"`)
- `ENABLE_DISMISS_STALE_APPROVALS`: Auto-dismiss reviews on new commits (default: `true`)

**What It Does**:
1. Skips archived repositories
2. Verifies Copilot is enabled in the organization
3. Deletes any existing Copilot Code Review ruleset with the same name
4. Creates a new ruleset with:
   - **Target**: Default branch (`~DEFAULT_BRANCH`)
   - **Enforcement**: Active (required, not advisory)
   - **Rules**:
     - Require Copilot code review on all PRs
     - Auto-dismiss stale reviews when new commits pushed
     - Require review thread resolution before merge
     - Disallow automatic approval after initial feedback
   - **Bypass**: Repository admins (ID 5) can always bypass the requirement

**Requirements**:
- Organization must have **GitHub Copilot Enterprise** or **GitHub Copilot Team** enabled
- Script will warn if Copilot is not detected but will attempt setup
- Admin access to target repositories

---

## Common Usage Patterns

### Batch Configuration for All Personal Repos
```bash
# Disable CodeQL for all public repos
FETCH_ALL_REPOS=true OWNER="username" bash 4-gh-disable-codeql.sh

# Setup Copilot Code Review on all repos
FETCH_ALL_REPOS=true OWNER="username" bash 5-gh-copilot-code-review.sh
```

### Target Specific Repositories
```bash
# Single repo with ruleset and branch
REPOS="username/my-repo" bash 3-gh-setup-ruleset-branches.sh

# Single repo with Copilot Code Review
REPOS="username/my-repo" bash 5-gh-copilot-code-review.sh

# Multiple repos
REPOS="username/repo1,username/repo2,username/repo3" bash 3-gh-setup-ruleset-branches.sh

# Multiple repos with Copilot Code Review
REPOS="username/repo1,username/repo2" bash 5-gh-copilot-code-review.sh
README
======

Small collection of Bash helper scripts for managing GitHub repositories and
related system tasks. Use with care — some scripts perform destructive actions.

Prerequisites
-------------
- Install GitHub CLI: https://cli.github.com
- Authenticate: `gh auth login`
- Have appropriate permissions (admin/write) for targeted repositories

Quick start
-----------
Run a script with an OWNER or REPOS environment variable. Examples:

    OWNER="my-org" bash 1-gh-setup-dev-branches.sh
    REPOS="repo1 repo2" OWNER="my-user" bash 4-gh-disable-codeql.sh

Scripts
-------
- `1-gh-setup-dev-branches.sh` — ensure a `dev` branch (or custom name) exists.
- `2-gh-delete-rulesets.sh` — delete all repository rulesets (destructive).
- `3-gh-setup-rulesets.sh` — create/replace branch protection rulesets.
- `4-gh-disable-codeql.sh` — disable CodeQL default setup; optionally remove workflows.
- `5-gh-copilot-code-review.sh` — create Copilot Code Review rulesets (requires Copilot).
- `delete_all_containers.sh` — stop/remove Docker containers, images, volumes (destructive).
- `disable_services_ubuntu24.sh` — disable a list of services on Ubuntu 24.04.
- `git_fetch_pull_all_subfolders.sh` — run `git fetch` and `git pull` in subfolders.
- `rename_directory.sh` — rename a directory to uppercase.

Caution
-------
- Review scripts before running. Several are destructive (delete rulesets, Docker images,
  or disable services).
- Use `PROMPT_BEFORE_API=true` where supported to enable interactive confirmations.

Support
-------
- Check individual script headers for usage and environment variables.
- Verify `gh auth status` before running GitHub-related scripts.

License
-------
MIT
- `OWNER`: GitHub user or organization name
