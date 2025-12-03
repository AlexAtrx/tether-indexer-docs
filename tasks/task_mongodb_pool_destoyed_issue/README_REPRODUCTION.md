# MongoDB Pool Destruction - Reproduction Guide

**Status:** Ready to share with dev team  
**Last Updated:** November 27, 2025

---

## 🎯 Goal

Reproduce the production error: `[HRPC_ERR]=Pool was force destroyed`

---

## ⚡ Quick Reproduction

### Automated Script (Recommended)

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue
./REPRODUCE_ERROR.sh
```

This script will:
- Start MongoDB in Docker
- Start EVM indexer
- Stop MongoDB to trigger the error
- Show logs with the error

### Manual Steps

1. **Start MongoDB**
   ```bash
   docker run -d --name mongodb_test -p 27017:27017 mongo:5
   ```

2. **Start EVM Indexer**
   ```bash
   cd wdk-indexer-wrk-evm
   node worker.js --wtype wrk-evm-indexer-proc --chain eth
   # In another terminal:
   node worker.js --wtype wrk-evm-indexer-api --chain eth --proc-rpc <KEY>
   ```

3. **Trigger Error**
   ```bash
   docker stop mongodb_test
   ```

4. **Observe Logs** - Check indexer logs for MongoDB connection errors

---

## 📋 Files Created

### For Reproduction
- [`REPRODUCE_ERROR.sh`](file:///Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue/REPRODUCE_ERROR.sh) - Automated reproduction script
- [`HOW_TO_REPRODUCE.md`](file:///Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue/HOW_TO_REPRODUCE.md) - Detailed manual guide

### Fix (Stashed for Later)
- [`mongodb-retry-fix.patch`](file:///Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue/mongodb-retry-fix.patch) - Git patch with retry logic
- [`api.indexer.wrk.retry.unit.test.js.backup`](file:///Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue/api.indexer.wrk.retry.unit.test.js.backup) - Unit tests for fix
- [`HOW_TO_RESTORE_FIX.md`](file:///Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue/HOW_TO_RESTORE_FIX.md) - How to apply the fix

### Analysis
- [`COMPREHENSIVE_ANALYSIS.md`](file:///Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue/COMPREHENSIVE_ANALYSIS.md) - Full investigation journey
- [`implementation_plan.md`](file:///Users/alexa/.gemini/antigravity/brain/14770f5b-cf29-4786-9018-b9e06e4cde7d/implementation_plan.md) - Technical fix plan
- [`walkthrough.md`](file:///Users/alexa/.gemini/antigravity/brain/14770f5b-cf29-4786-9018-b9e06e4cde7d/walkthrough.md) - Complete fix walkthrough

---

## 🔍 What Causes the Error

**Location:** `wdk-indexer-wrk-base/workers/api.indexer.wrk.js:166`

```javascript
async queryTransfersByAddress (req) {
  return this.db.transfers.findByAddressAndTimestamp(...).toArray()
  // ❌ NO ERROR HANDLING
}
```

**Trigger:** MongoDB becomes unavailable → driver destroys pool → query throws error

**Error Flow:**
```
MongoDB Pool Destroyed
  ↓
MongoError('Pool was force destroyed')
  ↓
hp-svc-facs-net wraps as [HRPC_ERR]=
  ↓
Data-shard sees: [HRPC_ERR]=Pool was force destroyed
```

---

## ✅ Expected Error Output

When successfully reproduced, you'll see:

**Indexer logs:**
```
MongoNetworkError: connect ECONNREFUSED 127.0.0.1:27017
```

**Data-shard logs (if running):**
```
Error: [HRPC_ERR]=Pool was force destroyed
    at NetFacility.handleInputError (hp-svc-facs-net/index.js:58:11)
    at blockchain.svc.js:415:21
```

---

## 🛠️ Fix Available

Once you've reproduced and want to apply the fix:

```bash
cd wdk-indexer-wrk-base
git apply ../docs/task_mongodb_pool_destoyed_issue/mongodb-retry-fix.patch
cp ..._docs/task_mongodb_pool_destoyed_issue/api.indexer.wrk.retry.unit.test.js.backup tests/api.indexer.wrk.retry.unit.test.js
```

The fix adds retry logic with exponential backoff (200ms → 400ms, max 2 retries) to handle transient MongoDB failures.

---

## 📚 Share with Team

Send colleagues this file or point them to:
- **Quick start:** `./REPRODUCE_ERROR.sh`
- **Manual guide:** [`HOW_TO_REPRODUCE.md`](file:///Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue/HOW_TO_REPRODUCE.md)
- **Analysis:** [`COMPREHENSIVE_ANALYSIS.md`](file:///Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue/COMPREHENSIVE_ANALYSIS.md)
