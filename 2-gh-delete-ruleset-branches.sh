#!/usr/bin/env bash
# File: 2-gh-delete-ruleset-branches.sh
# Purpose: Deletes all repository rulesets from specified repositories.
# Rulesets are GitHub branch protection rules (require PR reviews, block deletions, etc.).
# Use this to reset protection policies or prepare for fresh configuration.
#
# Prerequisites: GitHub CLI (gh) authentication with admin access. Run: gh auth login
# ⚠️  WARNING: This script DELETES all rulesets. Use with caution!
#
# Usage Examples:
#   bash 2-gh-delete-ruleset-branches.sh                           # public repos
#   INCLUDE_PRIVATE_REPOS=true bash 2-gh-delete-ruleset-branches.sh   # include private
#   OWNER="username" INCLUDE_PRIVATE_REPOS=true bash 2-gh-delete-ruleset-branches.sh

set -euo pipefail

# === CONFIGURATION ===
# OWNER: GitHub user or org name (override via environment: OWNER="username")
OWNER=${OWNER:-"username"}

# === FETCH REPOSITORIES ===
# INCLUDE_PRIVATE_REPOS: Include private repositories when fetching all repos
# Default: false (public repos only). Set to "true" to include private repos.
# Requires gh CLI token with private repo access scope.
INCLUDE_PRIVATE_REPOS=${INCLUDE_PRIVATE_REPOS:-false}

if [ "${INCLUDE_PRIVATE_REPOS}" = "true" ]; then
  echo "Fetching repositories for $OWNER (including private repositories)..."
  # Fetch all repos (public + private) for the owner without visibility filter
  mapfile -t REPOS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner')
else
  echo "Fetching public repositories for $OWNER..."
  # Fetch only public repos for the owner
  mapfile -t REPOS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public)
fi

echo "Found ${#REPOS[@]} repositories to process."
echo "⚠️  WARNING: This script will DELETE ALL rulesets in these repositories!"
echo "--------------------------------------------------"

# === PROCESS REPOSITORIES ===
for REPO in "${REPOS[@]}"; do
  echo "Processing $REPO..."

  # Fetch all ruleset IDs for this repository
  # GitHub API returns an array of rulesets; extract the .id field from each
  RULESET_IDS=$(gh api "repos/$REPO/rulesets" --jq '.[] | .id // empty')

  if [[ -z "$RULESET_IDS" ]]; then
    echo "  -> No rulesets found."
  else
    # Iterate through each ruleset ID and delete it
    while IFS= read -r ID; do
      if [[ -n "$ID" ]]; then
        echo "  -> Deleting ruleset ID: $ID"
        # Call DELETE on the ruleset endpoint; on success, report completion
        if gh api "repos/$REPO/rulesets/$ID" --method DELETE >/dev/null 2>&1; then
          echo "  -> SUCCESS: Ruleset $ID deleted."
        else
          echo "  -> ERROR: Failed to delete ruleset $ID. Skipping."
        fi
      fi
    done <<< "$RULESET_IDS"
  fi

  echo "--------------------------------------------------"
done

echo "✅ ALL DONE! Ruleset cleanup complete for all processed repositories."