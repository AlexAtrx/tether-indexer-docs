# Missing context

- [ ] Environment: the ticket never states which environment the repro was done
  on (staging vs prod). Device builds "v2.3 (654) / (742)" suggest QA builds.
  **Need from Alex:** confirm environment (staging cluster? dev? prod) so the
  right indexer/shard logs can be checked. **Source:** description.
- [ ] People / decisions: comment cc's two Asana profiles
  (https://app.asana.com/1/45238840754660/profile/1211860479278729 and
  https://app.asana.com/1/45238840754660/profile/1213406456321934) that the API
  could not resolve to names. **Need from Alex:** who was cc'd (likely BE
  leads), and whether there is a parallel Slack conversation about this
  regression. **Source:** Gocha Gafrindashvili, 2026-06-10T13:25:49Z.
- [ ] Logs: no logs, tx hashes, wallet addresses, or screenshots attached at
  all — only test account credentials/seed phrases. **Need from Alex:** at
  least one concrete example (network + tx hash + receiving account) and/or
  access to the env to reproduce. **Source:** description.
- [ ] Deploy timeline: "visible yesterday … recent regression" implies
  something was deployed or changed between 2026-06-09 and 2026-06-10.
  **Need from Alex:** what was deployed to that environment in that window
  (indexer wrk, data shard, app node, FE build). **Source:** comment +
  Alex's note at fetch time.
