#!/usr/bin/env bash
# 7-gh-enable-dependency-graph.sh
# Summary: Enable GitHub dependency graph for one or more repositories using `gh`.
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin access to the target repositories
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 7-gh-enable-dependency-graph.sh

set -euo pipefail

OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}
REPOS_TO_PROCESS=()

echo "Preparing to enable dependency graph for $OWNER..."

if [ -z "${REPOS}" ]; then
  echo "ERROR: No repositories specified."
  echo "Provide a comma-separated list via the REPOS variable:" \
       "REPOS=\"repo1,repo2\" OWNER=\"username\" bash 7-gh-enable-dependency-graph.sh"
  exit 1
fi

# Parse comma-separated REPOS and normalize
IFS=',' read -r -a REPOS_ARRAY <<< "$REPOS"
for r in "${REPOS_ARRAY[@]}"; do
  r="${r// /}"
  # If user provided owner/repo, use as-is; otherwise prefix with OWNER
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

  archived=$(gh api "repos/$repo" --jq '.archived' 2>/dev/null || echo "false")
  if [ "$archived" = "true" ]; then
    echo "  -> Skipping archived repository"
    continue
  fi

  # Attempt to enable dependency graph via API
  if gh api "repos/$repo/dependency-graph" --method PUT -f enabled=true >/dev/null 2>&1; then
    echo "  -> Dependency graph enabled for $repo"
    count=$((count+1))
  else
    echo "  -> ERROR: Failed to enable dependency graph for $repo"
  fi
done

echo "=========================================="
echo "Done. Attempted to enable dependency graph for $count repositories."
