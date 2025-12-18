#!/usr/bin/env bash
# File: 1-gh-setup-dev-branches.sh
# Run with: bash 1-gh-setup-dev-branches.sh

set -euo pipefail

# REQUIRED: You must be authenticated with GitHub CLI
# Run `gh auth login` first if you haven't

# --- Configuration ---
# Your GitHub username
OWNER="yanncarlier"

# Target specific repo as requested
# REPOS=("yanncarlier/tools")
# Name of the development branch you want everywhere
DEV_BRANCH="dev"
# Optional: list of repos (if empty, script will fetch all repos you have admin access to)
REPOS_TO_PROCESS=()
echo "Fetching repositories for $OWNER..."
if [ ${#REPOS_TO_PROCESS[@]} -eq 0 ]; then
  mapfile -t REPOS_TO_PROCESS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner')
else
  # Convert "repo-name" into "owner/repo-name" if needed
  REPOS_TO_PROCESS=( "${REPOS_TO_PROCESS[@]/#/$OWNER/}" )
fi
for repo in "${REPOS_TO_PROCESS[@]}"; do
  echo "=========================================="
  echo "Processing $repo"
  # 1. Create dev branch if it doesn't exist (from main/master/default branch)
  if ! gh api -X GET "repos/$repo/branches/$DEV_BRANCH" > /dev/null 2>&1; then
    echo "  → Creating branch $DEV_BRANCH from default branch"
    default_branch=$(gh api "repos/$repo" --jq '.default_branch')
    gh api "repos/$repo/git/refs" \
      -f ref="refs/heads/$DEV_BRANCH" \
      -f sha="$(gh api repos/$repo/branches/$default_branch --jq '.commit.sha')" > /dev/null
    echo "  → $DEV_BRANCH created"
  else
    echo "  → $DEV_BRANCH already exists"
  fi
done
echo "=========================================="
echo "All done! $DEV_BRANCH exists and $OWNER across ${#REPOS_TO_PROCESS[@]} repositories."
