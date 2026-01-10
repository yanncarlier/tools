#!/usr/bin/env bash
# 2-gh-delete-rulesets.sh
# Summary: Remove all repository rulesets (branch protection rules) for a set
# of repositories using the GitHub CLI. This permanently deletes rulesets.
#
# Prerequisites:
#  - `gh` installed and authenticated with admin access to target repos.
#
# Usage:
#  OWNER="username" bash 2-gh-delete-rulesets.sh
#  OWNER="username" REPOS="repo1,repo2" bash 2-gh-delete-rulesets.sh
#
# WARNING: This script deletes rulesets and cannot be undone. Review target
# repositories carefully before running.

set -euo pipefail

# === CONFIGURATION ===
OWNER=${OWNER:-"username"}

echo "Fetching repositories for $OWNER..."
if [ -n "${REPOS:-}" ]; then
  # Parse comma-separated REPOS from environment
  echo "Using provided REPOS"
  IFS=',' read -r -a REPOS_ARRAY <<< "$REPOS"
  REPOS_TO_PROCESS=()
  for r in "${REPOS_ARRAY[@]}"; do
    # Trim whitespace and prefix with OWNER if needed
    r="${r// /}"
    if [[ "$r" == *"/"* ]]; then
      REPOS_TO_PROCESS+=("$r")
    else
      REPOS_TO_PROCESS+=("$OWNER/$r")
    fi
  done
else
  # Fetch public repos for OWNER
  echo "  (fetching public repositories)"
  mapfile -t REPOS_TO_PROCESS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public)
fi

echo "Found ${#REPOS_TO_PROCESS[@]} repositories to process."
echo "⚠️  WARNING: This script will DELETE ALL rulesets in these repositories!"
echo "--------------------------------------------------"

# === PROCESS REPOSITORIES ===
for REPO in "${REPOS_TO_PROCESS[@]}"; do
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
