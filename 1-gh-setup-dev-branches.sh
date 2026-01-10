#!/usr/bin/env bash
# File: 1-gh-setup-dev-branches.sh
# Purpose: Creates a development branch (default: 'dev') across multiple repositories.
# This script enables a consistent dev branch across your repository landscape, useful for
# establishing a standard branching strategy across all projects.
#
# Prerequisites: GitHub CLI (gh) authentication. Run: gh auth login
#
# Usage Examples:
#   bash 1-gh-setup-dev-branches.sh                              # public repos only
#   OWNER="username" bash 1-gh-setup-dev-branches.sh
#s
# Notes:
#   - Use OWNER env var to override the hardcoded owner (repo must exist for authenticated user)
#   - Dev branch is created from the repository's default branch (main/master)
#   - If dev branch already exists, the script skips creation and reports success

set -euo pipefail

# === CONFIGURATION ===
# OWNER: GitHub user or org name (override via environment: OWNER="username")
OWNER=${OWNER:-"username"}

# DEV_BRANCH: Name of the branch to create in all repositories (default: 'dev')
# This branch is created from the repository's default branch
DEV_BRANCH="dev"

# REPOS_TO_PROCESS: Specific repos to target. If empty, fetches public repos for OWNER.
# Examples: REPOS_TO_PROCESS=("repo1" "repo2") or set via env: REPOS_TO_PROCESS="repo1,repo2"
REPOS_TO_PROCESS=()

# === FETCH REPOSITORIES ===
echo "Fetching repositories for $OWNER..."
if [ ${#REPOS_TO_PROCESS[@]} -eq 0 ]; then
  # No repos specified: fetch public repositories from GitHub
  echo "  (fetching public repositories)"
  mapfile -t REPOS_TO_PROCESS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public)
else
  # Repos specified in array: add OWNER prefix if not already present (handle "repo" → "owner/repo")
  REPOS_TO_PROCESS=( "${REPOS_TO_PROCESS[@]/#/$OWNER/}" )
fi
# === PROCESS REPOSITORIES ===
for repo in "${REPOS_TO_PROCESS[@]}"; do
  echo "=========================================="
  echo "Processing $repo"
  
  # Check if dev branch already exists via GitHub API
  if ! gh api -X GET "repos/$repo/branches/$DEV_BRANCH" > /dev/null 2>&1; then
    # Branch doesn't exist: create it from the repository's default branch (main/master/etc.)
    echo "  → Creating branch $DEV_BRANCH from default branch"
    default_branch=$(gh api "repos/$repo" --jq '.default_branch')
    # Get the commit SHA of the default branch and create a new ref pointing to it
    gh api "repos/$repo/git/refs" \
      -f ref="refs/heads/$DEV_BRANCH" \
      -f sha="$(gh api repos/$repo/branches/$default_branch --jq '.commit.sha')" > /dev/null
    echo "  → $DEV_BRANCH created"
  else
    # Branch already exists: report and skip
    echo "  → $DEV_BRANCH already exists"
  fi
done
echo "=========================================="
echo "All done! $DEV_BRANCH exists and $OWNER across ${#REPOS_TO_PROCESS[@]} repositories."
