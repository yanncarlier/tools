#!/usr/bin/env bash
# ===============================================================
# create-cursor-profile.sh
# Create an isolated VS cursor profile with copied settings/extensions
# ===============================================================
# Usage examples:
#   ./create-cursor-profile.sh rust
#   ./create-cursor-profile.sh go
#   ./create-cursor-profile.sh python-datascience
#   ./create-cursor-profile.sh cpp-competitive
#   ./create-cursor-profile.sh minimal

set -euo pipefail

BASE_DIR="$HOME/cursor-profiles"
SOURCE_CONFIG="$HOME/.config/Cursor"
SOURCE_EXTENSIONS="$HOME/.cursor/extensions"

# ── Colors ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ── Helper functions ──────────────────────────────────────
usage() {
    echo -e "Usage: ${0##*/} <profile-name>"
    echo
    echo "Examples:"
    echo "  ${0##*/} rust"
    echo "  ${0##*/} python-ml"
    echo "  ${0##*/} cpp-clangd"
    exit 1
}

error() {
    echo -e "${RED}Error:${NC} $*" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}Warning:${NC} $*" >&2
}

success() {
    echo -e "${GREEN}$*${NC}"
}

# ── Main logic ────────────────────────────────────────────
if [ $# -ne 1 ]; then
    usage
fi

PROFILE_NAME="$1"
PROFILE_DIR="$BASE_DIR/$PROFILE_NAME"

if [[ "$PROFILE_NAME" =~ [/\\] ]]; then
    error "Profile name cannot contain slashes"
fi

if [ -d "$PROFILE_DIR" ]; then
    warning "Profile directory already exists: $PROFILE_DIR"
    read -p "Overwrite? (y/N): " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    rm -rf "$PROFILE_DIR"
fi

echo "Creating VS cursor profile: $PROFILE_NAME"
echo "Location: $PROFILE_DIR"

mkdir -p "$PROFILE_DIR"/{data,extensions}

# Copy user configuration (settings.json, keybindings.json, snippets, etc.)
if [ -d "$SOURCE_CONFIG/User" ]; then
    cp -a "$SOURCE_CONFIG/User" "$PROFILE_DIR/data/"
    echo "  • Copied User settings & snippets"
else
    warning "User settings directory not found ($SOURCE_CONFIG/User)"
fi

# Copy various caches (helps with faster startup & consistency)
for dir in CachedData CachedExtensionVSIXs CachedProfilesData; do
    if [ -d "$SOURCE_CONFIG/$dir" ]; then
        cp -a "$SOURCE_CONFIG/$dir" "$PROFILE_DIR/data/"
        echo "  • Copied $dir"
    fi
done

# Copy all installed extensions
if [ -d "$SOURCE_EXTENSIONS" ]; then
    cp -r "$SOURCE_EXTENSIONS" "$PROFILE_DIR/"
    echo "  • Copied extensions (~$(find "$SOURCE_EXTENSIONS" -mindepth 1 -maxdepth 1 | wc -l)) folders"
else
    warning "Global extensions folder not found ($SOURCE_EXTENSIONS)"
fi

echo
success "Profile '$PROFILE_NAME' created successfully!"
echo
echo "To use it, run:"
echo "  cursor --user-data-dir \"$PROFILE_DIR/data\" --extensions-dir \"$PROFILE_DIR/extensions\" ."
echo
echo "Or create an alias/shortcut, for example:"
echo "  alias cursor-rust='cursor --user-data-dir \"$PROFILE_DIR/data\" --extensions-dir \"$PROFILE_DIR/extensions\"'"
echo