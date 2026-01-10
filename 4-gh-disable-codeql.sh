#!/usr/bin/env bash
# 4-gh-disable-codeql.sh
# Summary: Disable CodeQL default configuration and optionally remove custom
# CodeQL workflow files from listed repositories using `gh`.
#
# Prerequisites:
#  - `gh` installed and authenticated with access to target repositories.
#
# Usage example:
#  REPOS="repo1,repo2" OWNER="username" bash 4-gh-disable-codeql.sh

set -euo pipefail

# === CONFIGURATION WITH PLACEHOLDERS ===
# Replace or override these via environment variables when running the script

OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}

echo "Fetching repositories for $OWNER..."

REPOS_TO_PROCESS=()

if [ -z "${REPOS}" ]; then
  echo "ERROR: No repositories specified."
  echo "Provide a comma-separated list via the REPOS variable:"
  echo "  REPOS=\"repo1,repo2\" OWNER=\"username\" bash 4-gh-disable-codeql.sh"
  exit 1
fi

# Split comma-separated string into array
IFS=',' read -ra REPOS_ARRAY <<< "$REPOS"
for r in "${REPOS_ARRAY[@]}"; do
  # Trim whitespace
  r="${r// /}"
  REPOS_TO_PROCESS+=("$r")
done

# Convert to full owner/repo format
FULL_REPOS=()
for repo_name in "${REPOS_TO_PROCESS[@]}"; do
  FULL_REPOS+=("$OWNER/$repo_name")
done

echo "Found ${#FULL_REPOS[@]} repositories to process."
echo "--------------------------------------------------"

for REPO in "${FULL_REPOS[@]}"; do
  echo "Processing $REPO"

  # Skip archived repositories
  archived=$(gh api "repos/$REPO" --jq '.archived' 2>/dev/null || echo "false")
  if [ "$archived" = "true" ]; then
    echo "  -> Skipping archived repository"
    echo "--------------------------------------------------"
    continue
  fi

  # 1) Disable CodeQL default setup if enabled
  current_state=$(gh api "repos/$REPO/code-scanning/default-setup" --jq '.state // "not-configured"' 2>/dev/null || echo "error")

  if [ "$current_state" = "configured" ]; then
    echo "  -> CodeQL default setup is currently enabled. Disabling..."

    cat <<EOF > /tmp/disable-codeql.json
{
  "state": "not-configured"
}
EOF

    if gh api "repos/$REPO/code-scanning/default-setup" --method PATCH --input /tmp/disable-codeql.json >/dev/null 2>&1; then
      echo "  -> CodeQL default setup disabled successfully"
    else
      echo "  -> ERROR: Failed to disable CodeQL default setup"
    fi
  elif [ "$current_state" = "not-configured" ]; then
    echo "  -> CodeQL default setup is already disabled"
  else
    echo "  -> Unable to query CodeQL state (API error or not eligible)"
  fi

  # Note: Deleting custom CodeQL workflow files has been removed from this script.

  echo "  -> Security page: https://github.com/$REPO/security"
  echo "--------------------------------------------------"
done

rm -f /tmp/disable-codeql.json 2>/dev/null || true

echo "✅ ALL DONE! CodeQL disabling attempted for ${#FULL_REPOS[@]} repositories."
echo "Note: Existing alerts remain until manually dismissed."
echo "      If issues persist, disable manually in repo settings: Code security and analysis → Code scanning → Disable."
