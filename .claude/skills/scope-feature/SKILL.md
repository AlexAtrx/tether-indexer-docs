# Scope a feature: Rumble fork vs WDK / Tether-Wallet / indexer base

Before writing any code for a feature, bug, or refactor, decide **which layer and
repo owns each concern**, so Rumble-specific logic lands in the `rumble-*` forks
and never leaks into the shared WDK / Tether-Wallet / indexer base. This exists
because the same mistake keeps recurring: a change is made in a shared `wdk-*` /
`bfx-*` base, then has to be torn out and moved into the Rumble backend later
(e.g. RW-1998 promo, where the `promo` wallet type was first added to
`wdk-app-node` and `wdk-data-shard-wrk` and had to be relocated to
`rumble-app-node` / `rumble-data-shard-wrk`).

**Default assumption: a feature is Rumble-only unless proven shared.** Most work
here is Rumble. Only touch the Tether-Wallet / indexer base when there is a
concrete reason a non-Rumble consumer needs the change.

## Triggers

- "is this rumble-only" / "is this purely Rumble or does it touch the rest"
- "which repo / layer owns this" / "where should this change go"
- "scope this feature" / "separate the concerns" / "split this by layer"
- Any time you are about to start a feature/bug/refactor and have not yet decided
  the owning repos.

This skill is also invoked automatically by `handle-ticket` as a mandatory gate
at the start of its implementation flow (Step 5), so it runs on every code change
without having to be asked for.

## The fork model (the thing to internalise)

The Rumble backend is a set of **forks that extend** the WDK / Tether-Wallet
base, plus a few Rumble-only workers. Each fork extends its base class and adds
Rumble behaviour with the override pattern (`super.<method>(...)` then add):

| Rumble fork | extends | WDK / Tether-Wallet base |
|---|---|---|
| `rumble-app-node` | → | `wdk-app-node` |
| `rumble-ork-wrk` | → | `wdk-ork-wrk` |
| `rumble-data-shard-wrk` | → | `wdk-data-shard-wrk` |

Rumble-only workers with no base: `rumble-promo-wrk`, `rumble-wallet-lib-passkey`.

Shared, used by non-Rumble consumers (the Tether Wallet app, the public
indexer), so they must stay **product-agnostic**:

- `wdk-app-node`, `wdk-ork-wrk`, `wdk-data-shard-wrk` (the bases above)
- `wdk-indexer-app-node`, `wdk-indexer-processor-wrk`, `wdk-indexer-wrk-*`,
  `wdk-indexer-wrk-base`
- `bfx-*`, `svc-facs-*`, any `*-base` library
- wallet libs: `wdk`, `wdk-wallet`, `wdk-wallet-*`, `wdk-react-native-core`,
  `wdk-protocol-*`

(Full roles in `.claude/repos.md`.)

## The litmus test (one question)

For each concern, ask:

> **If a non-Rumble product (the Tether Wallet app, or the public indexer) used
> this base, would this change still make sense and be wanted there?**

- **No** → it is Rumble. Put it in the `rumble-*` fork via the override pattern,
  or in a Rumble-only worker. Do **not** edit the base.
- **Yes** → it is genuinely shared. It may go in the `wdk-*` / indexer / lib base
  (still the highest bar; you are changing something every consumer inherits).
- **The base must change for the Rumble behaviour to be possible at all** (a hook
  point doesn't exist yet) → add **only a generic, product-agnostic hook** to the
  base (an overridable method, a config-driven value) and put the Rumble specifics
  in the fork. Never name a Rumble concept in the base.

### Precedents to copy (RW-1998)

- `_isDuplicateWallet(candidate, existing)` was extracted into `wdk-data-shard-wrk`
  as a generic overridable hook (knows only `user` / `channel`);
  `rumble-data-shard-wrk` overrides it to add the Rumble `promo` singleton rule.
- `rumble-app-node` teaches the inherited wallets route to accept `type: 'promo'`
  by patching the route schema in its own `_setupRoutes`
  (`_enablePromoWalletType`), leaving `wdk-app-node`'s `walletEnum` generic.

## Domain signals (fast classification)

**Rumble-domain → fork or Rumble-only worker:** promo wallets / promo codes, tip
jars, rants, channels (as Rumble content), push / FCM notifications, webhooks to
the Rumble server or Fivetran, MoonPay, swaps, cashout / topup, Rumble SSO / auth
proxy, device-id management, mobile logs, anything tied to the Rumble product or
its web/auth backend.

**Shared → base (high bar):** generic wallet CRUD, balances, transfers, chain
indexing / processing, entropy / seed storage, address lookup, generic HRPC
plumbing, circuit breakers, schema/codec scaffolding, anything every WDK consumer
needs regardless of product.

Note that `user` / `channel` / `unrelated` wallet types are already the WDK base's
**generic vocabulary**; a brand-new type, enum value, HRPC method, or schema field
that encodes a Rumble concept is the classic thing that belongs in the fork.

## Steps

1. **Decompose** the feature into concerns (each distinct behaviour, endpoint,
   stored field, or validation rule).
2. **Classify** each concern with the litmus test → `rumble fork` | `rumble-only
   worker` | `wdk base` | `indexer` | `wallet lib` | `cross-cutting infra`.
3. **Map to the exact repo** (`.claude/repos.md`). For Rumble-only concerns, target
   the `rumble-*` fork and confirm the fork actually extends the base method /
   route you would otherwise touch (so the override pattern is available).
4. **Apply the hook rule** to any concern that still wants a base edit for a Rumble
   reason: generic hook in the base, specifics in the fork. Re-run the litmus test
   before any base edit; a base edit driven by a Rumble feature is the single
   biggest red flag.
5. **Stop and ask Alex only when genuinely ambiguous** (you cannot confidently
   answer the litmus test, or it is unclear whether the Tether Wallet app /
   indexer also needs the behaviour). When the answer is clear, proceed without
   asking. When leaning, default to Rumble-only. Use a single focused question
   (or `grill-me` if several decisions interlock).
6. **Output the layer map** before editing anything:

   ```
   <concern>  →  <owning repo>  →  <mechanism>  →  <one-line why>
   ```

   e.g. `accept promo wallet type → rumble-app-node → patch wallets route schema
   in _setupRoutes → promo is Rumble-only, base stays generic`.

## Hard rules

- Default Rumble-only unless proven shared.
- Never encode a Rumble concept (a wallet-type value, HRPC method, schema field,
  enum, route) into a `wdk-*` / `bfx-*` / `svc-facs-*` / `*-base` / wallet-lib
  repo. If a base change is genuinely unavoidable, it must be generic and
  product-agnostic.
- Read-only and advisory: this skill decides ownership and produces the map. The
  actual edits happen in the implementation flow.
- No em dashes in anything handed back to Alex.
