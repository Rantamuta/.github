#!/bin/bash

# Script to fork all RanvierMUD repositories to the Ranvire organization
# Note: Only the default branch (main/master) is forked, not feature branches
# Prerequisites: GitHub CLI (gh) must be installed and authenticated
# Usage: ./fork-repositories.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub CLI.${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

# List of all RanvierMUD repositories to fork
declare -a repos=(
    "ranviermud"
    "core"
    "ranvier-telnet"
    "neuro"
    "docs"
    "websocket-networking"
    "telnet-networking"
    "datasource-file"
    "bundle-example-commands"
    "bundle-example-combat"
    "bundle-example-player-events"
    "bundle-example-effects"
    "bundle-example-quests"
    "bundle-example-npc-behaviors"
    "bundle-example-lib"
    "bundle-example-input-events"
    "bundle-example-areas"
    "bundle-example-debug"
    "bundle-example-classes"
    "bundle-example-channels"
    "bundle-example-bugreport"
    "lootable-npcs"
    "vendor-npcs"
    "simple-crafting"
    "player-groups"
    "dialogflow-npcs"
    "simple-waypoints"
    "progressive-respawn"
    "trpg-skeleton"
    "tiny"
)

# Target organization
TARGET_ORG="Ranvire"

# Counters
total=${#repos[@]}
success=0
failed=0
skipped=0

echo "=========================================="
echo "RanvierMUD Repository Forking Script"
echo "=========================================="
echo "Target Organization: $TARGET_ORG"
echo "Total Repositories: $total"
echo "Note: Only default branch (main/master) will be forked"
echo ""

# Confirmation prompt
read -p "Are you sure you want to fork all $total repositories? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo ""
echo "Starting fork process..."
echo ""

# Process each repository
for repo in "${repos[@]}"; do
    source_repo="RanvierMUD/$repo"
    target_repo="$TARGET_ORG/$repo"
    
    echo -e "${YELLOW}Processing:${NC} $source_repo"
    
    # Check if the fork already exists
    if gh repo view "$target_repo" &> /dev/null; then
        echo -e "  ${YELLOW}→ Repository already exists: $target_repo (skipping)${NC}"
        ((skipped++))
        continue
    fi
    
    # Fork the repository
    if gh repo fork "$source_repo" --org "$TARGET_ORG" --clone=false; then
        echo -e "  ${GREEN}✓ Successfully forked to: $target_repo${NC}"
        ((success++))
    else
        echo -e "  ${RED}✗ Failed to fork: $source_repo${NC}"
        ((failed++))
    fi
    
    # Rate limiting: wait 2 seconds between forks
    sleep 2
    echo ""
done

# Summary
echo "=========================================="
echo "Fork Process Complete"
echo "=========================================="
echo -e "Total Repositories: $total"
echo -e "${GREEN}Successfully Forked: $success${NC}"
echo -e "${YELLOW}Skipped (Already Exists): $skipped${NC}"
echo -e "${RED}Failed: $failed${NC}"
echo ""

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}All operations completed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some operations failed. Please check the output above.${NC}"
    exit 1
fi
