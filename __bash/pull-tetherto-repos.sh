#!/usr/bin/env bash
#
# pull-tetherto-repos.sh
#
# For every Git repository under a given directory:
# 1. Find the remote whose URL contains 'git@github.com:tetherto'
# 2. Checkout and pull from dev, main, or master (in that order)
# 3. Report results
#
# Usage: ./pull-tetherto-repos.sh [directory]
#        Default directory is current working directory.

set -euo pipefail

# --- Configuration ---
readonly TARGET_URL_PATTERN="git@github.com:tetherto"
readonly BRANCH_PRIORITY=("dev" "main" "master")

# --- Color output (disabled if not a terminal) ---
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly NC=''
fi

# --- Results tracking ---
declare -a RESULTS_SUCCESS=()
declare -a RESULTS_SKIPPED=()
declare -a RESULTS_FAILED=()

# --- Functions ---

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

# Find the remote name that matches the target URL pattern
# Returns: remote name via stdout, exit code 0 if found, 1 if not
find_tetherto_remote() {
    local repo_path="$1"
    local remote_name
    local remote_url

    while IFS= read -r line; do
        # Parse "remote_name\turl (fetch)" format
        remote_name=$(echo "$line" | awk '{print $1}')
        remote_url=$(echo "$line" | awk '{print $2}')
        
        if [[ "$remote_url" == *"$TARGET_URL_PATTERN"* ]]; then
            echo "$remote_name"
            return 0
        fi
    done < <(git -C "$repo_path" remote -v 2>/dev/null | grep "(fetch)")

    return 1
}

# Check if a branch exists on the remote
remote_branch_exists() {
    local repo_path="$1"
    local remote="$2"
    local branch="$3"
    
    git -C "$repo_path" ls-remote --exit-code --heads "$remote" "$branch" &>/dev/null
}

# Check for uncommitted changes
has_uncommitted_changes() {
    local repo_path="$1"
    ! git -C "$repo_path" diff-index --quiet HEAD -- 2>/dev/null
}

# Process a single repository
process_repo() {
    local repo_path="$1"
    local repo_name
    repo_name=$(basename "$repo_path")
    
    local remote_name
    local target_branch=""
    local pull_output
    
    # Step 1: Find the tetherto remote
    if ! remote_name=$(find_tetherto_remote "$repo_path"); then
        RESULTS_SKIPPED+=("$repo_name: no tetherto remote found")
        return 0
    fi
    
    # Step 2: Fetch from the remote first
    if ! git -C "$repo_path" fetch "$remote_name" --prune &>/dev/null; then
        RESULTS_FAILED+=("$repo_name: fetch from '$remote_name' failed")
        return 1
    fi
    
    # Step 3: Check for uncommitted changes
    if has_uncommitted_changes "$repo_path"; then
        RESULTS_FAILED+=("$repo_name: has uncommitted changes, skipping checkout")
        return 1
    fi
    
    # Step 4: Find a valid branch (dev > main > master)
    for branch in "${BRANCH_PRIORITY[@]}"; do
        if remote_branch_exists "$repo_path" "$remote_name" "$branch"; then
            target_branch="$branch"
            break
        fi
    done
    
    if [[ -z "$target_branch" ]]; then
        RESULTS_FAILED+=("$repo_name: no dev/main/master branch on remote '$remote_name'")
        return 1
    fi
    
    # Step 5: Checkout the branch
    # First, check if branch exists locally
    if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$target_branch"; then
        # Branch exists locally, switch to it
        if ! git -C "$repo_path" checkout "$target_branch" &>/dev/null; then
            RESULTS_FAILED+=("$repo_name: checkout '$target_branch' failed")
            return 1
        fi
    else
        # Branch doesn't exist locally, create tracking branch
        if ! git -C "$repo_path" checkout -b "$target_branch" "$remote_name/$target_branch" &>/dev/null; then
            RESULTS_FAILED+=("$repo_name: checkout -b '$target_branch' failed")
            return 1
        fi
    fi
    
    # Step 6: Pull from the specific remote
    if ! pull_output=$(git -C "$repo_path" pull "$remote_name" "$target_branch" 2>&1); then
        RESULTS_FAILED+=("$repo_name: pull from '$remote_name/$target_branch' failed")
        return 1
    fi
    
    # Success
    if [[ "$pull_output" == *"Already up to date"* ]]; then
        RESULTS_SUCCESS+=("$repo_name: $target_branch (already up to date)")
    else
        RESULTS_SUCCESS+=("$repo_name: $target_branch (updated)")
    fi
    
    return 0
}

# Find all git repositories under a directory
find_git_repos() {
    local search_dir="$1"
    
    # Find directories containing .git (either file or directory)
    # Using -prune to avoid descending into .git directories
    find "$search_dir" -type d -name ".git" -prune 2>/dev/null | while read -r git_dir; do
        dirname "$git_dir"
    done
}

# Print the summary report
print_summary() {
    local total=$((${#RESULTS_SUCCESS[@]} + ${#RESULTS_SKIPPED[@]} + ${#RESULTS_FAILED[@]}))
    
    echo ""
    echo "=============================================="
    echo "               SUMMARY REPORT                 "
    echo "=============================================="
    echo ""
    
    if [[ ${#RESULTS_SUCCESS[@]} -gt 0 ]]; then
        echo -e "${GREEN}✓ Successfully pulled (${#RESULTS_SUCCESS[@]}):${NC}"
        for result in "${RESULTS_SUCCESS[@]}"; do
            echo "    $result"
        done
        echo ""
    fi
    
    if [[ ${#RESULTS_SKIPPED[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⊘ Skipped - no tetherto remote (${#RESULTS_SKIPPED[@]}):${NC}"
        for result in "${RESULTS_SKIPPED[@]}"; do
            echo "    $result"
        done
        echo ""
    fi
    
    if [[ ${#RESULTS_FAILED[@]} -gt 0 ]]; then
        echo -e "${RED}✗ Failed (${#RESULTS_FAILED[@]}):${NC}"
        for result in "${RESULTS_FAILED[@]}"; do
            echo "    $result"
        done
        echo ""
    fi
    
    echo "----------------------------------------------"
    echo "Total repositories: $total"
    echo "  Success: ${#RESULTS_SUCCESS[@]}"
    echo "  Skipped: ${#RESULTS_SKIPPED[@]}"
    echo "  Failed:  ${#RESULTS_FAILED[@]}"
    echo "=============================================="
}

# --- Main ---

main() {
    local search_dir="${1:-.}"
    
    # Resolve to absolute path
    if [[ ! -d "$search_dir" ]]; then
        log_error "Directory does not exist: $search_dir"
        exit 1
    fi
    search_dir=$(cd "$search_dir" && pwd)
    
    log_info "Searching for Git repositories in: $search_dir"
    log_info "Looking for remotes matching: $TARGET_URL_PATTERN"
    echo ""
    
    # Collect repos first to show count
    local repos=()
    while IFS= read -r repo; do
        [[ -n "$repo" ]] && repos+=("$repo")
    done < <(find_git_repos "$search_dir")
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        log_warn "No Git repositories found under $search_dir"
        exit 0
    fi
    
    log_info "Found ${#repos[@]} Git repositories"
    echo ""
    
    # Process each repository
    for repo_path in "${repos[@]}"; do
        local repo_name
        repo_name=$(basename "$repo_path")
        echo -n "Processing: $repo_name ... "
        
        if process_repo "$repo_path"; then
            # Result already logged in process_repo
            if [[ ${#RESULTS_SKIPPED[@]} -gt 0 ]] && [[ "${RESULTS_SKIPPED[*]}" == *"$repo_name"* ]]; then
                echo -e "${YELLOW}skipped${NC}"
            else
                echo -e "${GREEN}done${NC}"
            fi
        else
            echo -e "${RED}failed${NC}"
        fi
    done
    
    # Print summary
    print_summary
    
    # Exit with error if any failures
    if [[ ${#RESULTS_FAILED[@]} -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
