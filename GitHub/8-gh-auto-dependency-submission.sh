#!/usr/bin/env bash
# 8-gh-auto-dependency-submission.sh
# Summary: Submit a dependency snapshot to GitHub's dependency submission API
# for one or more repositories using the GitHub CLI (`gh`). This can be used
# to automate dependency submission when you have a prepared snapshot JSON.
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin or write access to target repositories
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" SNAPSHOT_FILE="./8-test-snapshot.json" bash 8-gh-auto-dependency-submission.sh

set -euo pipefail

OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}
# Default snapshot file (script directory). Can be overridden via SNAPSHOT_FILE env var.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAPSHOT_FILE=${SNAPSHOT_FILE:-"$script_dir/8-test-snapshot.json"}
REPOS_TO_PROCESS=()

if [ -z "$REPOS" ]; then
  echo "ERROR: No repositories specified."
  echo "Usage: REPOS=\"repo1,repo2\" OWNER=\"username\" SNAPSHOT_FILE=\"/path/to/snapshot.json\" bash 8-gh-auto-dependency-submission.sh"
  exit 1
fi

if [ -z "$SNAPSHOT_FILE" ]; then
  echo "ERROR: No snapshot file specified. Provide SNAPSHOT_FILE path to a valid JSON payload."
  exit 1
fi

if [ ! -f "$SNAPSHOT_FILE" ]; then
  echo "ERROR: Snapshot file not found: $SNAPSHOT_FILE"
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
  echo "Submitting snapshot for $repo"

  # Skip archived repositories
  archived=$(gh api "repos/$repo" --jq '.archived' 2>/dev/null || echo "false")
  if [ "$archived" = "true" ]; then
    echo "  -> Skipping archived repository"
    continue
  fi

  # POST the snapshot JSON to the dependency submission endpoint
  if gh api "repos/$repo/dependency-graph/snapshots" --method POST --input "$SNAPSHOT_FILE" >/dev/null 2>&1; then
    echo "  -> Snapshot submitted for $repo"
    count=$((count+1))
  else
    echo "  -> ERROR: Failed to submit snapshot for $repo"
  fi
done

echo "=========================================="
echo "Done. Attempted snapshot submission for $count repositories."
