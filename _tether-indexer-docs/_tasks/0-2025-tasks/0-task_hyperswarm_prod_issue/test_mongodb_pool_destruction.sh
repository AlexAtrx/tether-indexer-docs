#!/bin/bash

# MongoDB Pool Destruction Test
# This test reproduces the "Pool was force destroyed" MongoDB error
# by triggering MongoDB pool destruction while database operations are pending

set -e

echo "=== MongoDB Pool Destruction Test ==="
echo ""
echo "This test will trigger the MongoDB 'Pool was force destroyed' error by:"
echo "1. Creating heavy MongoDB load (many wallet operations)"
echo "2. Triggering MongoDB replica set failover/reconnection"
echo "3. Pending operations will fail with 'Pool was force destroyed'"
echo ""

API_URL="http://127.0.0.1:3000"
AUTH_HEADER="authorization: Bearer test_auth-"

# Step 1: Create multiple wallets quickly to queue MongoDB operations
echo "[Step 1] Creating 10 wallets rapidly to queue MongoDB operations..."

for i in {1..10}; do
  TIMESTAMP=$(date +%s)
  RANDOM_ADDR="0x$(od -An -N20 -tx1 /dev/urandom | tr -d ' \n')"
  WALLET_NAME="mongo-test-$TIMESTAMP-$i"
  
  echo "Creating wallet $i/10: $WALLET_NAME"
  
  # Fire and forget - don't wait for response
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
    }]" &
done

echo "✅ Fired 10 wallet creation requests"
echo ""

# Step 2: While operations are pending, restart MongoDB primary
echo "[Step 2] MANUAL STEP REQUIRED:"
echo ""
echo "NOW, while these operations are pending, you need to trigger MongoDB pool destruction."
echo ""
echo "Option A: Restart MongoDB primary (simulates replica set failover)"
echo "  cd ../_wdk_docker_network"
echo "  docker restart mongo1"
echo ""
echo "Option B: Stop all MongoDB nodes briefly"
echo "  docker stop mongo1 mongo2 mongo3"
echo "  sleep 2"
echo "  docker start mongo1 mongo2 mongo3"
echo ""
echo "Option C: Kill the data-shard-proc process and restart it"
echo "  (This will force destroy the pool)"
echo ""
echo "Press ENTER after you've triggered MongoDB disruption..."
read -r

echo ""
echo "[Step 3] Checking Terminal 3 for 'Pool was force destroyed' error..."
echo ""
echo "The error should appear in the data-shard-proc logs now."
echo ""
echo "🔍 Look for:"
echo "   [HRPC_ERR]=Pool was force destroyed"
echo "   OR"
echo "   MongoError: Pool was force destroyed"
echo ""

# Wait a bit for errors to propagate
sleep 5

echo ""
echo "=== Test Complete ==="
echo ""
echo "Check Terminal 3 for the MongoDB pool destruction error."
echo "If you don't see it, the MongoDB disruption wasn't severe enough."
echo "Try Option B (stopping all MongoDB nodes)."
echo ""
