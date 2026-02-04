#!/usr/bin/env bash
# 10-gh-enable-dependabot-security-updates.sh
# Summary: Enable Dependabot security updates (automated security fixes) for one or more repositories
# using the GitHub CLI (`gh`).
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin access to the target repositories
#  - GitHub Advanced Security available for the repository (if applicable)
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 10-gh-enable-dependabot-security-updates.sh

set -euo pipefail

OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}
REPOS_TO_PROCESS=()

echo "Preparing to enable Dependabot security updates for $OWNER..."

if [ -z "${REPOS}" ]; then
  echo "ERROR: No repositories specified."
  echo "Provide a comma-separated list via the REPOS variable:"
  echo "  REPOS=\"repo1,repo2\" OWNER=\"username\" bash 10-gh-enable-dependabot-security-updates.sh"
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

  # Enable Dependabot security updates (automated security fixes) via API
  # The endpoint returns 204 on success
  if gh api "repos/$repo/automated-security-fixes" --method PUT >/dev/null 2>&1; then
    echo "  -> Dependabot security updates enabled for $repo"
    count=$((count+1))
  else
    echo "  -> ERROR: Failed to enable Dependabot security updates for $repo"
  fi
done

echo "=========================================="
echo "Done. Enabled Dependabot security updates for $count repositories."
