# Image analysis

Both screenshots are from the **rumble-staging** Mongo cluster, collection
`wdk_data_shard_wallets`, filtered by `{userId: 'AyEKJHDxJuc'}` (the test user
Ashot was wiping during the Slack debugging session on 2026-03-31). They were
posted by Vigan at 9:28 PM as evidence of the dirty state that drove the bug
ticket.

## mongo-shard-w_2_1-clean.png

**Source comment:** Vigan, ~2026-03-31 21:28 (Slack thread)

**What it shows:** Mongo UI on shard collection `wdk_shard_wrk_data_shard_proc_w_2_1 > wdk_data_shard_wallets`. One document for `userId: 'AyEKJHDxJuc'`.

**Key content:**
- `_id`: `ObjectId('69cac81238969b3164cc2e4f')`
- `id`: `f9a26108-9bc4-4977-9f59-160f34e882a3`
- `accountIndex`: `0`
- `addresses.ethereum/arbitrum/polygon/plasma`: `0x0b0c22e544293ac91eb9c178b44ab990fa7fdddd`
- `addresses.bitcoin`: `bc1qjq0vqw8ddx3gash85un63tn6k0c57heehxdwqc`
- `addresses.spark`: `spark1pgssx9dptl6vkd9389t6vjcgszazcq3xgjgltx6rfnh82gg8awgczntey74tlx`
- `createdAt`: `1774897170786` → 2026-03-31 21:19:30 UTC
- **`deletedAt`: `0`** (clean — wallet is live)
- `enabled`: `true`
- `updatedAt`: `1774897171185`
- `name`: `devka1`, `type`: `unrelated`

**Relevance:** This is the *correct* post-purge state — the wallet that Ashot
recreated after Vigan ran `purgeUserData`. `deletedAt: 0` means "not deleted"
and the row is fine. This shard (`w_2_1`) is the **new** shard the user was
re-assigned to.

## mongo-shard-w_2_2-soft-deleted.png

**Source comment:** Vigan, ~2026-03-31 21:28 (Slack thread)

**What it shows:** Mongo UI on shard collection `wdk_shard_wrk_data_shard_proc_w_2_2 > wdk_data_shard_wallets`. Three documents for `userId: 'AyEKJHDxJuc'`, all with non-zero `deletedAt`.

**Key content:** (three rows, same `userId`, same `name: devka1`, same `type: unrelated`, same `accountIndex: 0`)

| `_id` | `id` | `createdAt` | `deletedAt` (non-zero!) |
| --- | --- | --- | --- |
| `69caa09538969b3164c1e772` | `cb97fab1-e997-4401-b8b9-4035a65533f4` | 1774887061878 | **1774888554723** |
| `69caac8c38969b3164c565ff` | `d8cdab9a-40da-49c9-81b8-098eefe44fbe` | 1774890124035 | **1774890725498** |
| `69caaf4e38969b3164c607fd` | `7627a850-dd44-448d-8e7b-03f327dda03b` | 1774890830864 | **1774896344732** |

**Relevance:** This is the **buggy** state on the user's **previous** shard
(`w_2_2`). Each row is a soft-deleted wallet with `deletedAt > 0`. The same
addresses live across rows. Per Vigan's diagnosis at 11:25 PM, when
`purgeUserData` runs but the user is **re-assigned to the same shard** as
before, the existing wallet rows are not cleared — `deletedAt` is left at its
old non-zero value, and the dedup check on POST `/wallets` then rejects
re-registration with `ERR_ADDRESS_ALREADY_EXISTS`. In this particular session
the user happened to be reassigned to a *different* shard (`w_2_1`), which is
why the next POST succeeded — but the bug remains for the same-shard case.
