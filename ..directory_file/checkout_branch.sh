#!/usr/bin/env bash

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Validate argument
if [[ -z "$1" ]]; then
    echo -e "${RED}Error: Branch name required${NC}"
    echo "Usage: $0 <branch-name>"
    exit 1
fi

BRANCH="$1"
BASE_DIR="${2:-.}"  # Optional second arg for base directory, defaults to current

# Arrays for summary
declare -a SUCCESS=()
declare -a FAILED=()
declare -a SKIPPED=()

log_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}[OK] $1${NC}"
}

log_info() {
    echo -e "${CYAN}[INFO] $1${NC}"
}

log_skip() {
    echo -e "${YELLOW}[SKIP] $1${NC}"
}

# Iterate one level deep
for dir in "$BASE_DIR"/*/; do
    # Remove trailing slash for cleaner output
    dir="${dir%/}"
    dir_name=$(basename "$dir")

    # Skip if not a directory
    [[ ! -d "$dir" ]] && continue

    # Skip if not a git repo
    if [[ ! -d "$dir/.git" ]]; then
        log_skip "$dir_name: not a git repository"
        SKIPPED+=("$dir_name")
        continue
    fi

    log_info "Processing: $dir_name"

    # Try checkout
    checkout_output=""
    checkout_success=false

    # Try local branch first
    if git -C "$dir" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
        checkout_output=$(git -C "$dir" checkout "$BRANCH" 2>&1)
        if [[ $? -eq 0 ]]; then
            checkout_success=true
        fi
    # Try remote branch
    elif git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/$BRANCH" 2>/dev/null; then
        checkout_output=$(git -C "$dir" checkout -b "$BRANCH" "origin/$BRANCH" 2>&1)
        if [[ $? -eq 0 ]]; then
            checkout_success=true
        # Branch might already exist but wasn't detected, try regular checkout
        elif git -C "$dir" checkout "$BRANCH" 2>&1; then
            checkout_success=true
        fi
    else
        log_error "$dir_name: branch '$BRANCH' not found (local or remote)"
        FAILED+=("$dir_name: branch not found")
        continue
    fi

    if [[ "$checkout_success" == false ]]; then
        log_error "$dir_name: checkout failed - $checkout_output"
        FAILED+=("$dir_name: checkout failed")
        continue
    fi

    log_success "$dir_name: checked out '$BRANCH'"

    # Pull from remote
    pull_output=$(git -C "$dir" pull origin "$BRANCH" 2>&1)
    if [[ $? -ne 0 ]]; then
        log_error "$dir_name: pull failed - $pull_output"
        FAILED+=("$dir_name: pull failed")
        continue
    fi

    log_success "$dir_name: pulled latest from origin/$BRANCH"
    SUCCESS+=("$dir_name")
done

# Print summary
echo ""
echo "========================================"
echo -e "${CYAN}SUMMARY${NC}"
echo "========================================"

if [[ ${#SUCCESS[@]} -gt 0 ]]; then
    echo -e "${GREEN}Successfully switched and pulled (${#SUCCESS[@]}):${NC}"
    for repo in "${SUCCESS[@]}"; do
        echo "  ✓ $repo"
    done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo -e "${RED}Failed (${#FAILED[@]}):${NC}"
    for repo in "${FAILED[@]}"; do
        echo "  ✗ $repo"
    done
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Skipped - not git repos (${#SKIPPED[@]}):${NC}"
    for repo in "${SKIPPED[@]}"; do
        echo "  - $repo"
    done
fi

echo "========================================"
echo "Total: ${#SUCCESS[@]} success, ${#FAILED[@]} failed, ${#SKIPPED[@]} skipped"

# Exit with error code if any failures
[[ ${#FAILED[@]} -gt 0 ]] && exit 1
exit 0