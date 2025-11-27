#!/bin/bash

# Pool Destruction Test v2 - Fixed
# This test reproduces the Hyperswarm RPC pool timeout race condition

set -e  # Exit on error

echo "=== Pool Destruction Test v2 ==="
echo "This test will:"
echo "1. Connect to establish API session"
echo "2. Create and enable a wallet (establishes RPC connection)"
echo "3. Wait 35 seconds for pool to be destroyed (poolLinger: 30s)"
echo "4. Wallet sync job will trigger and hit the destroyed pool"
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
  echo "❌ Wallet already exists - this shouldn't happen with timestamp-based addresses!"
  echo "Response: $CREATE_RESPONSE"
  echo ""
  echo "💡 Try clearing your database or running cleanup_test_wallets.sh"
  exit 1
elif echo "$CREATE_RESPONSE" | grep -q "\"error\""; then
  echo "❌ Error creating wallet:"
  echo "$CREATE_RESPONSE"
  exit 1
else
  echo "✅ Wallet created successfully"
  echo "$CREATE_RESPONSE" | jq '.' 2>/dev/null || echo "$CREATE_RESPONSE"
fi

echo ""
echo "[Step 2] Waiting 35 seconds for RPC pool to be destroyed (poolLinger=30s)..."
for i in {35..1}; do
  echo -ne "\rTime remaining: ${i}s  "
  sleep 1
done
echo -e "\n"

echo "[Step 3] Waiting for wallet sync job to run..."
echo "The syncWalletTransfersJob runs every 10 seconds and will make RPC calls"
echo "to the indexer through a pool that should be destroyed by now."
echo ""
echo "🔍 Watch Terminal 3 (data-shard-proc) for:"
echo "   [RPC_TRACE] RPC request FAILED ... Pool was force destroyed"
echo ""

# Wait for sync job to run (it runs every 10s, so wait up to 15s to be sure)
for i in {15..1}; do
  echo -ne "\rWaiting for sync job: ${i}s remaining  "
  sleep 1
done
echo -e "\n"

echo ""
echo "=== Test Complete ==="
echo ""
echo "📋 Next steps:"
echo "1. Check Terminal 3 (data-shard-proc) for pool destruction errors"
echo "2. Look for: [RPC_TRACE] RPC request FAILED ... Pool was force destroyed"
echo "3. If error appeared, collect traces as per NEXT_STEPS.md"
echo "4. If no error, try running the test again or check the troubleshooting section"
echo ""
