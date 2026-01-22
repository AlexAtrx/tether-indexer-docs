#!/bin/bash

# Test script to reproduce Hyperswarm RPC pool timeout issue with USDT-ETH
# Works with your existing USDT indexer setup

BASE_URL="http://127.0.0.1:3000"
AUTH_TOKEN="test_auth-"

echo "=========================================="
echo "Hyperswarm RPC Pool Timeout Test (USDT)"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Configuration:${NC}"
echo "- poolLinger: 30 seconds (pool destruction starts after 30s of inactivity)"
echo "- syncWalletTransfers: every 10 seconds"
echo "- Token: USDT (your currently running indexer)"
echo "- Expected timeline: Error should occur around 30-40 seconds"
echo ""

echo -e "${GREEN}Step 1: Creating test wallet with USDT-holding address...${NC}"

# Using a popular USDT address that definitely has transactions
# Tether Treasury address - lots of USDT activity
USDT_ADDRESS="0x5754284f345afc66a98fbB0a0Afe71e0F007B949"

RESPONSE=$(curl -s --request POST \
  --url "${BASE_URL}/api/v1/wallets" \
  --header "authorization: Bearer ${AUTH_TOKEN}" \
  --header "content-type: application/json" \
  --data "[
    {
      \"name\": \"test-usdt-pool-timeout\",
      \"type\": \"user\",
      \"addresses\": {
        \"ethereum\": \"${USDT_ADDRESS}\"
      }
    }
  ]")

echo "Response: $RESPONSE"
echo ""

# Extract wallet ID if successful
WALLET_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$WALLET_ID" ]; then
  echo -e "${GREEN}✓ Wallet created successfully!${NC}"
  echo "  Wallet ID: $WALLET_ID"
  echo "  Address: $USDT_ADDRESS"
  echo "  Token: USDT on Ethereum"
else
  echo -e "${YELLOW}⚠ Wallet may already exist or creation failed${NC}"
  echo "  Continuing with existing wallet..."
fi
echo ""

echo -e "${GREEN}Step 2: Verifying wallets...${NC}"
WALLET_COUNT=$(curl -s --request GET \
  --url "${BASE_URL}/api/v1/wallets" \
  --header "authorization: Bearer ${AUTH_TOKEN}" | jq '. | length')
echo "  Total wallets: $WALLET_COUNT"
echo ""

echo -e "${YELLOW}=========================================="
echo "Now monitoring for the pool timeout issue..."
echo "==========================================${NC}"
echo ""
echo "Timeline:"
echo "  0:00 - Wallet created/exists"
echo "  0:10 - First sync job (should succeed)"
echo "  0:20 - Second sync job (should succeed)"
echo "  0:30 - Pool destruction begins (30s poolLinger)"
echo "  0:30-0:40 - Next sync job → ERROR expected!"
echo ""
echo -e "${RED}Watch your rumble-data-shard-wrk PROC terminal for:${NC}"
echo "  Error: [HRPC_ERR]=Pool was force destroyed"
echo "  ERR_WALLET_TRANSFER_RPC_FAIL: ethereum:usdt:${USDT_ADDRESS}"
echo ""
echo -e "${YELLOW}Also watch for these logs (every 10 seconds):${NC}"
echo "  \"started syncing wallet transfers for wallets...\""
echo ""
echo -e "${YELLOW}Monitoring for 60 seconds...${NC}"
echo ""

# Monitor for 60 seconds with countdown
for i in {1..60}; do
  echo -ne "  Elapsed: ${i}s / 60s (ERROR expected at ~30-40s)\r"
  sleep 1
done

echo ""
echo ""
echo -e "${GREEN}=========================================="
echo "Test complete!"
echo "==========================================${NC}"
echo ""
echo "Did you see the error in the rumble-data-shard-wrk proc logs?"
echo ""
echo -e "${YELLOW}Expected error pattern:${NC}"
echo "  [HRPC_ERR]=Pool was force destroyed"
echo "  at NetFacility.handleInputError"
echo "  ERR_WALLET_TRANSFER_RPC_FAIL: ethereum:usdt:<address>"
echo ""
echo "If YES:"
echo "  ✓ Issue reproduced successfully!"
echo "  ✓ Confirms: Hyperswarm RPC pool timeout race condition"
echo "  ✓ Happens with USDT (not just XAUT)"
echo ""
echo "If NO:"
echo "  - Check that rumble-data-shard-wrk proc worker is running"
echo "  - Check that USDT indexer workers are running (proc + api)"
echo "  - Check proc worker restarted after config change"
echo "  - Look for sync job logs every 10s: 'started syncing wallet transfers'"
echo "  - Try running the test again (timing may vary)"
echo ""
echo "To view recent logs:"
echo "  # In your data-shard-proc terminal, scroll up to see last 60s"
echo ""
echo "To test again:"
echo "  ./test_pool_timeout_usdt.sh"
echo ""
