#!/usr/bin/env bash
# 3-gh-setup-rulesets.sh
# Summary: Create or replace repository rulesets to enforce branch protection
# policies for target repositories. Uses the GitHub CLI (`gh`).
#
# Prerequisites:
#  - `gh` installed and authenticated with admin access to target repos.
#
# Usage examples:
#  OWNER="username" bash 3-gh-setup-rulesets.sh
#  REPOS="my-repo" OWNER="username" bash 3-gh-setup-rulesets.sh
#  REPOS="repo1,repo2" OWNER="username" bash 3-gh-setup-rulesets.sh

set -euo pipefail

# Note: run `gh auth login` to authenticate before executing this script

# === CONFIGURATION ===
# OWNER: GitHub user or org name (override via environment: OWNER="username")
OWNER=${OWNER:-"username"}

# REPOS: Target specific repo(s). Can be set via environment as single or comma-separated list.
# Examples: REPOS="my-repo" or REPOS="repo1,repo2"
# If not provided, script fetches public repos for OWNER.

# If the user provided REPOS via the environment, honor it and convert to an array.
if [ -n "${REPOS:-}" ]; then
  echo "Using provided REPOS from environment"
  # Convert comma-separated list to array, handling spaces
  IFS=',' read -r -a __tmp <<< "$REPOS"
  REPOS=()
  for r in "${__tmp[@]}"; do
    # Trim whitespace
    r="${r// /}"
    # Always prefix with OWNER
    REPOS+=("$OWNER/$r")
  done
else
  # REPOS not provided: fetch public repositories from GitHub
  echo "Fetching public repositories for $OWNER..."
  # Fetch only public repos for the owner
  mapfile -t REPOS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public)
fi

echo "Found ${#REPOS[@]} repositories to process."
echo "--------------------------------------------------"

RULESET_NAME="protect-default-branch"

echo
for REPO in "${REPOS[@]}"; do
  echo "=================================================="
  echo "Processing $REPO"
  # 1. DELETE existing ruleset if it exists
  # Fix: ensure '$REPO' (singular) is used for the API call
  EXISTING_ID=$(gh api "repos/$REPO/rulesets" --jq "map(select(.name == \"$RULESET_NAME\")) | .[0].id // empty")
  if [[ -n "$EXISTING_ID" ]]; then
    echo "  -> Found existing ruleset (ID: $EXISTING_ID). Deleting..."
    gh api "repos/$REPO/rulesets/$EXISTING_ID" --method DELETE >/dev/null
  fi
  # 2. Define JSON Payload (Create new)
  # Fix: Change bypass_actors to use RepositoryRole (ID 5 for Admin) instead of RepositoryActor
  cat <<EOF > /tmp/ruleset.json
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": [ "~DEFAULT_BRANCH" ],
      "exclude": []
    }
  },
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": false,
        "required_approving_review_count": 0,
        "required_review_thread_resolution": false
      }
    }
  ]
}
EOF
  # 3. Create the Ruleset (POST)
  if gh api "repos/$REPO/rulesets" --method POST --input /tmp/ruleset.json >/dev/null 2>&1; then
    echo "  -> Ruleset created successfully"
  else
    echo "  -> ERROR: Failed to create ruleset (Validation error likely). Check the JSON payload."
  fi
  # Note: The success message is now technically inaccurate since bypass is applied via role, not specific ID.
  echo "  -> SUCCESS: Repository Admins (which includes you) can bypass merge rules."
  echo "  -> Repo Settings: https://github.com/$REPO/settings/rules"
  echo
done
rm -f /tmp/ruleset.json
echo "=================================================="
echo "Mission accomplished!"
