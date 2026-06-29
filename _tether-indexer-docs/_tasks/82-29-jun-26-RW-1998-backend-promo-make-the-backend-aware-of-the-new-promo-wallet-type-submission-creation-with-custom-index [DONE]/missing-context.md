# Missing context — [Backend Promo] ... (RW-1998)

The ticket itself is **empty** — no description, no comments, no attachments. All real
context has to come from the parent and from Alex.

- [ ] **Empty ticket:** RW-1998 has no description or acceptance criteria — **Need from Alex:** the actual BE requirements (which repo owns the `promo` wallet type, where the index + details are stored, whether this touches `wdk-app-node` / `rumble-app-node` / data-shard, what the submission/creation API looks like). **Source:** ticket is blank.

- [ ] **Parent scope is FE-flavoured:** the parent RW-1991 describes mostly FE behaviour (disable buttons, only show in tipping flow). The BE-specific contract (schema for the `Promo` type, custom-index derivation, storage) is not written down anywhere yet. **Need from Alex:** confirm the BE design before implementation. **Source:** parent RW-1991.

- [ ] **Design document:** Eddy asked for a design doc on the parent — **Need from Alex:** link it if it exists. **Source:** Eddy WM on RW-1991, 2026-06-24.

- [ ] **FE draft PR:** https://github.com/tetherto/rumble-wallet-app-mobile/pull/1311 — useful to read the FE contract the BE must satisfy (wallet type/index shape). **Source:** Aliaksei Shaltykou on RW-1991, 2026-06-29.

## Related task folder
- Parent / FE milestone: RW-1991 — `_tasks/81-29-jun-26-RW-1991-separate-wallet-for-promo/`
