# GitHub Tools Repository

A collection of Bash scripts to automate GitHub repository management and security configuration across multiple repositories using the GitHub CLI (`gh`).

## Prerequisites

- **GitHub CLI**: Install from [cli.github.com](https://cli.github.com)
- **Authentication**: Run `gh auth login` and authenticate with your GitHub account
- **Token Scopes**: 
  - `repo` (for public repos)
  - `read:org` (for organization data)
  - `admin:repo_hook` (for repository webhooks)
  - Ensure private repo access if using `INCLUDE_PRIVATE_REPOS=true`
- **Permissions**: Admin or write access to target repositories

---

## Scripts Overview

### 1. `1-gh-setup-dev-branches.sh`
**Purpose**: Creates a consistent development branch across multiple repositories.

Creates a `dev` branch (or custom name via `DEV_BRANCH`) from each repository's default branch. Useful for establishing a standard branching strategy across your project landscape.

**Quick Start**:
```bash
# Process public repos only
bash 1-gh-setup-dev-branches.sh

# Include private repos
INCLUDE_PRIVATE_REPOS=true bash 1-gh-setup-dev-branches.sh

# Target specific owner
OWNER="username" INCLUDE_PRIVATE_REPOS=true bash 1-gh-setup-dev-branches.sh
```

**Configuration**:
- `OWNER`: GitHub user or org name (default: `"username"` — override via env)
- `DEV_BRANCH`: Branch name to create (default: `"dev"`)
- `REPOS_TO_PROCESS`: Specific repos to target; if empty, fetches from GitHub
- `INCLUDE_PRIVATE_REPOS`: Include private repos when fetching (default: `false`)

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
# Process public repos only
bash 2-gh-delete-ruleset-branches.sh

# Include private repos
INCLUDE_PRIVATE_REPOS=true bash 2-gh-delete-ruleset-branches.sh

# Target specific owner
OWNER="username" INCLUDE_PRIVATE_REPOS=true bash 2-gh-delete-ruleset-branches.sh
```

**Configuration**:
- `OWNER`: GitHub user or org name (default: `"username"` — override via env)
- `INCLUDE_PRIVATE_REPOS`: Include private repos when fetching (default: `false`)

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
# Process public repos only
bash 3-gh-setup-ruleset-branches.sh

# Include private repos
INCLUDE_PRIVATE_REPOS=true bash 3-gh-setup-ruleset-branches.sh

# Target specific owner
OWNER="username" INCLUDE_PRIVATE_REPOS=true bash 3-gh-setup-ruleset-branches.sh

# Target single repo
REPOS="username/my-repo" bash 3-gh-setup-ruleset-branches.sh

# Target multiple repos
REPOS="username/repo1,username/repo2" bash 3-gh-setup-ruleset-branches.sh
```

**Configuration**:
- `OWNER`: GitHub user or org name (default: `"username"` — override via env)
- `REPOS`: Specific repo(s) to target; supports single, comma-separated, or empty (fetch all)
- `INCLUDE_PRIVATE_REPOS`: Include private repos when fetching (default: `false`)

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

### 4. `4-gh-advanced-security.sh`
**Purpose**: Configures comprehensive GitHub Advanced Security across multiple repositories.

Enables repository-level security features, Dependabot configuration, and CodeQL analysis with automatic language detection.

**Quick Start**:
```bash
# Configure hardcoded repos only
bash 4-gh-advanced-security.sh

# Configure all public repos for owner
FETCH_ALL_PUBLIC_REPOS=true OWNER="username" bash 4-gh-advanced-security.sh

# Include private repos
FETCH_ALL_PUBLIC_REPOS=true INCLUDE_PRIVATE_REPOS=true OWNER="username" bash 4-gh-advanced-security.sh

# CodeQL setup only (skip other steps)
CODEQL_ONLY=true FETCH_ALL_PUBLIC_REPOS=true OWNER="username" bash 4-gh-advanced-security.sh

# Interactive mode (prompt before each change)
PROMPT_BEFORE_API=true FETCH_ALL_PUBLIC_REPOS=true OWNER="username" bash 4-gh-advanced-security.sh
```

**Configuration**:
- `OWNER`: GitHub user or org name (default: `"username"` — override via env)
- `REPOS_TO_PROCESS`: Specific repos; if empty and `FETCH_ALL_PUBLIC_REPOS=true`, fetches all
- `FETCH_ALL_PUBLIC_REPOS`: Fetch all repos from GitHub instead of using hardcoded list
- `INCLUDE_PRIVATE_REPOS`: Include private repos (default: `false`)
- `PROMPT_BEFORE_API`: Interactive mode; prompt before each API call (default: `false`)
- `CODEQL_ONLY`: Run only CodeQL setup; skip other security configs (default: `false`)
- `ENABLE_PRIVATE_VULN_REPORTING`: Enable private vulnerability reporting (default: `false`)
- `CODEQL_QUERY_SUITE`: `"default"` or `"security-and-quality"` (default: `"default"`)
- `CODEQL_THREAT_MODEL`: `"remote"` or `"local"` (default: `"remote"`)

**What It Does**:

1. **Repository-Level Security**:
   - Enables Advanced Security (requires GHAS license)
   - Enables Secret Scanning
   - Enables Secret Scanning Push Protection
   - Enables Dependabot version updates

2. **Dependabot**:
   - Enables automated security fixes
   - Enables vulnerability alerts
   - Creates/updates `.github/dependabot.yml` config (npm, pip, github-actions)

3. **CodeQL**:
   - Auto-detects repository languages
   - Maps languages to CodeQL API tokens (`javascript-typescript`, `python`, `go`, `java-kotlin`, `ruby`, `c-cpp`, `csharp`)
   - Configures CodeQL default-setup with best-fit query suite
   - Creates/updates `.github/workflows/codeql-analysis.yml` workflow
   - Polls until CodeQL reaches `"configured"` state
   - Dispatches workflow if configuration pending

4. **Renovate** (optional):
   - Creates `.github/workflows/renovate.yml` (on-demand dispatch)

**Automatic Language Detection**:
The script automatically detects repo languages and enables CodeQL for supported languages:
- JavaScript/TypeScript → `javascript-typescript`
- Python → `python`
- Go → `go`
- Java → `java-kotlin`
- Ruby → `ruby`
- C/C++ → `c-cpp`
- C# → `csharp`

---

### 5. `5-gh-copilot-code-review.sh`
**Purpose**: Configures GitHub Copilot Code Review rulesets for automated PR analysis.

Sets up rulesets to enforce Copilot-powered code reviews and static analysis on pull requests targeting the default branch. Admins can bypass rules when needed for emergency deployments.

**Quick Start**:
```bash
# Configure all public repos
FETCH_ALL_PUBLIC_REPOS=true OWNER="username" bash 5-gh-copilot-code-review.sh

# Include private repos
FETCH_ALL_PUBLIC_REPOS=true INCLUDE_PRIVATE_REPOS=true OWNER="username" bash 5-gh-copilot-code-review.sh

# Target single repo
REPOS="username/my-repo" bash 5-gh-copilot-code-review.sh

# Target multiple repos
REPOS="username/repo1,username/repo2" bash 5-gh-copilot-code-review.sh

# Interactive mode (confirm before each change)
PROMPT_BEFORE_API=true FETCH_ALL_PUBLIC_REPOS=true OWNER="username" bash 5-gh-copilot-code-review.sh
```

**Configuration**:
- `OWNER`: GitHub user or org name (default: `"username"` — override via env)
- `REPOS`: Specific repo(s) to target; supports single, comma-separated, or empty (fetch all)
- `FETCH_ALL_PUBLIC_REPOS`: Fetch all repos from GitHub instead of hardcoded list
- `INCLUDE_PRIVATE_REPOS`: Include private repos when fetching (default: `false`)
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
# Configure all public repos with Advanced Security
FETCH_ALL_PUBLIC_REPOS=true OWNER="username" bash 4-gh-advanced-security.sh

# Configure all public + private repos
FETCH_ALL_PUBLIC_REPOS=true INCLUDE_PRIVATE_REPOS=true OWNER="username" bash 4-gh-advanced-security.sh

# Setup Copilot Code Review on all repos
FETCH_ALL_PUBLIC_REPOS=true INCLUDE_PRIVATE_REPOS=true OWNER="username" bash 5-gh-copilot-code-review.sh
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

# Multiple repos with advanced security
REPOS_TO_PROCESS=("repo1" "repo2") OWNER="username" bash 4-gh-advanced-security.sh
```

### Interactive Mode (Confirm Each Change)
```bash
# Prompt before each API call (works with any script)
PROMPT_BEFORE_API=true FETCH_ALL_PUBLIC_REPOS=true OWNER="username" bash 4-gh-advanced-security.sh
PROMPT_BEFORE_API=true FETCH_ALL_PUBLIC_REPOS=true OWNER="username" bash 5-gh-copilot-code-review.sh
```

### CodeQL Re-Configuration
```bash
# Re-run CodeQL setup for all public repos
CODEQL_ONLY=true FETCH_ALL_PUBLIC_REPOS=true OWNER="username" bash 4-gh-advanced-security.sh

# Re-run CodeQL for specific repo
CODEQL_ONLY=true REPOS="username/my-repo" bash 4-gh-advanced-security.sh
```

### Combined Security Setup
```bash
# Full security stack: dev branches + rulesets + advanced security + Copilot Code Review
OWNER="username" INCLUDE_PRIVATE_REPOS=true bash 1-gh-setup-dev-branches.sh
REPOS="username/my-repo" bash 3-gh-setup-ruleset-branches.sh
REPOS_TO_PROCESS=("my-repo") OWNER="username" bash 4-gh-advanced-security.sh
REPOS="username/my-repo" bash 5-gh-copilot-code-review.sh
```

---

## Environment Variables Reference

### Universal (All Scripts)
- `OWNER`: GitHub user or organization name
- `INCLUDE_PRIVATE_REPOS`: Include private repositories (`true`/`false`)

### Script 1: `1-gh-setup-dev-branches.sh`
- `DEV_BRANCH`: Name of dev branch to create (default: `"dev"`)
- `REPOS_TO_PROCESS`: Specific repos to target

### Script 2: `2-gh-delete-ruleset-branches.sh`
- (Only uses `OWNER` and `INCLUDE_PRIVATE_REPOS`)

### Script 3: `3-gh-setup-ruleset-branches.sh`
- `REPOS`: Single or comma-separated repo list (e.g., `"owner/repo1,owner/repo2"`)

### Script 4: `4-gh-advanced-security.sh`
- `FETCH_ALL_PUBLIC_REPOS`: Fetch all repos from GitHub (`true`/`false`)
- `PROMPT_BEFORE_API`: Interactive mode (`true`/`false`)
- `CODEQL_ONLY`: Run only CodeQL setup (`true`/`false`)
- `ENABLE_PRIVATE_VULN_REPORTING`: Enable private vuln reporting (`true`/`false`)
- `CODEQL_QUERY_SUITE`: `"default"` or `"security-and-quality"`
- `CODEQL_THREAT_MODEL`: `"remote"` or `"local"`
- `REPOS_TO_PROCESS`: Specific repos to target

### Script 5: `5-gh-copilot-code-review.sh`
- `FETCH_ALL_PUBLIC_REPOS`: Fetch all repos from GitHub (`true`/`false`)
- `INCLUDE_PRIVATE_REPOS`: Include private repos when fetching (`true`/`false`)
- `PROMPT_BEFORE_API`: Interactive mode (`true`/`false`)
- `REPOS`: Single or comma-separated repo list (e.g., `"owner/repo1,owner/repo2"`)
- `RULESET_NAME`: Name of Copilot ruleset (default: `"copilot-code-review-default"`)
- `ENABLE_DISMISS_STALE_APPROVALS`: Auto-dismiss stale reviews (`true`/`false`)

---

## Troubleshooting

### "the owner handle 'username' was not recognized"
- **Cause**: Script is using hardcoded `"username"` instead of actual owner name
- **Fix**: Set `OWNER` environment variable: `OWNER="username" bash script.sh`

### "CodeQL default-setup did not reach 'configured' state"
- **Cause**: CodeQL configuration pending or validation running
- **Fix**: 
  - Check repo Actions tab for ongoing workflows
  - Re-run script after 1-2 minutes
  - Use `CODEQL_ONLY=true` to focus on CodeQL setup

### "Failed to enable Advanced Security"
- **Cause**: Repository may not have GHAS license, or insufficient permissions
- **Fix**: 
  - Verify organization has GitHub Enterprise with GHAS enabled
  - Confirm user has admin access to repo
  - Try `PROMPT_BEFORE_API=true` for detailed error messages

### "No supported CodeQL languages detected"
- **Cause**: Repository uses languages CodeQL doesn't support yet
- **Fix**: Script will skip CodeQL; other security features still apply

---

## Notes

- All scripts run non-interactively by default. Use `PROMPT_BEFORE_API=true` for confirmation prompts.
- Failed API calls are reported but do not stop script execution.
- Archived repositories are automatically skipped.
- Scripts support up to 1000 repositories per owner (GitHub API limit).
- Created files (`.github/dependabot.yml`, workflows) are committed directly; consider creating a PR instead.

---

## License

MIT (or as specified in your repository)

---

## Support

For issues or questions:
1. Check script comments for detailed explanations
2. Run with `PROMPT_BEFORE_API=true` to see detailed error messages
3. Verify GitHub CLI authentication: `gh auth status`
4. Check repository Actions tab for workflow logs
