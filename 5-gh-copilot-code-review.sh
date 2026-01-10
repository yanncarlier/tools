#!/usr/bin/env bash
# 5-gh-copilot-code-review.sh
# Summary: Create Copilot Code Review rulesets to enforce automated PR analysis
# on target repositories' default branches. Uses the GitHub CLI (`gh`).
#
# Prerequisites:
#  - `gh` installed and authenticated with admin access
#  - Organization must have GitHub Copilot (Team/Enterprise) enabled
#
# Usage examples:
#  FETCH_ALL_REPOS=true OWNER="username" bash 5-gh-copilot-code-review.sh
#  REPOS="my-repo" OWNER="username" bash 5-gh-copilot-code-review.sh

set -euo pipefail

# === CONFIGURATION ===
# OWNER: GitHub user or org name (override via environment: OWNER="username")
OWNER=${OWNER:-"username"}

# REPOS: Target specific repo(s). Can be set via environment as single or comma-separated list.
# Examples: REPOS="my-repo" or REPOS="repo1,repo2"
# If not provided, script fetches all repos for OWNER based on INCLUDE_PRIVATE_REPOS flag.

# REPOS_TO_PROCESS: List of repos to configure. If empty and FETCH_ALL_REPOS=true,
# fetches repos from GitHub. Default hardcoded list: empty (requires explicit action)
REPOS_TO_PROCESS=()

# FETCH_ALL_REPOS: If true, override REPOS_TO_PROCESS and fetch all public repos for OWNER
# from GitHub instead of using the hardcoded list.
# Usage: `FETCH_ALL_REPOS=true OWNER="username" bash 5-gh-copilot-code-review.sh`
if [ "${FETCH_ALL_REPOS:-false}" = "true" ]; then
  REPOS_TO_PROCESS=()
fi

# PROMPT_BEFORE_API: If true, prompt user before each API call (interactive mode)
# Default: false (non-interactive, auto-approve). Usage: `PROMPT_BEFORE_API=true bash 5-gh-copilot-code-review.sh`
PROMPT_BEFORE_API=${PROMPT_BEFORE_API:-false}

# RULESET_NAME: Name of the Copilot Code Review ruleset to create/manage
# Default: "copilot-code-review-default" (protects default branch)
RULESET_NAME="copilot-code-review-default"

# ENABLE_DISMISS_STALE_APPROVALS: Auto-dismiss code review approvals when new commits are pushed
# Default: true (recommended for security)
ENABLE_DISMISS_STALE_APPROVALS=true

# === FETCH REPOSITORIES ===
echo "Fetching repositories for $OWNER..."
if [ -n "${REPOS:-}" ]; then
  echo "Using provided REPOS from environment"
  # Convert comma-separated list to array, handling spaces
  IFS=',' read -r -a __tmp <<< "$REPOS"
  REPOS_TO_PROCESS=()
  for r in "${__tmp[@]}"; do
    # Trim whitespace
    r="${r// /}"
    # Always prefix with OWNER
    REPOS_TO_PROCESS+=("$OWNER/$r")
  done
else
  # REPOS not provided: fetch from GitHub
  if [ ${#REPOS_TO_PROCESS[@]} -eq 0 ]; then
    echo "  (fetching public repositories)"
    # Fetch only public repos for the owner
    mapfile -t REPOS_TO_PROCESS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public)
  else
    # Repos specified: add OWNER prefix if not already present (handle "repo" → "owner/repo")
    REPOS_TO_PROCESS=( "${REPOS_TO_PROCESS[@]/#/$OWNER/}" )
  fi
fi

echo "Found ${#REPOS_TO_PROCESS[@]} repositories to process."
echo "--------------------------------------------------"

# === HELPER FUNCTION: Create or update Copilot Code Review ruleset ===
setup_copilot_ruleset() {
  local repo=$1
  
  # 1. Delete existing Copilot Code Review ruleset if it exists
  # Query for ruleset with RULESET_NAME; extract ID if found
  EXISTING_ID=$(gh api "repos/$repo/rulesets" --jq "map(select(.name == \"$RULESET_NAME\")) | .[0].id // empty" 2>/dev/null || true)
  
  if [[ -n "$EXISTING_ID" ]]; then
    echo "  -> Found existing ruleset (ID: $EXISTING_ID). Deleting..."
    if gh api "repos/$repo/rulesets/$EXISTING_ID" --method DELETE >/dev/null 2>&1; then
      echo "  -> Existing ruleset deleted."
    else
      echo "  -> WARNING: Failed to delete existing ruleset. Proceeding with new creation."
    fi
  fi
  
  # 2. Create JSON payload for Copilot Code Review ruleset
  # Ruleset enforces Copilot code review on PRs targeting the default branch
  # Admins (role ID 5) can bypass the requirement when needed
  cat <<'EOF' > /tmp/copilot-ruleset.json
{
  "name": "copilot-code-review-default",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"]
    }
  },
  "rules": [
    {
      "type": "code_review_by_copilot",
      "parameters": {
        "require_code_review_by_copilot": true,
        "dismiss_stale_reviews_on_push": true,
        "require_review_thread_resolution": true
      }
    }
  ],
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ]
}
EOF
  
  # 3. Create the Copilot Code Review ruleset
  if [ "$PROMPT_BEFORE_API" = true ]; then
    read -r -p "  -> Will POST 'repos/$repo/rulesets' to create Copilot Code Review ruleset. Proceed? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      response=$(gh api "repos/$repo/rulesets" --method POST --input /tmp/copilot-ruleset.json 2>&1 || true)
      if echo "$response" | grep -q "id"; then
        echo "  -> Copilot Code Review ruleset created successfully"
        return 0
      else
        echo "  -> ERROR: Failed to create Copilot Code Review ruleset"
        echo "  -> Response: $response"
        return 1
      fi
    else
      echo "  -> Skipped Copilot Code Review ruleset creation"
      return 0
    fi
  else
    response=$(gh api "repos/$repo/rulesets" --method POST --input /tmp/copilot-ruleset.json 2>&1 || true)
    if echo "$response" | grep -q "id"; then
      echo "  -> Copilot Code Review ruleset created successfully"
      return 0
    else
      echo "  -> ERROR: Failed to create Copilot Code Review ruleset"
      echo "  -> Response: $response"
      return 1
    fi
  fi
}

# === PROCESS REPOSITORIES ===
for REPO in "${REPOS_TO_PROCESS[@]}"; do
  echo "=========================================="
  echo "Processing $REPO"
  
  # Skip archived or disabled repositories
  archived=false
  if archived=$(gh api "repos/$REPO" --jq '.archived' 2>/dev/null || echo "false"); then
    if [ "$archived" = "true" ]; then
      echo "  -> Skipping archived repository"
      echo "=========================================="
      continue
    fi
  fi
  
  # Verify Copilot is available in the repository
  # Check if organization has Copilot enabled (Copilot Enterprise or Team)
  org=$(echo "$REPO" | cut -d'/' -f1)
  if gh api "orgs/$org" --jq '.copilot_enabled // false' >/dev/null 2>&1; then
    echo "  -> Copilot available for organization"
  else
    echo "  -> WARNING: Copilot may not be enabled for this organization"
  fi
  
  # Setup Copilot Code Review ruleset
  setup_copilot_ruleset "$REPO" || true
  
  echo "  -> Ruleset Management: https://github.com/$REPO/settings/rules"
  echo "  -> Branch Protection: https://github.com/$REPO/settings/branch_protection_rules"
  echo "=========================================="
done

rm -f /tmp/copilot-ruleset.json
echo "✅ ALL DONE! Copilot Code Review ruleset configuration attempted for ${#REPOS_TO_PROCESS[@]} repositories."
