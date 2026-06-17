# RW-1920 UMA: scope, gap, and the full-port sketch

Decision-ready note for Eddy / Rumble. Summarises what is built, what "real" UMA
needs, why there is a gap, and what the full receive port would touch.

## What is built today (this ticket)

`rumble-app-node` only. The wallet read/write endpoints now return a UMA config
block:

- `GET /wallets`, `GET /wallets/:id`, `GET /wallets/from-address/:address`,
  `POST /wallets`, `PATCH /wallets/:id` attach
  `uma: { domain, minSendable, maxSendable, defaultSettlementLayer }` to the
  user wallet, and echo the caller's immutable Rumble username
  (`preferred_username`) onto their own wallet.
- Domain is config-only (`conf.uma.domain`, required at boot); no storage, no
  schema change, no ork/shard change.

This is the **advertisement** of a UMA address. It lets the app display
`preferred_username@domain` and the send limits.

## The gap

It is not a working UMA feature. An external wallet / VASP cannot pay
`username@domain` against Rumble, because the **resolution path does not exist**:

- Rumble's `/.well-known/lnurlp/:sparkIdentityPubkey` still keys on the spark
  pubkey, not the username.
- There is no `username -> wallet` storage or lookup anywhere in the backend.
- So `alice9@rumble-domain` does not resolve to anything.

Two honest caveats:

- The `uma{}` slice is largely FE-derivable anyway: the username is the token's
  `preferred_username` (the app already holds it) and domain/limits are static
  config. On its own the backend slice adds little.
- Tether Wallet (`tether-wallet-app-node`) implements the **full** feature
  (username lifecycle + storage + `getUmaByUsername` + lnurlp-by-username +
  payreq returning invoices/addresses), so the complete version is proven and
  is the reference (`tw-reference/` in this folder).

## Why the gap (cause)

Not the immutable-username discovery. Immutability only removes the username
**management** surface (suggest / check / set / reset), which is a correct
reduction. It does **not** remove the resolution engine; if anything it makes it
simpler (the username is a stable token claim, so no uniqueness/availability
logic and no set/reset sync).

The gap came from a **scope decision**: `final-spec.md` leapt from "nothing to
manage" to "nothing to store or resolve," and its prose ("port lnurlp-by-
username") contradicted its decision section ("nothing stored"). The
contradiction was resolved by treating resolution as out of scope. That is the
step that left us advertisement-only.

## Decision needed from Rumble

1. Is the goal **UMA receive / interop** (pay-by-handle from external wallets)?
   - Yes -> the resolution port below is the real feature.
   - No, only **show the handle in-app** -> what exists is enough (or more than
     enough); label it "UMA address display", not "UMA implemented".
2. Confirm the open contract items (needed either way for correctness):
   - `preferred_username` is always present in the token for wallet users and
     stays stable; and the exact field name in `/-wallet/v1/me` (we read it
     defensively today).
   - The canonical UMA `domain` for each environment.
   - Which settlement layers / assets Rumble wants to advertise and accept.
   - Whether only `type: 'user'` wallets get a UMA address (assumed yes; channel
     / tip-jar wallets excluded).

## Full receive-port sketch (if UMA receive is wanted)

Immutability simplifies this: the username is captured once from the token at
wallet create, stored, never changed, and never taken from client input.

1. `wdk-data-shard-wrk` (+ mirror in `rumble-data-shard-wrk`)
   - Append `username` to the wallets HyperDB schema (append-only, after `meta`;
     `npm run db:build`), and to the Mongo wallet doc.
   - Add a unique `username -> wallet` lookup index + repo method
     (`getWalletByUsername`), staged through the unit of work (no direct store
     write; see `conventions.md`).
   - `addWallet`: persist `username` (from the token-sourced field); treat as
     write-once. `updateWallet`: never change it.
   - Version bump + dependent reinstall per the version-bump policy.

2. `wdk-ork-wrk` (+ mirror in `rumble-ork-wrk`)
   - Add HRPC `getUmaByUsername` (resolve username -> wallet via a new lookup,
     analogous to the existing address lookup `getWalletIdByAddress`), returning
     a serializable result (HRPC handlers must not return undefined).

3. `rumble-app-node`
   - Plumb `username` from the token into `POST /wallets` -> `ork.addWallet`
     (ssoHandler already surfaces it).
   - Port TW's UMA service/utils/constants (`tw-reference/`): `lnurlpLookup`,
     `lnurlpPay`, `handleUmaPayreq`, settlement-options builder, uma-chains
     constants. Drop suggest/check (immutable model).
   - Add `GET /.well-known/lnurlp/:username` (keyed on username; keep or retire
     the spark-pubkey route), `POST /api/uma/payreq/:uuid`; the existing
     `GET /api/lnurl/payreq/:uuid` already proxies to the spark indexer.
   - Extend `conf.uma` with supported chains / currencies; add response schemas.

4. `wdk-indexer-wrk-spark`
   - Lightning invoice creation already exists (`lnurl.js`). Likely minor: the
     app-node builds the `username@domain` identifier/metadata; the indexer
     mints the invoice. Verify the metadata/identifier it expects.

Effort: multi-repo with a HyperDB schema migration and version fan-out (the work
deliberately scoped out of this ticket). Risk concentrated in the schema append
+ uniqueness index and the lnurlp contract.

## Recommendation

Confirm goal (1) and the contract items (2) with Rumble before any further code.
If receive is wanted, raise it as its own ticket sized for the four-repo port
above; do not represent the current state as "UMA implemented".
