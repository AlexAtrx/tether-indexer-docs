#!/bin/bash

# Pool Destruction Test v4 - Relies on sync job timing
# This test reproduces the Hyperswarm RPC pool timeout race condition

set -e  # Exit on error

echo "=== Pool Destruction Test v4 ==="
echo "This test will:"
echo "1. Connect and create an ENABLED wallet (triggers initial sync)"
echo "2. Wait for ONE sync cycle to complete (~10s)"
echo "3. Disable wallet to stop future syncs"
echo "4. Wait 35 seconds for pool to be destroyed (poolLinger: 30s)"
echo "5. Re-enable wallet to trigger sync job which will hit destroyed pool"
echo ""

# Configuration
API_URL="http://127.0.0.1:3000"
AUTH_HEADER="authorization: Bearer test_auth-"

# Step 0: Connect to establish session
echo "[Step 0] Establishing API session..."
CONNECT_RESPONSE=$(curl -s --request POST \
  --url "$API_URL/api/v1/connect" \
  --header "$AUTH_HEADER" \
  --header "content-type: application/json" \
  --data '{}')

if [ $? -ne 0 ]; then
  echo "❌ Failed to connect to API"
  exit 1
fi

echo "✅ Connected"
echo ""

# Generate unique Ethereum address
TIMESTAMP=$(date +%s)
RANDOM_ADDR="0x$(od -An -N20 -tx1 /dev/urandom | tr -d ' \n')"
WALLET_NAME="pool-test-$TIMESTAMP-$$"

echo "[Step 1] Creating ENABLED wallet..."
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
  exit 1
fi

echo "✅ Wallet created and enabled: $WALLET_ID"
echo ""

echo "[Step 2] Waiting 15 seconds for first sync job to run and complete..."
echo "This ensures at least one RPC call has been made (establishing the pool)"
for i in {15..1}; do
  echo -ne "\rTime remaining: ${i}s  "
  sleep 1
done
echo -e "\n"

echo "[Step 3] Disabling wallet to stop sync jobs..."
DISABLE_RESPONSE=$(curl -s --request PATCH \
  --url "$API_URL/api/v1/wallets/$WALLET_ID" \
  --header "$AUTH_HEADER" \
  --header "content-type: application/json" \
  --data '{"enabled": false}')

echo "✅ Wallet disabled - sync jobs will skip it"
echo ""

echo "[Step 4] Waiting 35 seconds for RPC pool to be destroyed (poolLinger=30s)..."
echo "No RPC calls should be made during this time, allowing pool to timeout"
for i in {35..1}; do
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

echo "✅ Wallet re-enabled - next sync job will trigger RPC call"
echo ""

echo "[Step 6] Waiting up to 15 seconds for sync job to run..."
echo "The sync job runs every 10 seconds and will make an RPC call"
echo "to the indexer through the destroyed pool"
echo ""
echo "🔍 Watch Terminal 3 (data-shard-proc) for:"
echo "   [RPC_TRACE] Initiating RPC request to..."
echo "   [RPC_TRACE] RPC request FAILED ... Pool was force destroyed"
echo ""

for i in {15..1}; do
  echo -ne "\rWaiting for sync job: ${i}s remaining  "
  sleep 1
done
echo -e "\n"

echo ""
echo "=== Test Complete ==="
echo ""
echo "📋 Check Terminal 3 (data-shard-proc) for the error"
echo ""
