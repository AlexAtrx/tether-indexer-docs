#!/usr/bin/env bash
# pull-all.sh — Pull updates for every repo under this directory that has a tetherto remote.
# Usage: ./pull-all.sh [--dry-run] [--jobs N] [--quiet]
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
REMOTE_PATTERN="git@github.com:tetherto"
BRANCH_PRIORITY=(dev develop main master)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── CLI flags ───────────────────────────────────────────────────────────────
DRY_RUN=false
QUIET=false
PARALLEL_JOBS=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true;  shift ;;
        --quiet|-q) QUIET=true;    shift ;;
        --jobs|-j)  PARALLEL_JOBS="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $(basename "$0") [--dry-run] [--quiet|-q] [--jobs|-j N]"
            echo "  --dry-run   Show what would happen without making changes"
            echo "  --quiet     Suppress per-repo progress output"
            echo "  --jobs N    Process N repos in parallel (default: 1)"
            exit 0 ;;
        *) echo "Unknown flag: $1" >&2; exit 1 ;;
    esac
done

# ── Colors (disabled if not a terminal) ─────────────────────────────────────
if [[ -t 1 ]]; then
    C_GREEN='\033[0;32m' C_RED='\033[0;31m' C_YELLOW='\033[0;33m'
    C_CYAN='\033[0;36m'  C_BOLD='\033[1m'   C_RESET='\033[0m'
else
    C_GREEN='' C_RED='' C_YELLOW='' C_CYAN='' C_BOLD='' C_RESET=''
fi

# ── Temp file for collecting results from subprocesses ──────────────────────
RESULTS_FILE="$(mktemp)"
trap 'rm -f "$RESULTS_FILE"' EXIT

# ── Helpers ─────────────────────────────────────────────────────────────────
log()  { $QUIET || printf "${C_CYAN}[%s]${C_RESET} %s\n" "$(basename "$1")" "$2"; }
ok()   { printf "OK|%s|%s|%s\n"   "$1" "$2" "$3" >> "$RESULTS_FILE"; }
skip() { printf "SKIP|%s|%s|%s\n" "$1" "$2" "$3" >> "$RESULTS_FILE"; }
fail() { printf "FAIL|%s|%s|%s\n" "$1" "$2" "$3" >> "$RESULTS_FILE"; }

# ── Find the matching remote ────────────────────────────────────────────────
find_tetherto_remote() {
    local repo_dir="$1"
    git -C "$repo_dir" remote -v 2>/dev/null \
        | awk -v pat="$REMOTE_PATTERN" '$2 ~ pat && $3 == "(fetch)" { print $1; exit }'
}

# ── Resolve the best branch that exists on the remote ───────────────────────
resolve_branch() {
    local repo_dir="$1" remote="$2"
    local remote_heads
    remote_heads="$(git -C "$repo_dir" ls-remote --heads "$remote" 2>/dev/null)" || return 1

    for branch in "${BRANCH_PRIORITY[@]}"; do
        if echo "$remote_heads" | grep -q "refs/heads/${branch}$"; then
            echo "$branch"
            return 0
        fi
    done
    return 1
}

# ── Process a single repository ─────────────────────────────────────────────
process_repo() {
    local repo_dir="$1"
    local repo_name
    repo_name="$(basename "$repo_dir")"

    # 1. Find the tetherto remote
    local remote
    remote="$(find_tetherto_remote "$repo_dir")"
    if [[ -z "$remote" ]]; then
        log "$repo_dir" "No ${REMOTE_PATTERN} remote — skipping"
        skip "$repo_name" "-" "no matching remote"
        return 0
    fi

    # 2. Resolve best branch
    local branch
    if ! branch="$(resolve_branch "$repo_dir" "$remote")"; then
        log "$repo_dir" "Could not query remote '${remote}'"
        fail "$repo_name" "$remote" "ls-remote failed"
        return 0
    fi
    if [[ -z "$branch" ]]; then
        log "$repo_dir" "None of [${BRANCH_PRIORITY[*]}] found on remote '${remote}'"
        fail "$repo_name" "$remote" "no matching branch"
        return 0
    fi

    log "$repo_dir" "remote=${remote}  branch=${branch}"

    if $DRY_RUN; then
        ok "$repo_name" "$remote" "$branch (dry-run)"
        return 0
    fi

    # 3. Clean up stale index.lock if no other git process is running
    local lockfile="${repo_dir}/.git/index.lock"
    if [[ -f "$lockfile" ]]; then
        if ! pgrep -f "git.*$(basename "$repo_dir")" &>/dev/null; then
            log "$repo_dir" "Removing stale index.lock"
            rm -f "$lockfile"
        else
            log "$repo_dir" "index.lock exists and git is running — skipping"
            fail "$repo_name" "$remote" "index.lock held by another process"
            return 0
        fi
    fi

    # 4. Stash uncommitted changes if needed
    local stashed=false
    if ! git -C "$repo_dir" diff --quiet 2>/dev/null || \
       ! git -C "$repo_dir" diff --cached --quiet 2>/dev/null; then
        log "$repo_dir" "Stashing uncommitted changes"
        git -C "$repo_dir" stash push -m "pull-all auto-stash $(date +%s)" --quiet 2>/dev/null && stashed=true
    fi

    # 5. Fetch, checkout, merge
    local err=""
    if ! git -C "$repo_dir" fetch "$remote" "$branch" --quiet 2>/dev/null; then
        err="fetch failed"
    elif git -C "$repo_dir" rev-parse --verify "$branch" &>/dev/null; then
        # Branch exists locally — just switch to it
        if ! git -C "$repo_dir" checkout "$branch" --quiet 2>/dev/null; then
            err="checkout failed"
        fi
    else
        # Branch doesn't exist locally — create tracking branch
        if ! git -C "$repo_dir" checkout -b "$branch" "${remote}/${branch}" --quiet 2>/dev/null; then
            err="checkout -b failed"
        fi
    fi

    if [[ -z "$err" ]]; then
        # Set tracking so manual `git pull` works afterwards
        git -C "$repo_dir" branch --set-upstream-to="${remote}/${branch}" "$branch" --quiet 2>/dev/null || true
        # Merge from fetched ref — no tracking info dependency
        if ! git -C "$repo_dir" merge --ff-only "${remote}/${branch}" --quiet 2>/dev/null; then
            err="merge failed (local branch diverged from ${remote}/${branch}?)"
        fi
    fi

    # 6. Restore stash if we stashed
    if $stashed; then
        git -C "$repo_dir" stash pop --quiet 2>/dev/null || \
            log "$repo_dir" "⚠ stash pop had conflicts — resolve manually"
    fi

    if [[ -n "$err" ]]; then
        log "$repo_dir" "FAILED: ${err}"
        fail "$repo_name" "$remote" "$err"
    else
        log "$repo_dir" "✓ pulled ${branch}"
        ok "$repo_name" "$remote" "$branch"
    fi
}

# ── Discover repos ──────────────────────────────────────────────────────────
REPOS=()
while IFS= read -r line; do
    REPOS+=("$line")
done < <(find "$ROOT_DIR" -maxdepth 3 -type d -name ".git" 2>/dev/null \
    | sed 's|/\.git$||' | sort)

if [[ ${#REPOS[@]} -eq 0 ]]; then
    echo "No git repositories found under ${ROOT_DIR}"
    exit 0
fi

printf "${C_BOLD}Found %d repositories under %s${C_RESET}\n\n" "${#REPOS[@]}" "$ROOT_DIR"

# ── Run (sequential or parallel) ───────────────────────────────────────────
if [[ "$PARALLEL_JOBS" -gt 1 ]] && command -v xargs &>/dev/null; then
    export -f process_repo find_tetherto_remote resolve_branch log ok skip fail
    export REMOTE_PATTERN BRANCH_PRIORITY_STR="${BRANCH_PRIORITY[*]}"
    export DRY_RUN QUIET RESULTS_FILE
    export C_GREEN C_RED C_YELLOW C_CYAN C_BOLD C_RESET
    printf '%s\0' "${REPOS[@]}" | xargs -0 -P "$PARALLEL_JOBS" -I{} bash -c 'process_repo "$@"' _ {}
else
    for repo in "${REPOS[@]}"; do
        process_repo "$repo"
    done
fi

# ── Summary report ──────────────────────────────────────────────────────────
echo ""
printf "${C_BOLD}═══ Summary ═══════════════════════════════════════════════════${C_RESET}\n"
printf "${C_BOLD}%-35s %-12s %-10s %s${C_RESET}\n" "REPOSITORY" "REMOTE" "STATUS" "DETAIL"
printf "%-35s %-12s %-10s %s\n"   "──────────" "──────" "──────" "──────"

COUNT_OK=0 COUNT_SKIP=0 COUNT_FAIL=0

while IFS='|' read -r status repo remote detail; do
    case "$status" in
        OK)
            printf "${C_GREEN}%-35s %-12s %-10s %s${C_RESET}\n" "$repo" "$remote" "✓ pulled" "$detail"
            ((COUNT_OK++)) ;;
        SKIP)
            printf "${C_YELLOW}%-35s %-12s %-10s %s${C_RESET}\n" "$repo" "$remote" "⊘ skipped" "$detail"
            ((COUNT_SKIP++)) ;;
        FAIL)
            printf "${C_RED}%-35s %-12s %-10s %s${C_RESET}\n" "$repo" "$remote" "✗ failed" "$detail"
            ((COUNT_FAIL++)) ;;
    esac
done < "$RESULTS_FILE"

echo ""
printf "${C_GREEN}Pulled: %d${C_RESET}  ${C_YELLOW}Skipped: %d${C_RESET}  ${C_RED}Failed: %d${C_RESET}  Total: %d\n" \
    "$COUNT_OK" "$COUNT_SKIP" "$COUNT_FAIL" "$((COUNT_OK + COUNT_SKIP + COUNT_FAIL))"

# Exit with failure code if anything failed
[[ "$COUNT_FAIL" -eq 0 ]]
