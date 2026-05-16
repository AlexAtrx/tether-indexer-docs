# Next steps for purgeUserData doesn't reset deletedAt

> **Superseded by [`STATUS.md`](./STATUS.md) (2026-05-15).** This file is the original triage plan written before the empirical investigation. The actual root cause and the fix that shipped are different from what is sketched below; keep this only as a record of the investigation path. Read `STATUS.md` first.

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213882531683489

## Bug, in one line

After `purgeUserData`, the ork's flat address→walletId lookup
(`@wdk-ork/wallet-id-lookups`) still contains the user's old addresses, so
the next `POST /api/v1/wallets` fails at the ork's `_validateWalletExistence`
with `400 ERR_ADDRESS_ALREADY_EXISTS` — even though the shard already
soft-deleted the wallet rows and the ork tried to cascade-clear the lookups.

The shard-side `deletedAt > 0` behaviour Vigan flagged in Slack is correct
soft-delete semantics; it's a red herring as the **direct cause**, but it's
why the ork's `_validateWalletExistence` falls through to the stale lookup
and trips the dedup error.

## Failure layer (confirmed by reading the code locally)

- **Shard** — `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:589 → 567 `_deleteAllUserData``
  soft-deletes each active wallet (`softDel(wallet.id)` sets
  `deletedAt = Date.now()`), then soft-deletes the user. Address-uniqueness
  check on `addWallet` (`getActiveWalletsByAddresses`, line 258) already
  filters by `deletedAt: { $lte: 0 }`, so the shard itself does **not**
  raise the error on re-create.
- **Ork** — `wdk-ork-wrk/workers/api.ork.wrk.js:301 purgeUserData` correctly
  calls `lookupStorage.delLookupsForUser(req.userId)` after the shard RPC.
  But the handler at `wdk-ork-wrk/workers/lib/db/autobase/lookup.storage.js:50`
  iterates `@wdk-ork/lookups-by-user`, **deletes each row in-stream**, and
  only afterwards tries to resolve the deleted walletIds back to addresses
  via `@wdk-ork/lookups-address-by-wallet-id` to clear
  `@wdk-ork/wallet-id-lookups`. If the secondary index is built off the
  same source rows that have just been deleted in the transaction, the
  second loop finds nothing for those walletIds and the address→walletId
  entries are left orphaned.
- The orphaned `@wdk-ork/wallet-id-lookups` rows are what
  `api.ork.wrk.js:411 _validateWalletExistence` → `getWalletIdByAddress`
  hits on the next `addWallet`, which throws `ERR_ADDRESS_ALREADY_EXISTS`.

## Decided fix

Fix the cascade in `delLookupsForUser`. Two reinforcing changes, both in
`wdk-ork-wrk`:

1. **Reorder `lookup.storage.js:50` so the cascade runs before deletion.**
   - First pass: stream `@wdk-ork/lookups-by-user`, collect
     `{walletId, addresses[]}` for every WALLETS-type row (using
     `@wdk-ork/lookups-address-by-wallet-id` to resolve addresses).
   - Second pass: `tx.delete` every collected address from
     `@wdk-ork/wallet-id-lookups`.
   - Third pass: `tx.delete` the user's `@wdk-ork/lookups` rows.
   - Single `tx.flush()` at the end, same transactional guarantees.
2. **Belt-and-braces:** have the shard's `purgeUserData` return the deleted
   walletIds, and have the ork's `purgeUserData` (after the shard RPC) loop
   over them and call `delWalletIdLookup(walletId)` directly. This path
   doesn't depend on the autobase index being healthy and self-heals even
   if a previous bug left `lookups-by-user` partially populated.

Picked this over the two earlier options because:
- "exclude `deletedAt != 0` from the dedup check on add" doesn't apply at
  the layer that's actually failing — the ork's `wallet-id-lookups` has no
  `deletedAt` column, and adding one to a flat append-only map would be a
  schema change + HyperDB version bump for no benefit.
- "reset `deletedAt` to 0 in purge" (literal interpretation of Vigan's
  Slack note) would resurrect soft-deleted rows whose transfer/balance
  history was already wiped — wrong semantics. Hard-deleting the rows
  instead is internally consistent but breaks the soft-delete audit trail
  that other code (and BI) relies on.

The decided fix is the smallest blast radius (one file, one method, no
schema change) and addresses the root cause directly.

## What to ship

- [ ] Patch `wdk-ork-wrk/workers/lib/db/autobase/lookup.storage.js:50`
  per change #1 above.
- [ ] Add return value to `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:589`
  `purgeUserData` so it returns the deleted walletIds.
- [ ] In `wdk-ork-wrk/workers/api.ork.wrk.js:301`, after the shard RPC, loop
  over the returned walletIds and `await this.lookupStorage.delWalletIdLookup(walletId)`.
- [ ] Tests:
  - Ork autobase unit test: after `delLookupsForUser`, the user's
    `wallet-id-lookups` rows are gone for every wallet the user had.
  - Ork integration test: `addWallet → purgeUserData → addWallet (same
    addresses)` returns `201`, not `400`.
  - Repro from the Slack thread: user on same shard, two onboarding cycles.
- [ ] No HyperDB schema change required, so no version bump per
  [[conventions]].
- [ ] No `rumble-*` changes per [[project_wdk_vs_rumble_repo_split]] — this
  is generic WDK purge correctness.

## Evidence captured here

- 0 user comments on the Asana ticket (system events only) in `comments.md`
- 2 images analysed in `image-analysis.md` (Mongo screenshots showing dirty
  `w_2_2` vs clean `w_2_1`)
- 1 non-image attachment: `attachments/slack-thread.txt` — the Slack
  discussion that drove the bug report
- Local code review on 2026-05-15 traced the failure to the ork autobase
  cascade in `delLookupsForUser` (not the shard's soft-delete).
