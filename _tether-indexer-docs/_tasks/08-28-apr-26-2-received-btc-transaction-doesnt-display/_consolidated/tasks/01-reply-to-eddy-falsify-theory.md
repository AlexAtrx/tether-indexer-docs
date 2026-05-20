# Task 01 — Reply to Eddy on Asana with the falsified-theory rebuttal

**Priority:** highest. This is the immediate ball-in-court move.

**Why:** Eddy's 2026-04-20 11:05 deflection ("might have been created long time ago, very old in the address generation on wdk side") was an assumption, not an investigation. The 2026-04-28 WDK-derivation check disproves it. Replying now closes off the dead-end framing and re-points the team at the actual investigation Alex asked for on 2026-04-20.

## Draft reply (paste into the Asana comment)

> Hey @Eddy WM
>
> I checked `wdk-wallet-btc` end-to-end. It only supports bip44 + bip84 and has never had a taproot / bip86 code path on any branch — `git log --all -S` for `p2tr`, `bip86`, and `taproot` returns zero functional hits since the initial commit on 2025-05-01. The repo description on GitHub literally reads "WDK module to manage BIP-84 (SegWit) wallets for the Bitcoin blockchain".
>
> So the `bc1q…` segwit format is not a legacy artefact — it's exactly what the WDK BTC lib produces today on `main`. A "very old WDK address generation" cannot be the cause; there has been no derivation switch.
>
> If anything, the puzzle inverts: the *taproot* `bc1p…` addresses returned by `/wallets` for this user (`bc1pu036…` and `bc1p9phk…`) are the ones that *cannot* have come from `wdk-wallet-btc`. They're produced by some other derivation path on the BE side.
>
> The decisive question is still where the FE sources `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` from (since `/wallets` doesn't contain it), and what produces the taproot addresses in `/wallets` (since `wdk-wallet-btc` doesn't). Those are the two FE/BE investigations I asked for on 2026-04-20 — they're still owed.

## Before posting

- Re-read `_consolidated/03-investigation.md` Part 3 to make sure the citations are accurate.
- Trim/lengthen as you prefer. Don't soften the disagreement — the 2026-04-20 reply was a dodge and the team's time is being wasted.

## When done

- Mark this task complete here.
- Update `_consolidated/01-summary.md` "Where things stand" to reflect the new ball-in-court state (now Eddy's again).
- Move to Task 02.
