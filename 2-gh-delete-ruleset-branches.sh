#!/usr/bin/env bash
# File: 2-gh-delete-ruleset-branches.sh
# Run with: bash 2-gh-delete-ruleset-branches.sh

set -euo pipefail

# REQUIRED: You must be authenticated with GitHub CLI
# Run 'gh auth login' first if you haven't

# --- Configuration ---
# Your GitHub username 
OWNER="username" # Change this if necessary

# --- Fetch Repositories ---
echo "Fetching ALL *PUBLIC* repositories for $OWNER..."
# Add '--visibility public' to the list command
mapfile -t REPOS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public) 

echo "Found ${#REPOS[@]} repositories to process."
echo "⚠️ WARNING: This script will DELETE ALL rulesets in these repositories!"
echo "--------------------------------------------------"

# --- Processing Loop ---
for REPO in "${REPOS[@]}"; do
  echo "Processing $REPO..."

  # 1. Fetch ALL Ruleset IDs for the current repository
  # We use the corrected JQ filter to handle the root-level array.
  # We want a stream of all IDs, so we use '.[] | .id'
  RULESET_IDS=$(gh api "repos/$REPO/rulesets" --jq '.[] | .id // empty')

  if [[ -z "$RULESET_IDS" ]]; then
    echo "  -> No rulesets found."
  else
    # 2. Iterate through the stream of IDs and delete each one
    while IFS= read -r ID; do
      if [[ -n "$ID" ]]; then
        echo "  -> Deleting ruleset ID: $ID"
        # The DELETE method only requires the ruleset ID in the path
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