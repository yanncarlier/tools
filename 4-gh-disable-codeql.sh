#!/usr/bin/env bash
# File: disable-codeql.sh
# Purpose: Disables CodeQL code scanning across multiple repositories.
# This includes:
# - Disabling CodeQL default setup (if enabled) via API using {"state": "not-configured"}.
# - Optionally deleting any custom CodeQL workflow file (.github/workflows/codeql-analysis.yml) if it exists.
#
# Prerequisites: GitHub CLI (gh) authenticated with repo access.
#                Run: gh auth login
#
# Usage Examples:
#   REPOS="tools" OWNER="username" DELETE_CODEQL_WORKFLOW=true bash disable-codeql.sh
#   REPOS="repo1 repo2 repo3" OWNER="username" bash disable-codeql.sh
#   FETCH_ALL_PUBLIC_REPOS=true OWNER="username" DELETE_CODEQL_WORKFLOW=true bash disable-codeql.sh
#   PROMPT_BEFORE_API=true REPOS="tools" bash disable-codeql.sh

set -euo pipefail

# === CONFIGURATION WITH PLACEHOLDERS ===
# Replace or override these via environment variables when running the script

OWNER=${OWNER:-"username"}                    # GitHub username or organization
REPOS=${REPOS:-""}                            # Space-separated list of repo names (no owner prefix)
FETCH_ALL_PUBLIC_REPOS=${FETCH_ALL_PUBLIC_REPOS:-false}
INCLUDE_PRIVATE_REPOS=${INCLUDE_PRIVATE_REPOS:-false}
PROMPT_BEFORE_API=${PROMPT_BEFORE_API:-false}
DELETE_CODEQL_WORKFLOW=${DELETE_CODEQL_WORKFLOW:-false}

# === FETCH REPOSITORIES ===
echo "Fetching repositories for $OWNER..."

REPOS_TO_PROCESS=()

if [ "${FETCH_ALL_PUBLIC_REPOS}" = "true" ]; then
  if [ "${INCLUDE_PRIVATE_REPOS}" = "true" ]; then
    echo "  (including both public and private repos)"
    mapfile -t REPOS_TO_PROCESS < <(gh repo list "$OWNER" --limit 1000 --json name -q '.[].name')
  else
    echo "  (public repos only)"
    mapfile -t REPOS_TO_PROCESS < <(gh repo list "$OWNER" --limit 1000 --json name -q '.[].name' --visibility public)
  fi
else
  if [ -z "$REPOS" ]; then
    echo "ERROR: No repositories specified."
    echo "Provide a space-separated list via the REPOS variable:"
    echo "  REPOS=\"tools repo2 another-repo\" OWNER=\"username\" bash disable-codeql.sh"
    echo "Or use FETCH_ALL_PUBLIC_REPOS=true to process all repos automatically."
    exit 1
  fi
  # Split space-separated string into array
  IFS=' ' read -ra REPOS_TO_PROCESS <<< "$REPOS"
fi

# Convert to full owner/repo format
FULL_REPOS=()
for repo_name in "${REPOS_TO_PROCESS[@]}"; do
  FULL_REPOS+=("$OWNER/$repo_name")
done

echo "Found ${#FULL_REPOS[@]} repositories to process."
echo "--------------------------------------------------"

for REPO in "${FULL_REPOS[@]}"; do
  echo "Processing $REPO"

  # Skip archived repositories
  archived=$(gh api "repos/$REPO" --jq '.archived' 2>/dev/null || echo "false")
  if [ "$archived" = "true" ]; then
    echo "  -> Skipping archived repository"
    echo "--------------------------------------------------"
    continue
  fi

  # 1) Disable CodeQL default setup if enabled
  current_state=$(gh api "repos/$REPO/code-scanning/default-setup" --jq '.state // "not-configured"' 2>/dev/null || echo "error")

  if [ "$current_state" = "configured" ]; then
    echo "  -> CodeQL default setup is currently enabled. Disabling..."

    cat <<EOF > /tmp/disable-codeql.json
{
  "state": "not-configured"
}
EOF

    if [ "$PROMPT_BEFORE_API" = "true" ]; then
      read -r -p "  -> Disable CodeQL default setup in $REPO? [y/N] " yn
      if [[ ! "$yn" =~ ^[Yy]$ ]]; then
        echo "  -> Skipped"
        rm -f /tmp/disable-codeql.json
        echo "--------------------------------------------------"
        continue
      fi
    fi

    if gh api "repos/$REPO/code-scanning/default-setup" --method PATCH --input /tmp/disable-codeql.json >/dev/null 2>&1; then
      echo "  -> CodeQL default setup disabled successfully"
    else
      echo "  -> ERROR: Failed to disable CodeQL default setup"
    fi
  elif [ "$current_state" = "not-configured" ]; then
    echo "  -> CodeQL default setup is already disabled"
  else
    echo "  -> Unable to query CodeQL state (API error or not eligible)"
  fi

  # 2) Optionally delete custom CodeQL workflow file
  if [ "${DELETE_CODEQL_WORKFLOW}" = "true" ]; then
    WF_PATH=".github/workflows/codeql-analysis.yml"
    WF_SHA=$(gh api "repos/$REPO/contents/$WF_PATH" --jq '.sha // empty' 2>/dev/null || echo "")

    if [ -n "$WF_SHA" ]; then
      echo "  -> Custom CodeQL workflow file found. Deleting..."

      if [ "$PROMPT_BEFORE_API" = "true" ]; then
        read -r -p "  -> Delete $WF_PATH in $REPO? [y/N] " yn
        if [[ ! "$yn" =~ ^[Yy]$ ]]; then
          echo "  -> Skipped"
          echo "--------------------------------------------------"
          continue
        fi
      fi

      if gh api "repos/$REPO/contents/$WF_PATH" --method DELETE -f message="chore: remove CodeQL workflow" -f sha="$WF_SHA" >/dev/null 2>&1; then
        echo "  -> Deleted $WF_PATH successfully"
      else
        echo "  -> WARNING: Failed to delete $WF_PATH"
      fi
    else
      echo "  -> No custom CodeQL workflow file found"
    fi
  fi

  echo "  -> Security page: https://github.com/$REPO/security"
  echo "--------------------------------------------------"
done

rm -f /tmp/disable-codeql.json 2>/dev/null || true

echo "✅ ALL DONE! CodeQL disabling attempted for ${#FULL_REPOS[@]} repositories."
echo "Note: Existing alerts remain until manually dismissed."
echo "      If issues persist, disable manually in repo settings: Code security and analysis → Code scanning → Disable."