# Task 04 — Investigate the local-vs-backend wallet-count delta (5 vs 4)

**Priority:** medium. May be the same investigation as Task 02 but on the FE side; it answers a different question (where the segwit address lives), so kept separate.

**Why:** the `walletSync: {"localWalletCount":5,"backendWalletCount":4}` log entry at 2026-04-06 17:21:13 is the clearest observable marker of the bug class. The 5th local wallet — the one not in `/wallets` — is where `bc1qgm7k56…` is stored. Identifying its storage location and contents pins the bug to a specific FE module/store and gives us a precise fix target.

## What to find

1. Which FE module owns the local wallet store (almost certainly `walletSync` based on log lines).
2. The storage backend (MMKV / AsyncStorage / secure keychain) and the key/path.
3. The full payload of the 5th wallet entry, especially:
   - Its `accountIndex` (the four BE wallets occupy indexes 0 and 1 — what's the 5th's index?)
   - Its derivation metadata
   - Its `bitcoin` address (verify it's `bc1qgm7k56…`)
4. How it got there:
   - bip84 derivation from the seed at install/upgrade time (most likely)
   - Carried forward from a pre-migration build
   - Seeded by an old FE version that derived `bc1q` addresses

## Where to look (FE repo)

The mobile FE repo. Suggested grep targets, in priority order:
- `walletSync` module — the log calls it out by name; find its source file and trace the local-store API.
- `offlineWalletAccessService`
- `hooks/useResyncWalletsLackingAddresses`, `hooks/useBackendWalletResetCheck`, `hooks/useWalletBackendSync`, `hooks/useWalletValidation`
- `[QRCodeDisplay]` component — find the prop that supplies the bitcoin address it renders, and trace upstream.
- Any code path that calls `wdk-wallet-btc` directly — that's where segwit addresses are generated client-side.

## Reproducing locally (if needed)

Use the staging credentials in `_consolidated/02-evidence.md` (`klemens.andrew@gmail.com` / `1234qQ1234!` / seed `elephant adjust birth still van radio ecology young belt april range enable`). The bug was still reproducible on app v2.0.3 as of 2026-04-06; should still reproduce on a current dev build if no FE fix has shipped.

## Output

A note in `_consolidated/03-investigation.md` (new section: "Part 5 — Local 5th wallet"). Then either roll the finding into the Asana update for Task 02 or add a separate comment.
