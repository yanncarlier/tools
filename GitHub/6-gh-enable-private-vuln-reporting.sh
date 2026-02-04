#!/usr/bin/env bash
# 6-gh-enable-private-vuln-reporting.sh
# Summary: Enable GitHub Advanced Security Private Vulnerability Reporting
# for one or more repositories using the GitHub CLI (`gh`).
#
# Prerequisites:
#  - `gh` (GitHub CLI) installed and authenticated: `gh auth login`
#  - Admin access to target repositories and GH Advanced Security available
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 6-gh-enable-private-vuln-reporting.sh

set -euo pipefail

OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}
REPOS_TO_PROCESS=()

echo "Preparing to enable private vulnerability reporting for $OWNER..."

if [ -z "${REPOS}" ]; then
  echo "ERROR: No repositories specified."
  echo "Provide a comma-separated list via the REPOS variable:" \
       "REPOS=\"repo1,repo2\" OWNER=\"username\" bash 6-gh-enable-private-vuln-reporting.sh"
  exit 1
fi

# Split comma-separated string into array and trim whitespace
IFS=',' read -r -a REPOS_ARRAY <<< "$REPOS"
for r in "${REPOS_ARRAY[@]}"; do
  r="${r// /}"
  REPOS_TO_PROCESS+=("$r")
done

count=0
for repo_name in "${REPOS_TO_PROCESS[@]}"; do
  repo="$OWNER/$repo_name"
  echo "=========================================="
  echo "Processing $repo"

  # Skip archived repositories
  archived=$(gh api "repos/$repo" --jq '.archived' 2>/dev/null || echo "false")
  if [ "$archived" = "true" ]; then
    echo "  -> Skipping archived repository"
    continue
  fi

  # Enable private vulnerability reporting via API
  if gh api "repos/$repo/private-vulnerability-reporting" --method PUT -f enabled=true >/dev/null 2>&1; then
    echo "  -> Private vulnerability reporting enabled for $repo"
    count=$((count+1))
  else
    echo "  -> ERROR: Failed to enable private vulnerability reporting for $repo"
  fi
done

echo "=========================================="
echo "Done. Enabled private vulnerability reporting for $count repositories."
