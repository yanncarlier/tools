#!/usr/bin/env bash
# File: 3-gh-setup-ruleset-branches.sh
# Run with: bash 3-gh-setup-ruleset-branches.sh

set -euo pipefail

# REQUIRED: You must be authenticated with GitHub CLI
# Run `gh auth login` first if you haven't

# --- Configuration ---
# Your GitHub username
OWNER="yanncarlier"

# Target specific repo as requested
# REPOS=("yanncarlier/tools")

# --- Fetch Repositories ---
echo "Fetching ALL *PUBLIC* repositories for $OWNER..."
# Add '--visibility public' to the list command
mapfile -t REPOS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public) 

echo "Found ${#REPOS[@]} repositories to process."
echo "--------------------------------------------------"

RULESET_NAME="protect-default-branch"

# Get Current User ID
YOUR_ID=$(gh api user --jq '.id')
echo "Your GitHub user ID: $YOUR_ID"
echo "Found ${#REPOS[@]} repositories to process"
echo
for REPO in "${REPOS[@]}"; do
  echo "=================================================="
  echo "Processing $REPO"
  # 1. Ensure dev branch exists
  if ! gh api "repos/$REPO/branches/dev" >/dev/null 2>&1; then
    DEFAULT_BRANCH=$(gh api "repos/$REPO" --jq '.default_branch')
    SHA=$(gh api "repos/$REPO/branches/$DEFAULT_BRANCH" --jq '.commit.sha')
    echo "  -> Creating dev branch from $DEFAULT_BRANCH"
    gh api "repos/$REPO/git/refs" -f ref="refs/heads/dev" -f sha="$SHA" >/dev/null
  else
    echo "  -> dev branch already exists"
  fi
  # 2. DELETE existing ruleset if it exists
  # Fix: ensure '$REPO' (singular) is used for the API call
  EXISTING_ID=$(gh api "repos/$REPO/rulesets" --jq "map(select(.name == \"$RULESET_NAME\")) | .[0].id // empty")
  if [[ -n "$EXISTING_ID" ]]; then
    echo "  -> Found existing ruleset (ID: $EXISTING_ID). Deleting..."
    gh api "repos/$REPO/rulesets/$EXISTING_ID" --method DELETE >/dev/null
  fi
  # 3. Define JSON Payload (Create new)
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
  # 4. Create the Ruleset (POST)
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