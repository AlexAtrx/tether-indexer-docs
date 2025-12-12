#!/bin/bash

# Script to checkout 'dev' or 'main' branch from 'tether' remote in all subdirectories
# - Finds tether remote in each git repo
# - Tries to checkout and pull from dev branch first
# - Falls back to main branch if dev fails
# - Logs all output to stderr with color coding
# - Continues even if some directories fail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Counters for different outcomes
success_dev_count=0
success_main_count=0
fail_count=0
skip_count=0

echo "Starting git checkout dev/main from tether remote for all subdirectories..." >&2
echo "==================================================================================" >&2

# Iterate through all items in current directory
for dir in */; do
    # Remove trailing slash
    dir_name="${dir%/}"
    
    # Check if it's actually a directory
    if [ ! -d "$dir_name" ]; then
        continue
    fi
    
    echo "" >&2
    echo "Processing: $dir_name" >&2
    
    # Check if directory contains a git repository
    if [ ! -d "$dir_name/.git" ]; then
        echo -e "  ${RED}✗ Skipping (not a git repository)${NC}" >&2
        ((skip_count++))
        continue
    fi
    
    # Try to enter directory
    cd "$dir_name" || {
        echo -e "  ${RED}✗ Failed to enter directory${NC}" >&2
        ((fail_count++))
        continue
    }
    
    # Find tether remote (match any remote with 'tether' in the name)
    tether_remote=$(git remote -v | grep 'tether' | head -1 | awk '{print $1}')
    
    if [ -z "$tether_remote" ]; then
        echo -e "  ${RED}✗ No tether remote found${NC}" >&2
        ((fail_count++))
        cd ..
        continue
    fi
    
    echo "  Found tether remote: $tether_remote" >&2
    
    # Fetch from tether remote to get latest branch information
    echo "  ↓ Fetching from $tether_remote..." >&2
    fetch_output=$(git fetch "$tether_remote" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "  ${RED}✗ Failed to fetch from $tether_remote${NC}" >&2
        if [ -n "$fetch_output" ]; then
            echo "$fetch_output" | sed 's/^/    /' >&2
        fi
        ((fail_count++))
        cd ..
        continue
    fi
    # Show fetch output if there were updates
    if [ -n "$fetch_output" ]; then
        echo "$fetch_output" | sed 's/^/    /' >&2
    fi
    
    # Try to checkout and pull from dev branch
    echo "  ↓ Attempting to checkout dev branch..." >&2
    if git checkout dev &>/dev/null; then
        pull_output=$(git pull "$tether_remote" dev 2>&1)
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓ Successfully checked out and pulled dev branch${NC}" >&2
            if [ -n "$pull_output" ]; then
                echo "$pull_output" | sed 's/^/    /' >&2
            fi
            ((success_dev_count++))
            cd ..
            continue
        fi
    fi
    
    # If dev failed, try main branch as fallback
    echo "  ↓ Dev branch not available, attempting main branch..." >&2
    if git checkout main &>/dev/null; then
        pull_output=$(git pull "$tether_remote" main 2>&1)
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓ Successfully checked out and pulled main branch${NC}" >&2
            if [ -n "$pull_output" ]; then
                echo "$pull_output" | sed 's/^/    /' >&2
            fi
            ((success_main_count++))
            cd ..
            continue
        fi
    fi
    
    # If main failed, try master branch as second fallback
    echo "  ↓ Main branch not available, attempting master branch..." >&2
    if git checkout master &>/dev/null; then
        pull_output=$(git pull "$tether_remote" master 2>&1)
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓ Successfully checked out and pulled master branch${NC}" >&2
            if [ -n "$pull_output" ]; then
                echo "$pull_output" | sed 's/^/    /' >&2
            fi
            ((success_main_count++))
            cd ..
            continue
        fi
    fi
    
    # If dev, main, and master all failed, log error
    echo -e "  ${RED}✗ Failed to checkout/pull dev, main, or master from $tether_remote${NC}" >&2
    ((fail_count++))
    
    # Return to parent directory
    cd ..
done

echo "" >&2
echo "==================================================================================" >&2
echo "Summary:" >&2
echo -e "  ${GREEN}✓ Success (dev branch):${NC} $success_dev_count" >&2
echo -e "  ${GREEN}✓ Success (main branch):${NC} $success_main_count" >&2
echo -e "  ${RED}✗ Failed:${NC} $fail_count" >&2
echo "  ⊘ Skipped (not git repos or no tether remote): $skip_count" >&2
echo "==================================================================================" >&2

exit 0
