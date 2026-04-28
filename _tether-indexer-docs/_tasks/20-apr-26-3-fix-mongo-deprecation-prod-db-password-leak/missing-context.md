# Missing context

## Resolved (filled in 2026-04-20)

- ~~**Slack thread** (`C0A5DFYRNBB` / ts `1776091206.320369`)~~ — pasted by Alex, saved to `slack-thread.md`.
- ~~**Merged PR URLs**~~ — captured from the Slack thread:
  - https://github.com/tetherto/wdk-ork-wrk/pull/115
  - https://github.com/tetherto/wdk-indexer-wrk-base/pull/104
- ~~**Pinning decision**~~ — branch name (not commit hash) per Vigan; tether-wallet security-review guidance to pin by commit hash was knowingly pushed back on. See `slack-thread.md`.

## Still open

- [ ] **Data shard follow-up**: Vigan said "we need data shard as well" both in the Slack thread and in the Asana comment, but the merged PRs only cover `wdk-ork-wrk` and `wdk-indexer-wrk-base`. **Need from Alex:** which repo is "the data shard" (likely `wdk-data-shard-wrk` or similar — confirm via `repos.md`), and whether anyone has opened a PR there yet. **Source:** Vigan, Slack thread + Francesco's Asana comment 2026-04-14.
- [ ] **Real log snippet showing the leak**: only the Loki queries are in the ticket — no sample line. Useful if we need to verify the fix retroactively or check whether other services (data shard, anything else still on the old `bfx-facs-db-mongo` master) are still leaking. **Need from Alex:** one Loki hit from prod or staging, before/after the fix. **Source:** description.
- [ ] **Production incident timestamp**: "this happened in production during a deployment" — exact deployment date and which indexer service emitted the leaked URL is not recorded. Low priority now that PRs are merged, but useful for the post-incident write-up. **Source:** description.
