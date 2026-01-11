# Balance Oscillation Fix - Decision Conclusion

## Summary of the Situation

Your PRs implement deterministic (seeded) provider/peer selection to prevent balance oscillation. The fix works at two levels:

1. **Provider level** (`wdk-indexer-wrk-base`): `callWithSeed` pins addresses to providers with circuit-breaker fallback
2. **Peer level** (`wdk-data-shard-wrk`): seeded peer selection via `_rpcCall`

**Objections raised:**
- **Usman**: Reduced failover if seeded indexer is down; different wallet lists still oscillate
- **Vigan**: 15-minute potential downtime in data-shard; load balancing degradation vs round-robin

## Analysis of the Three Options

### Option 1: Park the whole thing

**Not recommended.** The PRs have already received two approvals (kulwindertether and SargeKhan) on both the base PR #63 and data-shard PR #138. The objections raised are valid concerns but not outright rejections. Parking loses significant work and leaves a known user-facing issue unresolved.

### Option 2: Upgrade the design to address concerns

**Recommended approach.** The objections are addressable:

| Concern | Fix |
|---------|-----|
| No failover in `wdk-data-shard-wrk` | Add explicit fallback: on failure, try next seed or fall back to `jTopicRequest` (you already mentioned this in Slack) |
| 15-min cache causing downtime | Reduce TTL or add health-aware cache invalidation |
| Load imbalance vs round-robin | Hash distribution across providers is still uniform per-address; monitor and tune if needed |
| Different wallet lists oscillate | Document this as expected behavior; UI should consistently query same address sets |

The provider-level fix (`callWithSeed` with circuit-breaker fallback) already handles failover properly. The data-shard layer is where most concerns apply, and adding a fallback path there addresses the core availability objection.

### Option 3: Cancel and live with oscillation

**Acceptable but suboptimal.** The oscillation is indeed intermittent and temporary (self-correcting once caches align). However:
- It causes user confusion and support burden
- The provider-level fix is solid and low-risk
- Abandoning now wastes the work already done and approved

## Recommended Decision

**Go with Option 2: Upgrade the design.**

Specifically:
1. **Merge the provider-level fix** (`wdk-indexer-wrk-base` #63 and chain-specific PRs) - these are approved and have proper fallback behavior
2. **Enhance `wdk-data-shard-wrk` #138** with an explicit fallback path:
   - On seeded peer failure, retry with `jTopicRequest` (random peer selection)
   - Consider reducing the 15-min lookup cache TTL or making it configurable
3. **Document** the expected behavior that different wallet list shapes may still produce different results (this is acceptable since identical requests are now stable)

This approach:
- Addresses the valid availability concerns
- Preserves the core oscillation fix
- Respects the work already invested and approved
- Maintains load balancing via hash distribution

If the team is unwilling to accept even the enhanced design, Option 3 (cancel) is a defensible fallback - but push for Option 2 first since the objections have concrete solutions.
