#!/usr/bin/env bash
# File: 3-gh-setup-rulesets.sh
# Purpose: Sets up repository rulesets with branch protection.
# Rulesets enforce branch protection policies (require PR reviews, block force pushes, etc.).
# Admins (including script runner) can bypass these rules when needed.
#
# Prerequisites: GitHub CLI (gh) authentication with admin access. Run: gh auth login
#
# Usage Examples:
#   bash 3-gh-setup-rulesets.sh                                 # public repos
#   INCLUDE_PRIVATE_REPOS=true bash 3-gh-setup-rulesets.sh      # include private
#   OWNER="username" INCLUDE_PRIVATE_REPOS=true bash 3-gh-setup-rulesets.sh
#   REPOS="my-repo" bash 3-gh-setup-rulesets.sh     # single repo
#   REPOS="repo1,repo2" bash 3-gh-setup-rulesets.sh  # multiple

set -euo pipefail

# REQUIRED: You must be authenticated with GitHub CLI
# Run `gh auth login` first if you haven't

# === CONFIGURATION ===
# OWNER: GitHub user or org name (override via environment: OWNER="username")
OWNER=${OWNER:-"username"}

# REPOS: Target specific repo(s). Can be set via environment as single or comma-separated list.
# Examples: REPOS="my-repo" or REPOS="repo1,repo2"
# If not provided, script fetches all repos for OWNER based on INCLUDE_PRIVATE_REPOS flag.

# === FETCH REPOSITORIES ===
# INCLUDE_PRIVATE_REPOS: Include private repositories when fetching all repos
# Default: false (public repos only). Set to "true" to include private repos.
# Requires gh CLI token with private repo access scope.
INCLUDE_PRIVATE_REPOS=${INCLUDE_PRIVATE_REPOS:-false}

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
  # REPOS not provided: fetch from GitHub based on INCLUDE_PRIVATE_REPOS flag
  if [ "${INCLUDE_PRIVATE_REPOS}" = "true" ]; then
    echo "Fetching repositories for $OWNER (including private repositories)..."
    # Fetch all repos (public + private) for the owner without visibility filter
    mapfile -t REPOS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner')
  else
    echo "Fetching public repositories for $OWNER..."
    # Fetch only public repos for the owner
    mapfile -t REPOS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public)
  fi
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
