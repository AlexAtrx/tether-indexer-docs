# Ticket: Deprecate Legacy TOKEN_TRANSFER Inference for RANT/TIP

**Priority:** Medium
**Type:** Deprecation / Backend Enhancement
**Affected Repos:** `rumble-ork-wrk`, `rumble-data-shard-wrk`
**Depends On:** Phase 1 (ticket_phase1_introduce_explicit_types.md)

---

## Background

This ticket is **Phase 2** of the explicit transaction types initiative. It should only be executed **after Phase 1 is complete and mobile apps have migrated to the new explicit types**.

### Phase 1 Recap

Phase 1 introduced:
- `TOKEN_TRANSFER_RANT` - explicit rant type with strict validation
- `TOKEN_TRANSFER_TIP` - explicit tip type with strict validation
- Backward-compatible `TOKEN_TRANSFER` behavior with deprecation warnings

### Why Phase 2 Is Needed

The legacy `TOKEN_TRANSFER` type with field-based inference has caused production issues:

1. **Silent Failures**: When required fields (`dt`, `id`, `payload`) are missing, the backend silently skips webhook creation. No error is returned, and tips/rants never appear in chat.

2. **Untraceable Bugs**: The 21-Jan-2026 investigation revealed that missing `dt` or `id` causes the entire notification flow to silently fail. Without explicit types, these issues are nearly impossible to debug.

3. **Implicit Contract**: The API behavior depends on field combinations that are not documented or enforced, leading to miscommunication between frontend and backend teams.

Once mobile apps have adopted `TOKEN_TRANSFER_RANT` and `TOKEN_TRANSFER_TIP`, the legacy inference behavior becomes technical debt that should be removed.

---

## Prerequisites

Before starting this phase, confirm:

- [ ] Phase 1 has been deployed to production for at least 2-3 release cycles
- [ ] Mobile apps are using `TOKEN_TRANSFER_RANT` for all rant flows
- [ ] Mobile apps are using `TOKEN_TRANSFER_TIP` for all tip flows
- [ ] Monitoring shows near-zero usage of `TOKEN_TRANSFER` for rant/tip scenarios
- [ ] Mobile teams have confirmed migration is complete

---

## Implementation Tasks

### 1. Add Deprecation Header (`rumble-ork-wrk`)

**File:** `workers/api.ork.wrk.js`

When `TOKEN_TRANSFER` is used with rant/tip-like fields (`dt`, `id`, `payload`), add a response header:

```
X-Deprecated: TOKEN_TRANSFER with rant/tip fields is deprecated. Use TOKEN_TRANSFER_RANT or TOKEN_TRANSFER_TIP.
```

This provides visibility to clients without breaking them.

### 2. Add Metrics/Monitoring

Track usage of:
- `TOKEN_TRANSFER` with rant/tip fields (should trend toward zero)
- `TOKEN_TRANSFER_RANT` usage (should increase)
- `TOKEN_TRANSFER_TIP` usage (should increase)

Create alerts if legacy usage increases after deprecation announcement.

### 3. Update Documentation

Mark in API documentation:
- `TOKEN_TRANSFER` for rant/tip flows is **DEPRECATED**
- Include migration guide with before/after examples
- Document removal timeline

### 4. Remove Inference Logic (Final Step)

**After confirming zero legacy usage**, remove the inference logic:

**File:** `workers/api.ork.wrk.js`

- Remove code that infers RANT/TIP from `TOKEN_TRANSFER` based on field presence
- `TOKEN_TRANSFER` should only be used for regular transfers (no webhook creation for rant/tip)

**File:** `workers/proc.shard.data.wrk.js`

- Update `_processTxWebhooksJob` to only handle explicit types
- Remove any fallback logic for inferring intent from `TOKEN_TRANSFER`

### 5. Update Tests

- Remove test cases for legacy inference behavior
- Add test case: `TOKEN_TRANSFER` with rant/tip fields → no webhook (or warning)
- Ensure explicit types remain fully functional

---

## Migration Timeline (Suggested)

| Week | Action |
|------|--------|
| 0 | Phase 1 deployed |
| 1-4 | Mobile teams migrate to explicit types |
| 5 | Begin monitoring legacy usage |
| 6 | Add deprecation header |
| 8 | Notify teams of removal date |
| 12 | Remove inference logic (if usage is zero) |

---

## Acceptance Criteria

- [ ] Deprecation header is returned for legacy type usage
- [ ] Metrics track legacy vs. explicit type usage
- [ ] Documentation is updated with deprecation notice and migration guide
- [ ] Inference logic is removed after confirming zero legacy usage
- [ ] `TOKEN_TRANSFER` only creates webhooks for regular transfers
- [ ] All explicit type functionality remains intact

---

## Rollback Plan

If issues arise after removing inference logic:
1. Re-enable inference logic immediately
2. Notify mobile teams
3. Investigate which client version is still using legacy type
4. Coordinate hotfix or extend migration timeline

---

## Benefits of Completing Phase 2

1. **Clean Codebase**: Remove inference logic and edge cases
2. **Explicit Contracts**: All transaction types have clear, documented requirements
3. **No Silent Failures**: Every rant/tip either succeeds with webhook or returns an error
4. **Easier Debugging**: Type in logs directly indicates intent
5. **Reduced Cognitive Load**: New developers don't need to understand implicit field combinations

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Old app version still using legacy type | Medium | Medium | Monitor metrics, delay removal if needed |
| Mobile team misses migration | Low | Medium | Clear communication, multiple reminders |
| Webhook processing regression | Low | High | Comprehensive testing, staged rollout |

---

## Related Documentation

- Phase 1 ticket: `ticket_phase1_introduce_explicit_types.md`
- Original investigation: `_docs/_tasks/_rumble-tip-test-21-jan-2026/`
- Solution proposal: `_docs/_tasks/_rumble-tip-test-21-jan-2026/solution-suggestion.md`
