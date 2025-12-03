# How to Restore the MongoDB Retry Fix

## Stashed Changes

The MongoDB retry logic fix has been stashed for later use. Here's how to restore it when needed.

## What Was Stashed

### 1. Modified File
- **`workers/api.indexer.wrk.js`** (+112 lines)
  - Added `_isMongoTransientError()` helper method (lines 107-122)
  - Added `_withMongoRetry()` retry wrapper method (lines 124-161)
  - Wrapped `getTransaction()` with retry (line 189)
  - Wrapped `queryTransactions()` with retry (lines 201-223)
  - Wrapped `queryTransfersByAddress()` with retry (lines 232-234)
  - Wrapped `getBlock()` with retry (lines 248-258)

### 2. New File
- **`tests/api.indexer.wrk.retry.unit.test.js`** (330 lines)
  - 6 comprehensive unit tests for retry logic

## How to Restore

### Option 1: Using Git Stash (Recommended)

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-base

# List stashes to find the right one
git stash list

# Apply the stash (keeps it in stash list)
git stash apply stash@{0}

# Or pop the stash (removes from stash list)
git stash pop stash@{0}
```

### Option 2: Using Saved Patch File

If a patch file was created:

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-base

# Apply the patch
git apply /path/to/mongodb-retry-fix.patch

# Or restore the test file
cp /path/to/api.indexer.wrk.retry.unit.test.js tests/
```

### Option 3: Manual Restoration

See the complete implementation in the artifacts:
- [`walkthrough.md`](file:///Users/alexa/.gemini/antigravity/brain/14770f5b-cf29-4786-9018-b9e06e4cde7d/walkthrough.md) - Full code with explanations
- [`implementation_plan.md`](file:///Users/alexa/.gemini/antigravity/brain/14770f5b-cf29-4786-9018-b9e06e4cde7d/implementation_plan.md) - Implementation details

## Verification After Restore

```bash
# Run linter
npm run lint:fix

# Run all tests
npm test

# Run retry-specific tests
npm test -- tests/api.indexer.wrk.retry.unit.test.js
```

## Files to Restore

1. `/Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-base/workers/api.indexer.wrk.js`
2. `/Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-base/tests/api.indexer.wrk.retry.unit.test.js`

## Git Stash Name

Look for: `WIP on dev: MongoDB retry logic fix for pool destruction errors`
