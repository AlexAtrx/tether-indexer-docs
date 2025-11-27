# MongoDB Pool Destruction Investigation

This folder contains the investigation into production errors showing `[HRPC_ERR]=Pool was force destroyed`.

## Quick Start

1. **Read This First:** [`COMPREHENSIVE_ANALYSIS.md`](./COMPREHENSIVE_ANALYSIS.md)
   - Complete investigation journey
   - All findings and theories
   - Current understanding of the issue

2. **Production Evidence:** [`production_logs.log`](./production_logs.log)
   - OCR'd error logs from production screenshots
   - Shows exact timing and stack traces

3. **Next Steps:** [`INDEXER_INVESTIGATION_PLAN.md`](./INDEXER_INVESTIGATION_PLAN.md)
   - Detailed plan to investigate indexer MongoDB connection
   - Checklist of actions
   - Test procedures

## Key Finding

**Original diagnosis was likely wrong.** The error appears to be:
- ❌ NOT a Hyperswarm RPC `poolLinger` timeout issue
- ✅ LIKELY a MongoDB connection pool issue in the INDEXER
- ✅ Error gets wrapped by `hp-svc-facs-net` as `[HRPC_ERR]=`

## Test Scripts

All test scripts have been copied to this folder:

- `test_pool_destruction_v4.sh` - Hyperswarm pool test (failed to reproduce)
- `test_pool_destruction_v5.sh` - Enhanced version (failed to reproduce)  
- `test_mongodb_pool_auto.sh` - Data-shard MongoDB test (failed to reproduce)
- `test_indexer_mongodb.sh` - Indexer MongoDB test (current focus)
- `cleanup_mongo_test_wallets.sh` - Cleanup helper
- `_run_the_test_repeat.sh` - Run tests multiple times

## Investigation Status

**Current Phase:** Need indexer production logs and codebase review

**Next Action:** Follow steps in [`INDEXER_INVESTIGATION_PLAN.md`](./INDEXER_INVESTIGATION_PLAN.md)

## Related

Original investigation folder: [`../_INDEXER/_docs/task_hyperswarm_prod_issue/`](../task_hyperswarm_prod_issue/)
