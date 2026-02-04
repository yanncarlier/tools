#!/usr/bin/env bash
# 1-gh-setup-dev-branches.sh
# Summary: Ensure a development branch (default: "dev") exists across multiple
# repositories using the GitHub CLI (`gh`).
#
# Prerequisites:
#  - GitHub CLI installed and authenticated: `gh auth login`
#
# Usage:
#  OWNER="username" bash 1-gh-setup-dev-branches.sh
#  OWNER="username" REPOS="repo1,repo2" bash 1-gh-setup-dev-branches.sh
#
# Environment variables:
#  - OWNER: GitHub user/org (default: "username")
#  - DEV_BRANCH: branch name to create (default: "dev")
#  - REPOS: comma-separated list of repos (e.g., "repo1,repo2"). If empty, public repos for OWNER are fetched.

set -euo pipefail

OWNER=${OWNER:-"username"}
DEV_BRANCH="dev"

echo "Fetching repositories for $OWNER..."
if [ -n "${REPOS:-}" ]; then
  # Parse comma-separated REPOS from environment
  echo "Using provided REPOS"
  IFS=',' read -r -a REPOS_ARRAY <<< "$REPOS"
  REPOS=()
  for r in "${REPOS_ARRAY[@]}"; do
    # Trim whitespace and prefix with OWNER if needed
    r="${r// /}"
    if [[ "$r" == *"/"* ]]; then
      REPOS+=("$r")
    else
      REPOS+=("$OWNER/$r")
    fi
  done
else
  # Fetch public repos for OWNER from GitHub
  REPOS=()
  echo "  (fetching public repositories)"
  mapfile -t REPOS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public)
fi
# === PROCESS REPOSITORIES ===
for repo in "${REPOS[@]}"; do
  echo "=========================================="
  echo "Processing $repo"
  
  # Check if dev branch exists
  if ! gh api -X GET "repos/$repo/branches/$DEV_BRANCH" > /dev/null 2>&1; then
    # Branch missing: create from default
    echo "  → Creating branch $DEV_BRANCH from default branch"
    default_branch=$(gh api "repos/$repo" --jq '.default_branch')
    # Fetch commit SHA and create new ref
    gh api "repos/$repo/git/refs" \
      -f ref="refs/heads/$DEV_BRANCH" \
      -f sha="$(gh api repos/$repo/branches/$default_branch --jq '.commit.sha')" > /dev/null
    echo "  → $DEV_BRANCH created"
  else
    # Already exists: skip
    echo "  → $DEV_BRANCH already exists"
  fi
done
echo "=========================================="
echo "All done! $DEV_BRANCH exists across ${#REPOS[@]} repositories for $OWNER."
