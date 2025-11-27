#!/bin/bash

# Automated MongoDB Pool Destruction Test
# This version uses Docker to automatically trigger MongoDB disruption

set -e

echo "=== Automated MongoDB Pool Destruction Test ==="
echo ""

API_URL="http://127.0.0.1:3000"
AUTH_HEADER="authorization: Bearer test_auth-"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please use manual test instead."
    exit 1
fi

echo "[Step 1] Creating 20 wallets rapidly to queue MongoDB operations..."
echo ""

# Create many wallets concurrently to build up a queue
for i in {1..20}; do
  TIMESTAMP=$(date +%s)
  RANDOM_ADDR="0x$(od -An -N20 -tx1 /dev/urandom | tr -d ' \n')"
  WALLET_NAME="mongo-stress-$TIMESTAMP-$i-$$"
  
  # Fire all requests concurrently (background jobs)
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
    }]" > /dev/null 2>&1 &
  
  # Add slight delay between requests to spread them out
  sleep 0.05
done

echo "✅ Fired 20 concurrent wallet creation requests"
echo ""

# Give requests time to hit the database
sleep 0.5

echo "[Step 2] Stopping MongoDB primary to trigger pool destruction..."
docker stop mongo1 > /dev/null 2>&1

echo "⏸️  MongoDB primary stopped - pool should be destroyed"
echo ""

# Wait for pool destruction and error propagation
echo "[Step 3] Waiting 3 seconds for pool destruction..."
sleep 3

echo "[Step 4] Restarting MongoDB..."
docker start mongo1 > /dev/null 2>&1

echo "✅ MongoDB restarted"
echo ""

# Wait for connections to restore
sleep 2

echo ""
echo "=== Test Complete ==="
echo ""
echo "🔍 Check Terminal 3 (data-shard-proc) for:"
echo "   MongoError: Pool was force destroyed"
echo "   OR"
echo "   [HRPC_ERR]=Pool was force destroyed"
echo ""
echo "You can also check the log file:"
echo "   grep -i \"pool was force destroyed\" /tmp/data-shard-proc-trace.log"
echo ""
