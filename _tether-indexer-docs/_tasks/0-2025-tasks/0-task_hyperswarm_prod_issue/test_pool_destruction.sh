#!/bin/bash

# Test script to reproduce "Pool was force destroyed" error
# This simulates the production scenario where RPC pools timeout and get hit with requests

echo "=== Pool Destruction Test ==="
echo "This test will:"
echo "1. Create a wallet (establishes RPC connection)"
echo "2. Wait 35 seconds for pool to be destroyed (poolLinger: 30s)"
echo "3. Make multiple parallel requests to trigger the error"
echo ""

# Configuration
API_URL="http://127.0.0.1:3000"
AUTH_HEADER="authorization: Bearer test_auth-"

echo "[Step 1] Creating initial wallet to establish RPC connection pool..."
RESPONSE=$(curl -s --request POST \
  --url "$API_URL/api/v1/wallets" \
  --header "$AUTH_HEADER" \
  --header "content-type: application/json" \
  --data '[
    {
      "name": "pool-test-wallet-1",
      "type": "user",
      "addresses": {
        "ethereum": "0x1111111111111111111111111111111111111111"
      }
    }
  ]')

echo "Response: $RESPONSE"
echo ""

echo "[Step 2] Waiting 35 seconds for RPC pool to be destroyed (poolLinger=30s)..."
for i in {35..1}; do
  echo -ne "\rTime remaining: ${i}s  "
  sleep 1
done
echo -e "\n"

echo "[Step 3] Making multiple parallel requests to trigger pool destruction error..."
echo "This should hit the dying pool and cause 'Pool was force destroyed' errors"
echo ""

# Make 5 parallel requests
for i in {1..5}; do
  (
    ADDR=$(printf "0x%040d" $i)
    echo "Request $i: Creating wallet with address $ADDR"
    curl -s --request POST \
      --url "$API_URL/api/v1/wallets" \
      --header "$AUTH_HEADER" \
      --header "content-type: application/json" \
      --data "[
        {
          \"name\": \"pool-test-wallet-$i\",
          \"type\": \"user\",
          \"addresses\": {
            \"ethereum\": \"$ADDR\"
          }
        }
      ]" &
  ) &
done

# Wait for all requests to complete
wait

echo ""
echo "=== Test Complete ==="
echo "Check Terminal 3 (data-shard-proc) logs for '[HRPC_ERR]=Pool was force destroyed' errors"
echo "Check Terminal 5 (ork-api) logs for retry behavior"
