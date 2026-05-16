# Missing context

The original bug-report context (Mongo screenshots + 2026-03-31 Slack
thread) was captured during the first fetch on 2026-05-15. The ork-side
fix has shipped in `wdk-ork-wrk#135`. The ticket is now re-scoped to a
Rumble-side migration — what's missing now is the PR-review discussion
that triggered the re-scope.

## Open — from the 2026-05-15 re-scope

- [ ] Slack: PR-review thread `https://tether-to.slack.com/archives/C0A5DFYRNBB/p1778861994960789?thread_ts=1778859257.013279&cid=C0A5DFYRNBB` — **Need from Alex:** export of the thread so Vigan's exact migration requirements (scope, dry-run expectations, shard set, idempotency) are on record. The ticket's "After Vigan's review let's create a migration" comes from this conversation. **Source:** description, re-edited 2026-05-15T18:51:32Z.
- [ ] GitHub: any PR-review comments left on `wdk-ork-wrk#135` that justify or scope the migration — **Need from Alex:** if Vigan left review comments on the PR itself, those should be linked / quoted. **Source:** inferred from ticket move to "PR OPEN" + description edit on the same day.

## Resolved (kept for reference)

- ~~Slack thread (channel `C0A5DFYRNBB`, parent `1774621065.566059`)~~ —
  captured in `attachments/slack-thread.txt`. Key diagnosis line from Vigan
  @ 23:25: "if user gets assigned to same shard then we don't reset
  deletedAt to 0, we should create a ticket in core be for this".
- ~~Exact failure mode on re-create after purge~~ — confirmed:
  `400 Bad Request — [HRPC_ERR]=ERR_ADDRESS_ALREADY_EXISTS` from
  `POST /api/v1/wallets` on `wallet-8s4anfsr6it9.rumble.com` (rumble-staging)
  when the same user re-onboards onto the same shard with the same seed.
- ~~Repo placement (WDK vs Rumble)~~ — original fix lives in `wdk-ork-wrk`
  (PR #135, generic ork correctness). The **migration** belongs in
  `rumble-ork-wrk/migrations/autobase/` per
  [[project_wdk_vs_rumble_repo_split]].

## External links (saved or referenced)

- Slack bug-report thread (saved as `attachments/slack-thread.txt`):
  `https://tether-to.slack.com/archives/C0A5DFYRNBB/p1774905922216999?thread_ts=1774621065.566059&cid=C0A5DFYRNBB`
- Slack PR-review thread (NOT yet saved):
  `https://tether-to.slack.com/archives/C0A5DFYRNBB/p1778861994960789?thread_ts=1778859257.013279&cid=C0A5DFYRNBB`
- GitHub PR (the shipped ork-side fix): https://github.com/tetherto/wdk-ork-wrk/pull/135
- GitHub (original code refs from the bug report):
  - https://github.com/tetherto/wdk-ork-wrk/blob/9d748c9f859083b78640865b724606aaf4051ac9/workers/api.ork.wrk.js#L300
  - https://github.com/tetherto/wdk-data-shard-wrk/blob/f69dbe8ac82b512e264c9fe5baf1644d5736b346/workers/proc.shard.data.wrk.js#L587
