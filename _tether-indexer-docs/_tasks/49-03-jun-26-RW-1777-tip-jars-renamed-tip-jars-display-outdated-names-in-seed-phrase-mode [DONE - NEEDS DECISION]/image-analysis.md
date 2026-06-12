# Image analysis

## 1215023267903769-tip-jar-names.png

**Source comment:** Task description (attached by Gocha Gafrindashvili, 2026-05-21T15:13:35Z)

**What it shows:** Two side-by-side mobile screenshots of the wallet's "Choose Balance View" tip jar selection list. A red arrow connects an entry on the left screenshot to the corresponding entry on the right, highlighting the name discrepancy.

**Key content:**
- Header: "Balance" with total `$5.68` (left screenshot), times shown 6:27 / 18:27.
- Both show a "Choose Balance View" bottom sheet listing tip jars, each `$0.00`, subtitle "Tip Jar".
- **Left screenshot** (correct state): list includes `9Channell`, `10Channell`, `11Channell`, `12Channell`, **`13ChannellRenamed`** (red box), `14Channell`, `15Channell`, `16Channell`, `17Deleted`.
- **Right screenshot** (stale state): same list but the same entry shows **`13Channell`** (red box) instead of `13ChannellRenamed` — `10Channell`…`12Channell`, `13Channell`, `14Channell`…`17Deleted`.
- Red arrow points from `13ChannellRenamed` (left) to `13Channell` (right), evidencing that the renamed value is not reflected.

**Relevance:** Directly demonstrates the bug — the same tip jar appears with its updated name (`13ChannellRenamed`) in one view but with the old/default name (`13Channell`) in the seed-phrase-mode balance selection list. Per Ahsan's comment, the stale list comes from the `api/v1/seed-phrases/connect/verify` endpoint not returning updated names.
