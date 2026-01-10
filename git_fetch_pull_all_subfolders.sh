#!/usr/bin/env bash
# git_fetch_pull_all_subfolders.sh
# Summary: Iterate subdirectories and run `git fetch` and `git pull` where a
# `.git` folder exists. Designed for a folder containing multiple repositories.

set -euo pipefail

# Uncomment to force the script directory as the repositories root
# REPOSITORIES="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPOSITORIES=$(pwd)

IFS=$'\n'

for REPO in $(ls "$REPOSITORIES/"); do
  if [ -d "$REPOSITORIES/$REPO" ]; then
    echo "Updating $REPOSITORIES/$REPO at $(date)"
    if [ -d "$REPOSITORIES/$REPO/.git" ]; then
      cd "$REPOSITORIES/$REPO"
      git status
      echo "Fetching"
      git fetch
      echo "Pulling"
      git pull
    else
      echo "Skipping: not a git repo"
    fi
    echo "Done at $(date)"
    echo
  fi
done
