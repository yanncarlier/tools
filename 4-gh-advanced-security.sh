#!/usr/bin/env bash
# File: 4-gh-advanced-security.sh
# Purpose: Configures GitHub Advanced Security across multiple repositories.
# Enables: Advanced Security, Secret Scanning, Push Protection, Dependabot updates,
# Vulnerability Alerts, CodeQL default-setup, and creates Dependabot/CodeQL workflow files.
#
# Prerequisites: GitHub CLI (gh) authentication with admin access. Run: gh auth login
# Note: Advanced Security requires GitHub Enterprise with GHAS enabled.
#
# Usage Examples:
#   bash 4-gh-advanced-security.sh                                      # hardcoded repos
#   FETCH_ALL_PUBLIC_REPOS=true OWNER="yanncarlier" bash 4-gh-advanced-security.sh
#   FETCH_ALL_PUBLIC_REPOS=true INCLUDE_PRIVATE_REPOS=true OWNER="yanncarlier" bash 4-gh-advanced-security.sh
#   CODEQL_ONLY=true FETCH_ALL_PUBLIC_REPOS=true OWNER="yanncarlier" bash 4-gh-advanced-security.sh  # CodeQL only
#   REPOS_TO_PROCESS=("repo1") OWNER="yanncarlier" bash 4-gh-advanced-security.sh

set -euo pipefail

# === CONFIGURATION ===
# === CONFIGURATION ===
# OWNER: GitHub user or org name (override via environment: OWNER="yanncarlier")
OWNER=${OWNER:-"username"}

# REPOS_TO_PROCESS: List of repos to configure. If empty and FETCH_ALL_PUBLIC_REPOS=true,
# fetches repos from GitHub. Default hardcoded list: ("demo-advanced-security")
# Set via environment: REPOS_TO_PROCESS=("repo1" "repo2") or use FETCH_ALL_PUBLIC_REPOS=true
REPOS_TO_PROCESS=("demo-advanced-security")

# FETCH_ALL_PUBLIC_REPOS: If true, override REPOS_TO_PROCESS and fetch all repos for OWNER
# from GitHub instead of using the hardcoded list.
# Usage: `FETCH_ALL_PUBLIC_REPOS=true OWNER="yanncarlier" bash 4-gh-advanced-security.sh`
if [ "${FETCH_ALL_PUBLIC_REPOS:-false}" = "true" ]; then
  REPOS_TO_PROCESS=()
fi

# INCLUDE_PRIVATE_REPOS: Include private repositories when fetching all repos
# Default: false (public repos only). Set to "true" to include private repos.
# Usage: `FETCH_ALL_PUBLIC_REPOS=true INCLUDE_PRIVATE_REPOS=true OWNER="yanncarlier" bash 4-gh-advanced-security.sh`
INCLUDE_PRIVATE_REPOS=${INCLUDE_PRIVATE_REPOS:-false}

# PROMPT_BEFORE_API: If true, prompt user before each API call (interactive mode)
# Default: false (non-interactive, auto-approve). Usage: `PROMPT_BEFORE_API=true bash 4-gh-advanced-security.sh`
PROMPT_BEFORE_API=${PROMPT_BEFORE_API:-false}

# ENABLE_PRIVATE_VULN_REPORTING: Enable private vulnerability reporting for all repos
# Default: false. Set to true if you want to enable private vuln reporting.
ENABLE_PRIVATE_VULN_REPORTING=false

# CodeQL Configuration (auto-detected per repo language; these are defaults/fallbacks)
# CODEQL_QUERY_SUITE: "default" (recommended) or "security-and-quality"
CODEQL_QUERY_SUITE="default"
# CODEQL_THREAT_MODEL: "remote" or "local" (determines analysis scope)
CODEQL_THREAT_MODEL="remote"
# CODEQL_SCHEDULE: Schedule for periodic CodeQL runs (e.g., "weekly")
CODEQL_SCHEDULE="weekly"

# CODEQL_ONLY: If true, only run CodeQL setup steps; skip other security configurations
# Usage: `CODEQL_ONLY=true FETCH_ALL_PUBLIC_REPOS=true OWNER="yanncarlier" bash 4-gh-advanced-security.sh`
CODEQL_ONLY=${CODEQL_ONLY:-false}

# === FETCH REPOSITORIES ===

echo "Fetching repositories for $OWNER..."
if [ ${#REPOS_TO_PROCESS[@]} -eq 0 ]; then
  if [ "${INCLUDE_PRIVATE_REPOS}" = "true" ]; then
    echo "  (including both public and private repos)"
    mapfile -t REPOS_TO_PROCESS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner')
  else
    echo "  (public repos only; set INCLUDE_PRIVATE_REPOS=true to include private repos)"
    mapfile -t REPOS_TO_PROCESS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public)
  fi
else
  REPOS_TO_PROCESS=( "${REPOS_TO_PROCESS[@]/#/$OWNER/}" )
fi

echo "Found ${#REPOS_TO_PROCESS[@]} repositories to process."
echo "--------------------------------------------------"

for REPO in "${REPOS_TO_PROCESS[@]}"; do
  echo "Processing $REPO"

  # Skip archived or disabled repositories
  archived=false
  if archived=$(gh api "repos/$REPO" --jq '.archived' 2>/dev/null || echo "false"); then
    if [ "$archived" = "true" ]; then
      echo "  -> Skipping archived repository"
      echo "--------------------------------------------------"
      continue
    fi
  fi

  # 1) Enable GitHub Advanced Security / Secret Scanning / Push Protection
  # Skip non-CodeQL steps when CODEQL_ONLY is true
  if [ "${CODEQL_ONLY}" != "true" ]; then
  cat <<EOF > /tmp/advanced-security.json
{
  "security_and_analysis": {
    "advanced_security": { "status": "enabled" },
    "secret_scanning": { "status": "enabled" },
      "secret_scanning_push_protection": { "status": "enabled" },
      "dependabot_version_updates": { "status": "enabled" }
  }
}
EOF

  if [ "$PROMPT_BEFORE_API" = true ]; then
    read -r -p "  -> Will PATCH 'repos/$REPO' to enable security_and_analysis. Proceed? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      if gh api "repos/$REPO" --method PATCH --input /tmp/advanced-security.json >/dev/null 2>&1; then
        echo "  -> security_and_analysis updated (Advanced Security, Secret Scanning, Push Protection requested)"
      else
        echo "  -> ERROR: Failed to update security_and_analysis (you may lack admin access or Advanced Security not available)"
      fi
    else
      echo "  -> Skipped security_and_analysis update"
    fi
  else
    if gh api "repos/$REPO" --method PATCH --input /tmp/advanced-security.json >/dev/null 2>&1; then
      echo "  -> security_and_analysis updated (Advanced Security, Secret Scanning, Push Protection requested)"
    else
      echo "  -> ERROR: Failed to update security_and_analysis (you may lack admin access or Advanced Security not available)"
    fi
  fi

  # 2) Enable Dependabot security updates (Automated security fixes)
  if [ "$PROMPT_BEFORE_API" = true ]; then
    read -r -p "  -> Will PUT 'repos/$REPO/automated-security-fixes' to enable Dependabot updates. Proceed? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      if gh api "repos/$REPO/automated-security-fixes" --method PUT >/dev/null 2>&1; then
        echo "  -> Dependabot security updates enabled"
      else
        echo "  -> WARNING: Could not enable Dependabot security updates"
      fi
    else
      echo "  -> Skipped Dependabot security updates"
    fi
  else
    if gh api "repos/$REPO/automated-security-fixes" --method PUT >/dev/null 2>&1; then
      echo "  -> Dependabot security updates enabled"
    else
      echo "  -> WARNING: Could not enable Dependabot security updates"
    fi
  fi

  # 3) Enable vulnerability alerts (dependency graph & alerts)
  if [ "$PROMPT_BEFORE_API" = true ]; then
    read -r -p "  -> Will PUT 'repos/$REPO/vulnerability-alerts' to enable vulnerability alerts. Proceed? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      if gh api "repos/$REPO/vulnerability-alerts" --method PUT >/dev/null 2>&1; then
        echo "  -> Vulnerability alerts enabled"
      else
        echo "  -> WARNING: Could not enable vulnerability alerts"
      fi
    else
      echo "  -> Skipped vulnerability alerts"
    fi
  else
    if gh api "repos/$REPO/vulnerability-alerts" --method PUT >/dev/null 2>&1; then
      echo "  -> Vulnerability alerts enabled"
    else
      echo "  -> WARNING: Could not enable vulnerability alerts"
    fi
  fi

  # 4) Optionally enable private vulnerability reporting
  if [ "$ENABLE_PRIVATE_VULN_REPORTING" = true ]; then
    if [ "$PROMPT_BEFORE_API" = true ]; then
      read -r -p "  -> Will PUT 'repos/$REPO/private-vulnerability-reporting'. Proceed? [y/N] " yn
      if [[ "$yn" =~ ^[Yy]$ ]]; then
        if gh api "repos/$REPO/private-vulnerability-reporting" --method PUT >/dev/null 2>&1; then
          echo "  -> Private vulnerability reporting enabled"
        else
          echo "  -> WARNING: Could not enable private vulnerability reporting"
        fi
      else
        echo "  -> Skipped private vulnerability reporting"
      fi
    else
      if gh api "repos/$REPO/private-vulnerability-reporting" --method PUT >/dev/null 2>&1; then
        echo "  -> Private vulnerability reporting enabled"
      else
        echo "  -> WARNING: Could not enable private vulnerability reporting"
      fi
    fi
  fi

  fi

  # 5) Configure CodeQL default setup (will queue a validation run)
  # Detect repository languages and only request CodeQL languages present.
  # Use exact JSON key matching and map to CodeQL API language tokens.
  repo_langs_json=$(gh api "repos/$REPO/languages" 2>/dev/null || echo "{}")
  api_langs=()
  # JavaScript / TypeScript -> javascript-typescript
  if echo "$repo_langs_json" | grep -q '"JavaScript"' || echo "$repo_langs_json" | grep -q '"TypeScript"'; then
    api_langs+=("javascript-typescript")
  fi
  # Python
  if echo "$repo_langs_json" | grep -q '"Python"'; then
    api_langs+=("python")
  fi
  # Go
  if echo "$repo_langs_json" | grep -q '"Go"'; then
    api_langs+=("go")
  fi
  # Java (map to java-kotlin)
  if echo "$repo_langs_json" | grep -q '"Java"'; then
    api_langs+=("java-kotlin")
  fi
  # Ruby
  if echo "$repo_langs_json" | grep -q '"Ruby"'; then
    api_langs+=("ruby")
  fi
  # C / C++ (map to c-cpp)
  if echo "$repo_langs_json" | grep -q '"C\+\+"' || echo "$repo_langs_json" | grep -q '"C"'; then
    api_langs+=("c-cpp")
  fi
  # C#
  if echo "$repo_langs_json" | grep -q '"C#"'; then
    api_langs+=("csharp")
  fi

  if [ ${#api_langs[@]} -eq 0 ]; then
    echo "  -> No supported CodeQL languages detected in $REPO; skipping CodeQL default-setup."
    skip_codeql_setup=true
  else
    skip_codeql_setup=false
    # Build JSON array for languages
    languages_json=""
    for lang in "${api_langs[@]}"; do
      languages_json+="\"${lang}\",";
    done
    languages_json="[${languages_json%,}]"
  fi

  if [ "$skip_codeql_setup" = false ]; then
    cat <<EOF > /tmp/codeql-default-setup.json
{
  "state": "configured",
  "query_suite": "$CODEQL_QUERY_SUITE",
  "threat_model": "$CODEQL_THREAT_MODEL",
  "languages": $languages_json
}
EOF

    # Configure CodeQL default setup (will queue a validation run). We'll request it
    # and then poll the `code-scanning/default-setup` state until it becomes
    # 'configured' or until we time out. If polling fails, we dispatch the
    # CodeQL workflow once to attempt to trigger analysis.
    do_codeql_setup() {
      local tmpresp
      tmpresp=$(mktemp)
      if gh api "repos/$REPO/code-scanning/default-setup" --method PATCH --input /tmp/codeql-default-setup.json >"$tmpresp" 2>&1; then
        echo "  -> CodeQL default setup requested (server accepted request). Polling status..."
        # Poll for state change
        attempts=20
        sleep_seconds=6
        while [ $attempts -gt 0 ]; do
          state=$(gh api "repos/$REPO/code-scanning/default-setup" --jq '.state' 2>/dev/null || echo "error")
          echo "    -> current state: $state"
          if [ "$state" = "configured" ]; then
            echo "  -> CodeQL default-setup is now configured"
            rm -f "$tmpresp"
            return 0
          fi
          attempts=$((attempts-1))
          sleep $sleep_seconds
        done
        echo "  -> CodeQL default-setup did not reach 'configured' within timeout. You can check Actions logs at: https://github.com/$REPO/actions"
        echo "    -> Server response (first 400 chars):"
        head -c 400 "$tmpresp" || true
        # Try dispatching the CodeQL workflow to kick analysis
        echo "  -> Attempting to dispatch CodeQL workflow to run now..."
        if gh workflow run codeql-analysis.yml --repo "$REPO" >/dev/null 2>&1; then
          echo "  -> Dispatched CodeQL workflow; check Actions in the repo."
        else
          echo "  -> WARNING: Could not dispatch CodeQL workflow via GH CLI. Run it manually in the Actions UI."
        fi
        rm -f "$tmpresp"
        return 1
      else
        echo "  -> WARNING: CodeQL default setup request failed (see server response)"
        echo "    -> Response (first 400 chars):"
        head -c 400 "$tmpresp" || true
        rm -f "$tmpresp"
        return 2
      fi
    }
  fi

  if [ "$skip_codeql_setup" = true ]; then
    echo "  -> Skipping CodeQL default setup for $REPO"
  else
    if [ "$PROMPT_BEFORE_API" = true ]; then
      read -r -p "  -> Will PATCH 'repos/$REPO/code-scanning/default-setup' to configure CodeQL. Proceed? [y/N] " yn
      if [[ "$yn" =~ ^[Yy]$ ]]; then
        do_codeql_setup || true
      else
        echo "  -> Skipped CodeQL default setup"
      fi
    else
      do_codeql_setup || true
    fi
  fi

  # (non-CodeQL steps were skipped when CODEQL_ONLY=true)

  echo "  -> Security page: https://github.com/$REPO/security"
  echo "--------------------------------------------------"
done

rm -f /tmp/advanced-security.json /tmp/codeql-default-setup.json
echo "✅ ALL DONE! Advanced Security configuration attempted for ${#REPOS_TO_PROCESS[@]} repositories."

# If called with CODEQL_ONLY=true we stop here (we only ran CodeQL steps).
if [ "${CODEQL_ONLY}" = "true" ]; then
  echo "CODEQL_ONLY=true — skipping file creation and other non-CodeQL steps."
  exit 0
fi

# -----------------------------------------------------------------------------
# Additional repository files: Dependabot config and CodeQL workflow
# These help enable Automatic dependency submission / Dependabot version updates
# and add a CodeQL analysis workflow file. The script will create or update
# the files in each target repository (prompting before each change).
# -----------------------------------------------------------------------------

DEPENDABOT_YML=$(cat <<'YML'
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
open-pull-requests-limit: 5
YML
)

# Note: This Dependabot config opens PRs for package updates. This script does not
# perform any automatic merging — Dependabot will only open PRs per this config.

CODEQL_YML=$(cat <<'YML'
name: "CodeQL"

on:
  push:
    branches: [ main, master, dev ]
  pull_request:
    # The branches below must be a subset of the branches above
    branches: [ main, master, dev ]
  schedule:
    - cron: '0 2 * * 1'

jobs:
  analyze:
    name: Analyze
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v2
        with:
          languages: javascript,python

      - name: Autobuild
        uses: github/codeql-action/autobuild@v2

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v2
YML
)

for REPO in "${REPOS_TO_PROCESS[@]}"; do
  # Prepare full repo path (ensure owner/ prefix)
  if [[ "$REPO" != *"/"* ]]; then
    REPO="$OWNER/$REPO"
  fi

  echo "Preparing repository files for $REPO"

  # Dependabot config
  DEP_PATH=".github/dependabot.yml"
  DEP_SHA=$(gh api repos/$REPO/contents/$DEP_PATH --jq '.sha' 2>/dev/null || true)
  DEP_B64=$(printf '%s' "$DEPENDABOT_YML" | base64 | tr -d '\n')

  if [ "$PROMPT_BEFORE_API" = true ]; then
    read -r -p "  -> Will create/update '$DEP_PATH' in $REPO. Proceed? [y/N] " yn
  else
    yn=y
  fi
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    if [ -n "$DEP_SHA" ]; then
      if gh api repos/$REPO/contents/$DEP_PATH --method PUT -f message="chore: update Dependabot config" -f content="$DEP_B64" -f sha="$DEP_SHA" >/dev/null 2>&1; then
        echo "  -> Updated $DEP_PATH"
      else
        echo "  -> WARNING: Failed to update $DEP_PATH"
      fi
    else
      if gh api repos/$REPO/contents/$DEP_PATH --method PUT -f message="chore: add Dependabot config" -f content="$DEP_B64" >/dev/null 2>&1; then
        echo "  -> Created $DEP_PATH"
      else
        echo "  -> WARNING: Failed to create $DEP_PATH"
      fi
    fi
  else
    echo "  -> Skipped $DEP_PATH"
  fi

  # CodeQL workflow
  WF_PATH=".github/workflows/codeql-analysis.yml"
  WF_SHA=$(gh api repos/$REPO/contents/$WF_PATH --jq '.sha' 2>/dev/null || true)
  WF_B64=$(printf '%s' "$CODEQL_YML" | base64 | tr -d '\n')

  if [ "$PROMPT_BEFORE_API" = true ]; then
    read -r -p "  -> Will create/update '$WF_PATH' in $REPO. Proceed? [y/N] " yn
  else
    yn=y
  fi
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    if [ -n "$WF_SHA" ]; then
      if gh api repos/$REPO/contents/$WF_PATH --method PUT -f message="chore: update CodeQL workflow" -f content="$WF_B64" -f sha="$WF_SHA" >/dev/null 2>&1; then
        echo "  -> Updated $WF_PATH"
      else
        echo "  -> WARNING: Failed to update $WF_PATH"
      fi
    else
      if gh api repos/$REPO/contents/$WF_PATH --method PUT -f message="chore: add CodeQL workflow" -f content="$WF_B64" >/dev/null 2>&1; then
        echo "  -> Created $WF_PATH"
      else
        echo "  -> WARNING: Failed to create $WF_PATH"
      fi
    fi
  else
    echo "  -> Skipped $WF_PATH"
  fi

  echo "Finished preparing $REPO"
  # Renovate workflow: create a workflow that runs Renovate on demand to open PRs
  RENOVATE_PATH=".github/workflows/renovate.yml"
  RENOVATE_YML=$(cat <<'YML'
name: "Run Renovate"

on:
  workflow_dispatch:

jobs:
  renovate:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - name: Run Renovate
        uses: renovatebot/github-action@v36.46.2
        with:
          # uses GITHUB_TOKEN by default
          token: ${{ secrets.GITHUB_TOKEN }}
YML
)

  REN_SHA=$(gh api repos/$REPO/contents/$RENOVATE_PATH --jq '.sha' 2>/dev/null || true)
  REN_B64=$(printf '%s' "$RENOVATE_YML" | base64 | tr -d '\n')
  if [ "$PROMPT_BEFORE_API" = true ]; then
    read -r -p "  -> Will create/update '$RENOVATE_PATH' in $REPO. Proceed? [y/N] " yn
  else
    yn=y
  fi
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    if [ -n "$REN_SHA" ]; then
      if gh api repos/$REPO/contents/$RENOVATE_PATH --method PUT -f message="chore: update Renovate workflow" -f content="$REN_B64" -f sha="$REN_SHA" >/dev/null 2>&1; then
        echo "  -> Updated $RENOVATE_PATH"
      else
        echo "  -> WARNING: Failed to update $RENOVATE_PATH"
      fi
    else
      if gh api repos/$REPO/contents/$RENOVATE_PATH --method PUT -f message="chore: add Renovate workflow" -f content="$REN_B64" >/dev/null 2>&1; then
        echo "  -> Created $RENOVATE_PATH"
      else
        echo "  -> WARNING: Failed to create $RENOVATE_PATH"
      fi
    fi

    # Dispatch the workflow to run now
    echo "  -> Dispatching Renovate workflow to run now..."
    if gh workflow run renovate.yml --repo $REPO >/dev/null 2>&1; then
      echo "  -> Renovate workflow dispatched (check Actions in the repo)."
    else
      echo "  -> WARNING: Could not dispatch Renovate workflow via GH CLI. You can run it manually in the Actions UI."
    fi
  else
    echo "  -> Skipped $RENOVATE_PATH"
  fi
  echo "--------------------------------------------------"

  # Attempt organization-level Automatic Dependency Submission once
  if [ -z "${_AUTOMATIC_DEP_SUBMISSION_ATTEMPTED:-}" ]; then
    _AUTOMATIC_DEP_SUBMISSION_ATTEMPTED=1
    # Determine if OWNER is an organization
    if gh api "orgs/$OWNER" >/dev/null 2>&1; then
      echo "Attempting to enable Automatic dependency submission at organization level for '$OWNER'..."
      # Candidate endpoints to try (best-effort; GitHub may reject unsupported endpoints)
      endpoints=(
        "orgs/$OWNER/dependabot/automated-dependency-submission"
        "orgs/$OWNER/dependabot/automated-dependency-updates"
        "orgs/$OWNER/automated-dependency-submission"
        "orgs/$OWNER/automated-dependency-updates"
      )
      success=false
      for ep in "${endpoints[@]}"; do
        if [ "$PROMPT_BEFORE_API" = true ]; then
          read -r -p "  -> Will PUT '$ep' to enable Automatic dependency submission. Proceed? [y/N] " yn
          if [[ ! "$yn" =~ ^[Yy]$ ]]; then
            echo "  -> Skipped $ep"
            continue
          fi
        fi
        if gh api "$ep" --method PUT >/dev/null 2>&1; then
          echo "  -> Automatic dependency submission enabled via '$ep'"
          success=true
          break
        else
          echo "  -> Attempt to enable via '$ep' failed (endpoint may not exist or you lack permissions)"
        fi
      done
      if [ "$success" = false ]; then
        echo "  -> Automatic dependency submission could not be enabled via API."
        echo "     If you are an organization admin, enable it in GitHub: Settings → Code security and analysis → Automatic dependency submission"
      fi
    else
      echo "Owner '$OWNER' is not an organization or org query failed; skipping org-level Automatic dependency submission."
    fi
  fi
done

echo "All repository file changes attempted. Review the repositories on GitHub to confirm." 
