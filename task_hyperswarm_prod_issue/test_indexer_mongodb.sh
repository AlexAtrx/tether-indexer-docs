#!/bin/bash

# Test: MongoDB Pool Destruction at INDEXER Level
# Theory: The error might be coming from MongoDB operations INSIDE the indexer,
# not from Hyperswarm RPC pools. When the indexer can't query MongoDB,
# it returns an error that gets wrapped as [HRPC_ERR]=Pool was force destroyed

set -e

echo "=== MongoDB Indexer Pool Destruction Test ==="
echo ""
echo "Theory: The indexer queries MongoDB -> MongoDB pool destroyed -> error wrapped as [HRPC_ERR]="
echo ""

API_URL="http://127.0.0.1:3000"
AUTH_HEADER="authorization: Bearer test_auth-"

# Step 1: Create a wallet to trigger sync
echo "[Step 1] Creating wallet to trigger sync job..."
TIMESTAMP=$(date +%s)
RANDOM_ADDR="0x$(od -An -N20 -tx1 /dev/urandom | tr -d ' \n')"
WALLET_NAME="indexer-mongo-test-$TIMESTAMP-$$"

curl -s --request POST \
  --url "$API_URL/api/v1/wallets" \
  --header "$AUTH_HEADER" \
  --header "content-type: application/json" \
  --data "[{
    \"name\": \"$WALLET_NAME\",
    \"type\": \"user\",
    \"enabled\": true,
    \"addresses\": {
      \"ethereum\": \"$RANDOM_ADDR\"
    }
  }]" > /dev/null

echo "✅ Wallet created"
echo ""

# Step 2: Wait a bit for wallet to be saved
sleep 2

# Step 3: Trigger many queries that will hit the indexer
echo "[Step 2] Triggering 20 sync operations to hit the indexer..."
echo "(These will make RPC calls to indexer which queries MongoDB)"
echo ""

# Get the wallet ID first
WALLET_RESPONSE=$(curl -s --request GET \
  --url "$API_URL/api/v1/wallets" \
  --header "$AUTH_HEADER")

# Handle both array and object response formats
WALLET_ID=$(echo "$WALLET_RESPONSE" | jq -r 'if type == "array" then .[0].id else .id end // empty')

# Trigger multiple balance/transfer queries that will hit the indexer
for i in {1..20}; do
  # These API calls will cause RPC calls to the indexer
  curl -s --request GET \
    --url "$API_URL/api/v1/wallets/$WALLET_ID/transfers?limit=100" \
    --header "$AUTH_HEADER" > /dev/null 2>&1 &
    
  sleep 0.05
done

echo "✅ Fired 20 transfer query requests (all will RPC to indexer)"
echo ""

# Give requests a moment to start
sleep 0.3

# Step 4: Stop MongoDB that the INDEXER uses
echo "[Step 3] Stopping MongoDB that the INDEXER queries..."
echo ""
echo "⚠️  CRITICAL: We're stopping the MongoDB that the indexer-wrk-evm uses!"
echo "    Check your indexer's MongoDB connection string to confirm which database it uses."
echo ""

# The indexer might use a different MongoDB database than the data-shard
# Let's stop the primary to affect all databases
docker stop mongo1 > /dev/null 2>&1

echo "🛑 MongoDB primary stopped"
echo ""
echo "Now the indexer cannot query MongoDB for transfer data."
echo "When data-shard makes RPC calls, indexer will try to query MongoDB and fail."
echo ""

# Step 5: Wait for errors to propagate
echo "[Step 4] Waiting 3 seconds for errors to propagate..."
sleep 3

# Step 6: Restart MongoDB
echo "[Step 5] Restarting MongoDB..."
docker start mongo1 > /dev/null 2>&1
echo "✅ MongoDB restarted"
echo ""

sleep 2

echo ""
echo "=== Test Complete ==="
echo ""
echo "🔍 Check Terminal 3 (data-shard-proc) for:"
echo "   [HRPC_ERR]=Pool was force destroyed"
echo ""
echo "🔍 Also check Terminal 2 (indexer-api) for MongoDB errors:"
echo "   MongoError: Pool was force destroyed"
echo "   OR other MongoDB connection errors"
echo ""
echo "If the error appears in BOTH terminals:"
echo "  ✅ Confirms: MongoDB error in indexer -> wrapped as [HRPC_ERR]="
echo ""
echo "If error only in indexer terminal:"
echo "  ✅ Confirms: It's a MongoDB issue, not Hyperswarm"
echo ""
echo "If no error appears:"
echo "  ⚠️  Need to check which MongoDB the indexer actually uses"
echo ""

# Helper command
echo "Quick check:"
echo "  grep -i \"pool was force destroyed\" /tmp/data-shard-proc-trace.log"
echo ""
