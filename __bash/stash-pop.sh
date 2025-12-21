#!/bin/bash

# git-stash-pop-all.sh
# Runs 'git stash pop' in all immediate subdirectories that are git repositories.

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
total=0
popped=0
empty=0
failed=0
skipped=0

start_dir="$(pwd)"

echo -e "${BLUE}Scanning immediate subdirectories for git repos...${NC}\n"

for dir in */; do
    # Remove trailing slash
    dir="${dir%/}"
    
    # Skip if not a directory (handles edge case of no subdirs)
    [[ -d "$dir" ]] || continue
    
    # Skip if not a git repository
    if [[ ! -d "$dir/.git" ]]; then
        ((skipped++))
        continue
    fi
    
    ((total++))
    
    echo -e "${YELLOW}[$dir]${NC}"
    
    cd "$dir" || {
        echo -e "${RED}  ✗ Failed to enter directory${NC}\n"
        ((failed++))
        continue
    }
    
    output=$(git stash pop 2>&1)
    exit_code=$?
    
    if [[ "$output" == *"No stash entries found"* ]]; then
        echo -e "  No stash entries found"
        ((empty++))
    elif [[ $exit_code -eq 0 ]]; then
        echo -e "  ${GREEN}✓ Stash popped successfully${NC}"
        ((popped++))
    else
        echo -e "${RED}  ✗ git stash pop failed:${NC}"
        echo -e "${RED}$output${NC}"
        ((failed++))
    fi
    
    cd "$start_dir" || exit 1
    echo ""
done

# Summary
echo -e "${BLUE}────────────────────────────────────${NC}"
echo -e "${BLUE}Summary:${NC}"
echo -e "  Git repos found:   $total"
echo -e "  Popped:            ${GREEN}$popped${NC}"
echo -e "  Empty stash:       $empty"
echo -e "  Failed:            ${RED}$failed${NC}"
echo -e "  Skipped (non-git): $skipped"