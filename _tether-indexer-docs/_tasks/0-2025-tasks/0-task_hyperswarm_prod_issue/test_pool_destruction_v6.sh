#!/bin/bash

# Pool Destruction Test v6 - forces a pool timeout by aligning sync interval with poolLinger
# Requires config: poolLinger=4500ms (config/facs/net.config.json r0), syncWalletTransfers="*/5 * * * * *" (config/common.json)
# Idea: sync runs every 5s, poolLinger is 4.5s. After a sync completes, the pool idles for ~4.5s, is destroyed,
# then the next sync (at ~5s) lands very close to the destruction window to try to hit the race.

set -euo pipefail

API_URL="http://127.0.0.1:3000"
AUTH_HEADER="authorization: Bearer test_auth-"

echo "=== Pool Destruction Test v6 (aligned timing) ==="
echo "Config expectations:"
echo "  - config/facs/net.config.json r0.poolLinger = 4500"
echo "  - config/common.json wrk.syncWalletTransfers = \"*/5 * * * * *\""
echo "Services: data-shard proc/api + indexer proc/api + ork + app-node"
echo ""

echo "[Step 0] Establishing API session..."
curl -s --request POST \
  --url "$API_URL/api/v1/connect" \
  --header "$AUTH_HEADER" \
  --header "content-type: application/json" \
  --data '{}' >/dev/null
echo "✅ Connected"
echo ""

TIMESTAMP=$(date +%s)
RANDOM_ADDR="0x$(od -An -N20 -tx1 /dev/urandom | tr -d ' \n')"
WALLET_NAME="pool-test-v6-$TIMESTAMP-$$"

echo "[Step 1] Creating ENABLED wallet (keep enabled; no disable/enable toggling)"
echo "Name: $WALLET_NAME"
echo "Address: $RANDOM_ADDR"

CREATE_RESPONSE=$(curl -s --request POST \
  --url "$API_URL/api/v1/wallets" \
  --header "$AUTH_HEADER" \
  --header "content-type: application/json" \
  --data "[
    {
      \"name\": \"$WALLET_NAME\",
      \"type\": \"user\",
      \"enabled\": true,
      \"addresses\": {
        \"ethereum\": \"$RANDOM_ADDR\"
      }
    }
  ]")

WALLET_ID=$(echo "$CREATE_RESPONSE" | jq -r '.[0].id // .[0]._id // empty' 2>/dev/null)

if [ -z "$WALLET_ID" ]; then
  echo "❌ Failed to create wallet. Response:"
  echo "$CREATE_RESPONSE"
  exit 1
fi

echo "✅ Wallet created: $WALLET_ID"
echo ""

echo "[Step 2] Wait through two sync cycles to hit the race window..."
echo "Timeline with current config:"
echo "  t=0s   first sync (creates pool)"
echo "  t=4.5s poolLinger expires → pool destroyed"
echo "  t=5s   next sync → expected to land during/just after destruction"
echo ""
echo "Watch data-shard proc logs for:"
echo "  [RPC_TRACE] Initiating RPC request..."
echo "  [RPC_TRACE] RPC request FAILED ... error=Pool was force destroyed"
echo ""

for i in {12..1}; do
  echo -ne "\rWaiting: ${i}s remaining  "
  sleep 1
done
echo -e "\n"

echo "[Step 3] Give one more sync cycle (safety) ..."
for i in {8..1}; do
  echo -ne "\rExtra wait: ${i}s remaining  "
  sleep 1
done
echo -e "\n"

echo "=== Test Complete ==="
echo "Check data-shard proc terminal or /tmp/data-shard-proc-trace.log for '[HRPC_ERR]=Pool was force destroyed'."
