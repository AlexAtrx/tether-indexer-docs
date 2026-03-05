<!-- Based on Vigan suggestion -->

# Transaction History v2 — Data Shard Upgrade Plan

## Approach

No new service layer. Extend the existing `wdk-data-shard-wrk` parsing logic and add a new RPC method + route in `wdk-app-node`. The existing `getWalletTransfers` and `getUserTransfers` stay untouched — no breaking changes.

---

## What already exists (and will be reused, not rewritten)

**`api.shard.data.wrk.js` — `getWalletTransfers()` (lines 441-507):**

- Wallet validation + address resolution via `wallet.addresses`
- Stream-based transfer retrieval via `walletTransferRepository.getTransfersForWalletInRange`
- `type: "sent"/"received"` computation using `walletAddress.includes(tx.from)`
- Filtering (token, blockchain, type, date range)
- Pagination (skip, limit, sort)

**`api.shard.data.wrk.js` — `getUserTransfers()` (lines 312-435):**

- Multi-wallet merge with sorted iterator pattern
- Same filtering + type computation across all user wallets

**`price.calculator.js`:**

- Fiat price enrichment already runs at storage time → `fiatAmount` and `fiatCcy` already stored on each transfer

**`proc.shard.data.wrk.js`:**

- Real-time transfer ingestion via Redis streams
- Batch sync via `syncWalletTransfersJob`

---

## What needs to change

### 1. New RPC method in `api.shard.data.wrk.js`

Add `getWalletTransferHistory(req)` alongside the existing `getWalletTransfers`. Same input signature, same wallet resolution, same streaming — but with a **grouping + enrichment step** before returning.

```
getWalletTransfers     → returns flat transfers (unchanged, backward-compatible)
getWalletTransferHistory → returns grouped + enriched transfers (new)
```

The new method reuses the same plumbing:

```js
async getWalletTransferHistory (req) {
  const {
    userId, walletId, from, to, token, blockchain,
    type, limit = 10, skip = 0, sort = 'desc'
  } = req

  // --- REUSE: same wallet resolution as getWalletTransfers ---
  const wallet = await this.db.walletRepository.getActiveWallet(walletId)
  if (!wallet || wallet.userId !== userId) throw new Error('ERR_WALLET_NOT_FOUND')
  const walletAddresses = Object.values(wallet.addresses || {})
  if (!walletAddresses.length) throw new Error('ERR_WALLET_ADDRESS_NOT_FOUND')

  // --- REUSE: same stream + filtering ---
  const reverse = sort.toLowerCase() === 'asc'
  const fromTs = from ? new Date(from).getTime() : 0
  const toTs = to ? new Date(to).getTime() : Date.now()
  const stream = this.db.walletTransferRepository.getTransfersForWalletInRange(
    wallet.id, fromTs, toTs, reverse
  )

  // --- NEW: group by transactionHash ---
  const txGroups = new Map()  // transactionHash → [transfers]
  for await (const tx of stream) {
    if (token && tx.token !== token) continue
    if (blockchain && tx.blockchain !== blockchain) continue
    const key = tx.transactionHash
    if (!txGroups.has(key)) txGroups.set(key, [])
    txGroups.get(key).push(tx)
  }

  // --- NEW: parse each group into a logical transaction ---
  let transfers = []
  for (const [txHash, rawTransfers] of txGroups) {
    const parsed = parseTransferGroup(txHash, rawTransfers, walletAddresses, this.conf)
    if (type && parsed.type !== type.toLowerCase()) continue
    transfers.push(parsed)
  }

  // sort + paginate
  transfers.sort((a, b) => reverse ? a.ts - b.ts : b.ts - a.ts)
  transfers = transfers.slice(skip, skip + limit)

  return { transfers }
}
```

### 2. New parsing function: `parseTransferGroup`

This is the core of the upgrade — a pure function that takes a group of raw transfers sharing the same `transactionHash` and returns a single logical transaction. Can live in `workers/lib/transfer.parser.js`.

```js
/**
 * @param {string} transactionHash
 * @param {Array<WalletTransferEntity>} rawTransfers - all transfers sharing this txHash
 * @param {string[]} walletAddresses - all addresses belonging to this wallet
 * @param {object} conf - blockchain config (for explorer URLs, chain metadata)
 * @returns {object} parsed logical transaction
 */
function parseTransferGroup(
  transactionHash,
  rawTransfers,
  walletAddresses,
  conf,
) {
  const first = rawTransfers[0];
  const isOwner = (addr) => walletAddresses.includes(addr);

  // --- Direction ---
  const hasSent = rawTransfers.some((tx) => isOwner(tx.from));
  const hasReceived = rawTransfers.some(
    (tx) => isOwner(tx.to) && !isOwner(tx.from),
  );
  let direction, type;

  if (hasSent && hasReceived) {
    direction = "self";
    type = "sent";
  } else if (hasSent) {
    direction = "out";
    type = "sent";
  } else {
    direction = "in";
    type = "received";
  }

  // --- Change detection (BTC) ---
  // Mark underlying transfers where `to` is one of the wallet's own addresses
  // and direction is outbound → that's a change output
  const underlyingTransfers = rawTransfers.map((tx) => ({
    transactionHash: tx.transactionHash,
    transferIndex: tx.transferIndex,
    transactionIndex: tx.transactionIndex ?? null,
    logIndex: tx.logIndex ?? null,
    blockNumber: tx.blockNumber,
    from: tx.from,
    to: tx.to,
    token: tx.token,
    amount: tx.amount,
    ts: tx.ts,
    label: tx.label || "transaction",
    isChange: direction === "out" && isOwner(tx.to),
  }));

  // --- Primary from/to ---
  // from: for outbound, it's the wallet address. For inbound, it's the external sender.
  // to: for outbound, it's the non-change recipient. For inbound, it's the wallet address.
  let primaryFrom, primaryTo;
  if (direction === "out" || direction === "self") {
    const outbound =
      underlyingTransfers.find((tx) => !tx.isChange) || underlyingTransfers[0];
    primaryFrom = outbound.from;
    primaryTo = outbound.to;
  } else {
    const inbound =
      rawTransfers.find((tx) => isOwner(tx.to)) || rawTransfers[0];
    primaryFrom = inbound.from;
    primaryTo = inbound.to;
  }

  // --- Amount ---
  // For outbound: sum of non-change outputs (what actually left the wallet to external parties)
  // For inbound: sum of transfers where to = wallet address
  let amount;
  if (direction === "out" || direction === "self") {
    const nonChange = underlyingTransfers.filter((tx) => !tx.isChange);
    amount = nonChange
      .reduce((sum, tx) => sum + BigInt(tx.amount), 0n)
      .toString();
  } else {
    const received = rawTransfers.filter((tx) => isOwner(tx.to));
    amount = received
      .reduce((sum, tx) => sum + BigInt(tx.amount), 0n)
      .toString();
  }

  // --- Sponsored ---
  const sponsored = rawTransfers.some(
    (tx) => tx.label === "paymasterTransaction",
  );

  // --- Fiat amount ---
  // Use the fiatAmount from the primary transfer if available
  const primaryTx =
    direction === "out"
      ? rawTransfers.find((tx) => !isOwner(tx.to)) || rawTransfers[0]
      : rawTransfers.find((tx) => isOwner(tx.to)) || rawTransfers[0];
  const fiatAmount = primaryTx.fiatAmount || null;
  const fiatCcy = primaryTx.fiatCcy || null;

  // --- Network metadata ---
  const chainConf = conf.blockchains?.[first.blockchain] || {};
  const rail = resolveRail(first.blockchain);
  const chainId = resolveChainId(first.blockchain);
  const networkName = resolveNetworkName(first.blockchain);
  const explorerUrl = buildExplorerUrl(first.blockchain, transactionHash);

  return {
    transactionHash,
    ts: first.ts,
    updatedAt: first.ts,
    blockchain: first.blockchain,
    rail,
    chainId,
    networkName,
    token: first.token,
    symbol: resolveSymbol(first.token),
    decimals: resolveDecimals(first.token),
    type,
    direction,
    status: "confirmed",
    amount,
    fiatAmount,
    fiatCcy,
    from: primaryFrom,
    to: primaryTo,
    fromMeta: {
      addressType: resolveAddressType(primaryFrom, first.blockchain),
      isSelf: isOwner(primaryFrom),
      appResolved: null, // Phase 2: Rumble addon
    },
    toMeta: {
      addressType: resolveAddressType(primaryTo, first.blockchain),
      isSelf: isOwner(primaryTo),
      appResolved: null, // Phase 2: Rumble addon
    },
    fees: {
      sponsored,
      networkFee: null, // Phase 2: requires fee data in index
    },
    explorerUrl,
    label: first.label || "transaction",
    appActivitySubtype: null, // Phase 2: Rumble addon
    appContext: null, // Phase 2: Rumble addon
    appTip: null, // Phase 2: Rumble addon
    underlyingTransfers,
  };
}
```

### 3. Helper functions in the same file (`transfer.parser.js`)

Static config-driven lookups — no external calls:

```js
const RAIL_MAP = {
  ethereum: "EVM",
  sepolia: "EVM",
  plasma: "EVM",
  arbitrum: "EVM",
  polygon: "EVM",
  tron: "TRON",
  ton: "TON",
  solana: "SOL",
  bitcoin: "BTC",
  spark: "SPARK",
};

const CHAIN_ID_MAP = {
  ethereum: 1,
  sepolia: 11155111,
  arbitrum: 42161,
  polygon: 137,
  plasma: null,
  tron: null,
  ton: null,
  solana: null,
  bitcoin: null,
  spark: null,
};

const NETWORK_NAME_MAP = {
  ethereum: "Ethereum",
  sepolia: "Sepolia",
  plasma: "Plasma",
  arbitrum: "Arbitrum One",
  polygon: "Polygon",
  tron: "Tron",
  ton: "TON",
  solana: "Solana",
  bitcoin: "Bitcoin",
  spark: "Spark",
};

const EXPLORER_TX_URL_MAP = {
  ethereum: "https://etherscan.io/tx/",
  sepolia: "https://sepolia.etherscan.io/tx/",
  arbitrum: "https://arbiscan.io/tx/",
  polygon: "https://polygonscan.com/tx/",
  tron: "https://tronscan.org/#/transaction/",
  ton: "https://tonviewer.com/transaction/",
  solana: "https://solscan.io/tx/",
  bitcoin: "https://mempool.space/tx/",
  spark: null,
  plasma: null,
};

const TOKEN_META = {
  usdt: { symbol: "USDT", decimals: 6 },
  usdt0: { symbol: "USDT0", decimals: 6 },
  xaut: { symbol: "XAUT", decimals: 6 },
  xaut0: { symbol: "XAUT0", decimals: 6 },
  btc: { symbol: "BTC", decimals: 8 },
};

const resolveRail = (blockchain) => RAIL_MAP[blockchain] || "UNKNOWN";
const resolveChainId = (blockchain) => CHAIN_ID_MAP[blockchain] ?? null;
const resolveNetworkName = (blockchain) =>
  NETWORK_NAME_MAP[blockchain] || blockchain;
const resolveSymbol = (token) =>
  TOKEN_META[token]?.symbol || token.toUpperCase();
const resolveDecimals = (token) => TOKEN_META[token]?.decimals ?? 18;

const resolveAddressType = (address, blockchain) => {
  const rail = RAIL_MAP[blockchain];
  if (rail === "EVM") return "EVM_ADDRESS";
  if (rail === "BTC") return "BTC_ADDRESS";
  if (rail === "SPARK") return "SPARK_ACCOUNT";
  if (rail === "TRON") return "TRON_ADDRESS";
  if (rail === "TON") return "TON_ADDRESS";
  if (rail === "SOL") return "SOL_ADDRESS";
  return "UNKNOWN";
};

const buildExplorerUrl = (blockchain, txHash) => {
  const base = EXPLORER_TX_URL_MAP[blockchain];
  return base ? `${base}${txHash}` : null;
};
```

### 4. User-level variant: `getUserTransferHistory`

Same pattern — reuse `getUserTransfers` iterator merging, but add the grouping step. The existing multi-wallet merge (`createWalletIterator` + sorted merge) stays the same; the grouping happens after collecting flat transfers.

```js
async getUserTransferHistory (req) {
  // Reuse the same multi-wallet resolution + sorted merge from getUserTransfers
  // but collect into txGroups Map instead of flat array, then parse each group.
  // walletAddresses = all addresses across all user wallets (already collected at line 337-348)
  // ...
}
```

### 5. New route in `wdk-app-node/workers/lib/server.js`

Add alongside the existing wallet token-transfers route:

```js
{
  method: 'GET',
  url: '/api/v1/wallets/:walletId/transfer-history',
  schema: {
    params: {
      type: 'object',
      additionalProperties: false,
      properties: {
        walletId: { type: 'string' }
      },
      required: ['walletId']
    },
    querystring: {
      type: 'object',
      additionalProperties: false,
      properties: {
        userId: { type: 'string' },
        token: { type: 'string' },
        blockchain: { type: 'string' },
        type: { type: 'string', enum: ['sent', 'received', 'swap_out', 'swap_in'] },
        from: { type: 'integer', minimum: 0 },
        to: { type: 'integer', minimum: 0 },
        limit: { type: 'integer', minimum: 1, default: 10 },
        skip: { type: 'integer', minimum: 0, default: 0 },
        sort: { type: 'string', enum: ['asc', 'desc'], default: 'desc' }
      }
    }
  },
  preHandler: async (req, rep) => {
    await runGuards([
      middleware.getAuth('secret')?.guard,
      middleware.auth.guard
    ], ctx, req)
  },
  handler: async (req, rep) => {
    return await service.ork.getWalletTransferHistory(ctx, req, rep)
  }
}
```

And the user-level variant:

```js
{
  method: 'GET',
  url: '/api/v1/users/:userId/transfer-history',
  schema: {
    // same shape as /users/:userId/token-transfers but with extended type enum
    // ...
  },
  preHandler: async (req, rep) => {
    await runGuards([
      middleware.getAuth('secret')?.guard,
      middleware.auth.guard
    ], ctx, req)
  },
  handler: async (req, rep) => {
    const res = await service.ork.getUserTransferHistory(ctx, req)
    return send200(rep, res)
  }
}
```

### 6. RPC proxy in `wdk-app-node/workers/lib/services/ork.js`

```js
const getWalletTransferHistory = async (ctx, req, rep) => {
  try {
    const payload = { walletId: req.params.walletId, ...req.query };
    const res = await rpcCall(ctx, req, "getWalletTransferHistory", payload);
    return rep.status(200).send(res);
  } catch (err) {
    if (err.message.includes("ERR_WALLET_NOT_FOUND")) {
      throw ctx.httpd_h0.server.httpErrors.notFound("ERR_WALLET_NOT_FOUND");
    }
    throw ctx.httpd_h0.server.httpErrors.internalServerError(err.message);
  }
};
```

---

## Files touched

| File                                                         | Change                                                                                      |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| `wdk-data-shard-wrk/workers/lib/transfer.parser.js`          | **NEW** — `parseTransferGroup` + static config maps                                         |
| `wdk-data-shard-wrk/workers/api.shard.data.wrk.js`           | Add `getWalletTransferHistory` + `getUserTransferHistory` methods                           |
| `wdk-app-node/workers/lib/server.js`                         | Add 2 new routes (`/wallets/:walletId/transfer-history`, `/users/:userId/transfer-history`) |
| `wdk-app-node/workers/lib/services/ork.js`                   | Add RPC proxy methods                                                                       |
| `wdk-app-node/workers/lib/middlewares/response.validator.js` | Add response schema for new endpoints                                                       |

**No changes** to:

- Existing `getWalletTransfers` / `getUserTransfers` (untouched)
- Transfer storage/ingestion (`proc.shard.data.wrk.js`)
- Database schema / repositories
- Price calculator

---

## What this delivers (Phase 1)

- Grouped transactions (BTC change + recipient = 1 entry)
- Direction: `in` / `out` / `self`
- Type: `sent` / `received` (extensible to `swap_out` / `swap_in` when swap addresses are configured)
- Change detection via wallet's own addresses (no `known_addresses` param needed — wallet already knows its addresses)
- Explorer URLs
- Network metadata (rail, chainId, networkName)
- Token metadata (symbol, decimals)
- Sponsored/gasless flag from existing `paymasterTransaction` label
- `fiatAmount` / `fiatCcy` carried through from existing stored data
- Underlying raw transfers with `isChange` flag
- Null placeholders for Phase 2 fields (appTip, appContext, appResolved, fees.networkFee)

## What it doesn't deliver yet (Phase 2)

- Swap detection (needs configured swap partner addresses)
- Fee breakdown (needs fee data indexed or RPC call)
- Pending/failed status (needs pending tx tracking)
- Rumble addons: tip info, counterparty resolution, app context
