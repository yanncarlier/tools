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
#   INCLUDE_PRIVATE_REPOS=true bash 1-gh-setup-dev-branches.sh   # include private repos
#   OWNER="yanncarlier" INCLUDE_PRIVATE_REPOS=true bash 1-gh-setup-dev-branches.sh
#
# Notes:
#   - Use OWNER env var to override the hardcoded owner (repo must exist for authenticated user)
#   - INCLUDE_PRIVATE_REPOS=true fetches all repos (requires gh token with repo scope)
#   - Dev branch is created from the repository's default branch (main/master)
#   - If dev branch already exists, the script skips creation and reports success

set -euo pipefail

# === CONFIGURATION ===
# OWNER: GitHub user or org name (override via environment: OWNER="yanncarlier")
OWNER=${OWNER:-"username"}

# DEV_BRANCH: Name of the branch to create in all repositories (default: 'dev')
# This branch is created from the repository's default branch
DEV_BRANCH="dev"

# REPOS_TO_PROCESS: Specific repos to target. If empty, fetches all repos for OWNER.
# Examples: REPOS_TO_PROCESS=("repo1" "repo2") or set via env: REPOS_TO_PROCESS="repo1,repo2"
REPOS_TO_PROCESS=()

# INCLUDE_PRIVATE_REPOS: Include private repositories when fetching all repos
# Default: false (public repos only). Set to "true" to include private repos.
# Requires gh CLI token with private repo access scope.
INCLUDE_PRIVATE_REPOS=${INCLUDE_PRIVATE_REPOS:-false}
# === FETCH REPOSITORIES ===
echo "Fetching repositories for $OWNER..."
if [ ${#REPOS_TO_PROCESS[@]} -eq 0 ]; then
  # No repos specified: fetch from GitHub based on INCLUDE_PRIVATE_REPOS flag
  if [ "${INCLUDE_PRIVATE_REPOS}" = "true" ]; then
    echo "  (including private repositories)"
    # Fetch all repos (public + private) for the owner without visibility filter
    mapfile -t REPOS_TO_PROCESS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner')
  else
    echo "  (public repositories only; set INCLUDE_PRIVATE_REPOS=true to include private repos)"
    # Fetch only public repos for the owner
    mapfile -t REPOS_TO_PROCESS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public)
  fi
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
