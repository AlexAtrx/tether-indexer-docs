#!/bin/bash

# Pool Destruction Test v5 - ROOT CAUSE FIX VERSION
# This test reproduces the Hyperswarm RPC pool timeout race condition
# 
# KEY FIX: Creates wallet addresses that match the configured blockchain indexers
# Based on root cause analysis showing that wallets with "ethereum" addresses
# are NOT synced when only XAUT indexer is running

set -e  # Exit on error

echo "=== Pool Destruction Test v5 - ROOT CAUSE FIX ===\"
echo "This version addresses the core issue: wallet addresses must match indexer config"
echo ""

# Configuration
API_URL="http://127.0.0.1:3000"
AUTH_HEADER="authorization: Bearer test_auth-"

echo "[Pre-Check] Verifying blockchain configuration..."
echo "Your rumble-data-shard-wrk/config/common.json should have:"
echo '  "blockchains": { "ethereum": { "ccys": ["xaut"] } }'
echo ""
echo "This means ONLY XAUT tokens on Ethereum will be synced!"
echo "Regular 'ethereum' addresses will be IGNORED by the sync job."
echo ""

# Step 0: Connect to establish session
echo "[Step 0] Establishing API session..."
CONNECT_RESPONSE=$(curl -s --request POST \
  --url "$API_URL/api/v1/connect" \
  --header "$AUTH_HEADER" \
  --header "content-type: application/json" \
  --data '{}')

if [ $? -ne 0 ]; then
  echo "❌ Failed to connect to API"
  echo "Make sure all services are running:"
  echo "  1. Terminal 1: indexer-proc --chain xaut-eth"
  echo "  2. Terminal 2: indexer-api --chain xaut-eth"
  echo "  3. Terminal 3: data-shard-proc"
  echo "  4. Terminal 4: data-shard-api"
  echo "  5. Terminal 5: ork-api"
  echo "  6. Terminal 6: app-node --port 3000"
  exit 1
fi

echo "✅ Connected"
echo ""

# Generate unique address
TIMESTAMP=$(date +%s)
RANDOM_ADDR="0x$(od -An -N20 -tx1 /dev/urandom | tr -d ' \n')"
WALLET_NAME="pool-test-v5-$TIMESTAMP-$$"

echo "[Step 1] Creating ENABLED wallet with XAUT address..."
echo "Name: $WALLET_NAME"
echo "Address: $RANDOM_ADDR"
echo ""
echo "🔑 KEY FIX: Using blockchain='ethereum' so it matches the config!"
echo "   The sync job will iterate: blockchains['ethereum']['ccys'] = ['xaut']"
echo "   And make RPC call: ethereum:xaut -> queryTransfersByAddress"
echo ""

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

# Check if wallet creation succeeded
if echo "$CREATE_RESPONSE" | grep -q "ERR_WALLET_ALREADY_EXISTS"; then
  echo "❌ Wallet already exists - run cleanup_mongo_test_wallets.sh first"
  exit 1
elif echo "$CREATE_RESPONSE" | grep -q "\"error\""; then
  echo "❌ Error creating wallet:"
  echo "$CREATE_RESPONSE"
  exit 1
fi

WALLET_ID=$(echo "$CREATE_RESPONSE" | jq -r '.[0].id // .[0]._id // empty' 2>/dev/null)

if [ -z "$WALLET_ID" ]; then
  echo "⚠️  Could not extract wallet ID"
  echo "Response: $CREATE_RESPONSE"
  exit 1
fi

echo "✅ Wallet created and enabled: $WALLET_ID"
echo ""

echo "[Step 2] Waiting 15 seconds for first sync job to run..."
echo "Watch Terminal 3 (data-shard-proc) NOW for:"
echo "  ✅ [RPC_TRACE] Initiating RPC request to... method=queryTransfersByAddress"
echo "  ✅ [RPC_TRACE] RPC request successful to..."
echo ""
echo "If you DON'T see [RPC_TRACE] logs, the problem persists!"
echo ""

for i in {15..1}; do
  echo -ne "\rTime remaining: ${i}s  "
  sleep 1
done
echo -e "\n"

# Quick check
echo "⚠️  PAUSE - Did you see [RPC_TRACE] logs in Terminal 3?"
echo "   If YES: Great! The RPC pool is being used. Continue to Step 3."
echo "   If NO: Stop here. The sync job is still not making RPC calls."
echo ""
echo "Press ENTER to continue (or Ctrl+C to stop)..."
read -r

echo "[Step 3] Disabling wallet to stop sync jobs..."
DISABLE_RESPONSE=$(curl -s --request PATCH \
  --url "$API_URL/api/v1/wallets/$WALLET_ID" \
  --header "$AUTH_HEADER" \
  --header "content-type: application/json" \
  --data '{"enabled": false}')

echo "✅ Wallet disabled"
echo ""

echo "[Step 4] Waiting 10 seconds for RPC pool to be destroyed..."
echo "poolLinger is set to 5000ms (5 seconds) in config/facs/net.config.json"
echo "After 5 seconds of no RPC activity, the pool should be destroyed"
echo ""

for i in {10..1}; do
  echo -ne "\rTime remaining: ${i}s  "
  sleep 1
done
echo -e "\n"

echo "[Step 5] Re-enabling wallet to trigger sync job..."
ENABLE_RESPONSE=$(curl -s --request PATCH \
  --url "$API_URL/api/v1/wallets/$WALLET_ID" \
  --header "$AUTH_HEADER" \
  --header "content-type: application/json" \
  --data '{"enabled": true}')

echo "✅ Wallet re-enabled"
echo ""

echo "[Step 6] Waiting up to 15 seconds for sync job..."
echo ""
echo "🔍 NOW WATCH Terminal 3 CAREFULLY for:"
echo "   [RPC_TRACE] Initiating RPC request to..."
echo "   ❌ [RPC_TRACE] RPC request FAILED ... Pool was force destroyed"
echo ""
echo "This is the ERROR we're trying to reproduce!"
echo ""

for i in {15..1}; do
  echo -ne "\rWaiting for sync job: ${i}s remaining  "
  sleep 1
done
echo -e "\n"

echo ""
echo "=== Test Run Complete ==="
echo ""
echo "📋 Check Terminal 3 (data-shard-proc) for the target error:"
echo "   Look for: [HRPC_ERR]=Pool was force destroyed"
echo ""
echo "If you didn't see it, try running this test multiple times:"
echo "   ./_run_the_test_repeat.sh"
echo ""
