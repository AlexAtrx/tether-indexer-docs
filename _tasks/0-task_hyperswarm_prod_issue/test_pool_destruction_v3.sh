#!/bin/bash

# Pool Destruction Test v3 - Improved to prevent sync job interference
# This test reproduces the Hyperswarm RPC pool timeout race condition

set -e  # Exit on error

echo "=== Pool Destruction Test v3 ==="
echo "This test will:"
echo "1. Connect to establish API session"
echo "2. Create a wallet (establishes RPC connection between data-shard and indexer)"
echo "3. Delete the wallet (stops sync jobs from resetting pool timeout)"
echo "4. Wait 35 seconds for pool to be destroyed (poolLinger: 30s)"
echo "5. Make balance request to trigger pool use between data-shard and indexer"
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

echo "✅ Connected: $CONNECT_RESPONSE"
echo ""

# Generate unique Ethereum address
# Format: 0x + 40 hex digits (20 bytes) = 42 chars total
# Use /dev/urandom for true randomness
TIMESTAMP=$(date +%s)
RANDOM_ADDR="0x$(od -An -N20 -tx1 /dev/urandom | tr -d ' \n')"
WALLET_NAME="pool-test-$TIMESTAMP-$$"  # Include PID for extra uniqueness

echo "[Step 1] Creating wallet with random address..."
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
      \"addresses\": {
        \"ethereum\": \"$RANDOM_ADDR\"
      }
    }
  ]")

# Check if wallet creation succeeded
if echo "$CREATE_RESPONSE" | grep -q "ERR_WALLET_ALREADY_EXISTS"; then
  echo "❌ Wallet already exists - run cleanup_mongo_test_wallets.sh first"
  echo "Response: $CREATE_RESPONSE"
  exit 1
elif echo "$CREATE_RESPONSE" | grep -q "\"error\""; then
  echo "❌ Error creating wallet:"
  echo "$CREATE_RESPONSE"
  exit 1
else
  echo "✅ Wallet created successfully"
  echo "$CREATE_RESPONSE" | jq '.' 2>/dev/null || echo "$CREATE_RESPONSE"
fi

# Extract wallet ID from response
WALLET_ID=$(echo "$CREATE_RESPONSE" | jq -r '.[0].id // .[0]._id // empty' 2>/dev/null)

if [ -z "$WALLET_ID" ]; then
  echo "⚠️  Could not extract wallet ID from response"
  echo "Cannot proceed with test - need wallet ID to delete and trigger balance check"
  exit 1
fi

echo ""
echo "[Step 2] Deleting wallet to stop sync jobs from using the pool..."
echo "Wallet ID: $WALLET_ID"

# Delete wallet using MongoDB directly (no DELETE endpoint in API)
DELETE_RESULT=$(mongosh "mongodb://localhost:27017/rumble_data_shard_wrk_data_shard_proc_shard_1" --quiet --eval "db.wdk_data_shard_wallets.deleteOne({id: '$WALLET_ID'})" | tail -1)

echo "$DELETE_RESULT"

if echo "$DELETE_RESULT" | grep -q '"deletedCount": 1'; then
  echo "✅ Wallet deleted - sync jobs will stop using this wallet"
else
  echo "⚠️  Wallet deletion unclear, continuing anyway..."
fi

echo ""
echo "[Step 3] Waiting 35 seconds for RPC pool to be destroyed (poolLinger=30s)..."
echo "The pool between data-shard-proc and indexer-proc should be destroyed after 30s of inactivity"
for i in {35..1}; do
  echo -ne "\rTime remaining: ${i}s  "
  sleep 1
done
echo -e "\n"

echo "[Step 4] Making balance request to trigger pool usage..."
echo "This will cause data-shard-proc to make an RPC call to indexer-proc"
echo "If the pool was destroyed, we should see the error in data-shard-proc logs"
echo ""

# Make a balance request which will trigger RPC calls from data-shard to indexer
BALANCE_RESPONSE=$(curl -s --request GET \
  --url "$API_URL/api/v1/balance" \
  --header "$AUTH_HEADER")

echo "Balance response: $BALANCE_RESPONSE"
echo ""

echo "🔍 Now check Terminal 3 (data-shard-proc) for:"
echo "   [RPC_TRACE] RPC request FAILED ... Pool was force destroyed"
echo ""

sleep 2

echo ""
echo "=== Test Complete ==="
echo ""
echo "📋 Next steps:"
echo "1. Check Terminal 3 (data-shard-proc) for pool destruction errors"
echo "2. Look for: [RPC_TRACE] RPC request FAILED ... Pool was force destroyed"
echo "3. If error appeared, collect traces as per NEXT_STEPS.md"
echo "4. If no error, the timing might not have aligned - try running again"
echo ""
