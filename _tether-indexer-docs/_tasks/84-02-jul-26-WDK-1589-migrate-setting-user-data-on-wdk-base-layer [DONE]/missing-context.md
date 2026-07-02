# Missing context

- [x] External tickets: "Task related to WDK-1522" — **Resolved:** local folder
  `_tasks/83-01-jul-26-WDK-1522-support-setting-multiple-user-data-keys-in-one-request [DONE]/`.
  **Source:** description.
- [x] Slack thread: the ticket has a one-line description; the actual scope was agreed in
  the Slack thread Alex started on 2026-07-02 — **Resolved:** captured in
  `slack-context.md`. **Source:** conversation relayed by Alex.
- [x] Decisions: WDK-1522 merge order — **Resolved by Alex 2026-07-02:** fold WDK-1522
  into the base migration; close #169/#81/#141 in favor of the base PRs (close once the
  base PRs are open). Rumble wire changes (DELETE 204, validation errors 400) approved.
  **Source:** Alex, this session.
- [ ] Systems: does the "City" product (Label: "City Support") have its own fork with a
  user-data copy that must also be reconciled, or does it consume wdk-app-node directly?
  **Need from Alex:** confirm whether any `city-*` repos carry user-data code.
  **Source:** ticket Label custom field.
