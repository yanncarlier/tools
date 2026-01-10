#!/usr/bin/env bash
# 9-gh-enable-dependabot-alerts.sh
# Summary: Enable Dependabot vulnerability alerts for one or more repositories
# using the GitHub CLI (`gh`).
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin access to the target repositories
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 9-gh-enable-dependabot-alerts.sh

set -euo pipefail

OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}
REPOS_TO_PROCESS=()

echo "Preparing to enable Dependabot alerts for $OWNER..."

if [ -z "${REPOS}" ]; then
  echo "ERROR: No repositories specified."
  echo "Provide a comma-separated list via the REPOS variable:"
  echo "  REPOS=\"repo1,repo2\" OWNER=\"username\" bash 9-gh-enable-dependabot-alerts.sh"
  exit 1
fi

# Parse comma-separated REPOS and normalize
IFS=',' read -r -a REPOS_ARRAY <<< "$REPOS"
for r in "${REPOS_ARRAY[@]}"; do
  r="${r// /}"
  if [[ "$r" == *"/"* ]]; then
    REPOS_TO_PROCESS+=("$r")
  else
    REPOS_TO_PROCESS+=("$OWNER/$r")
  fi
done

count=0
for repo in "${REPOS_TO_PROCESS[@]}"; do
  echo "=========================================="
  echo "Processing $repo"

  # Skip archived repositories
  archived=$(gh api "repos/$repo" --jq '.archived' 2>/dev/null || echo "false")
  if [ "$archived" = "true" ]; then
    echo "  -> Skipping archived repository"
    continue
  fi

  # Enable Dependabot alerts via API
  # The vulnerability alerts endpoint historically returns 204 on success
  if gh api "repos/$repo/vulnerability-alerts" --method PUT >/dev/null 2>&1; then
    echo "  -> Dependabot alerts enabled for $repo"
    count=$((count+1))
  else
    echo "  -> ERROR: Failed to enable Dependabot alerts for $repo"
  fi
done

echo "=========================================="
echo "Done. Enabled Dependabot alerts for $count repositories."
