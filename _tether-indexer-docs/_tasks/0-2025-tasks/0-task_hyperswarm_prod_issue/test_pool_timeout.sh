#!/bin/bash

# Test script to reproduce Hyperswarm RPC pool timeout issue
# This script creates a test wallet and monitors for the "Pool was force destroyed" error

BASE_URL="http://127.0.0.1:3000"
AUTH_TOKEN="test_auth-"

echo "=========================================="
echo "Hyperswarm RPC Pool Timeout Test"
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
echo "- Expected timeline: Error should occur around 30-40 seconds"
echo ""

echo -e "${GREEN}Step 1: Creating test wallet with XAUT address...${NC}"
RESPONSE=$(curl -s --request POST \
  --url "${BASE_URL}/api/v1/wallets" \
  --header "authorization: Bearer ${AUTH_TOKEN}" \
  --header "content-type: application/json" \
  --data '[
    {
      "name": "test-xaut-pool-timeout",
      "type": "user",
      "addresses": {
        "ethereum": "0x68749665FF8D2d112Fa859AA293F07A622782F38"
      }
    }
  ]')

echo "Response: $RESPONSE"
echo ""

# Extract wallet ID if successful
WALLET_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$WALLET_ID" ]; then
  echo -e "${GREEN}✓ Wallet created successfully!${NC}"
  echo "  Wallet ID: $WALLET_ID"
  echo "  Address: 0x68749665FF8D2d112Fa859AA293F07A622782F38 (XAUT contract)"
else
  echo -e "${YELLOW}⚠ Wallet may already exist or creation failed${NC}"
fi
echo ""

echo -e "${GREEN}Step 2: Verifying wallet...${NC}"
curl -s --request GET \
  --url "${BASE_URL}/api/v1/wallets" \
  --header "authorization: Bearer ${AUTH_TOKEN}" | jq '.'
echo ""

echo -e "${YELLOW}=========================================="
echo "Now monitoring for the pool timeout issue..."
echo "==========================================${NC}"
echo ""
echo "Timeline:"
echo "  0:00 - Wallet created"
echo "  0:10 - First sync job (should succeed)"
echo "  0:20 - Second sync job (should succeed)"
echo "  0:30 - Pool destruction begins (30s poolLinger)"
echo "  0:30-0:40 - Next sync job → ERROR expected!"
echo ""
echo -e "${RED}Watch your data-shard-proc worker terminal for:${NC}"
echo "  Error: [HRPC_ERR]=Pool was force destroyed"
echo "  at NetFacility.handleInputError"
echo ""
echo -e "${YELLOW}Monitoring for 60 seconds...${NC}"
echo ""

# Monitor for 60 seconds
for i in {1..60}; do
  echo -ne "  Elapsed: ${i}s / 60s\r"
  sleep 1
done

echo ""
echo ""
echo -e "${GREEN}=========================================="
echo "Test complete!"
echo "==========================================${NC}"
echo ""
echo "Did you see the error in the data-shard-proc logs?"
echo ""
echo "If YES:"
echo "  ✓ Issue reproduced successfully!"
echo "  ✓ Confirms: Hyperswarm RPC pool timeout race condition"
echo ""
echo "If NO:"
echo "  - Check that data-shard-proc worker is running"
echo "  - Check that XAUT indexer workers are running"
echo "  - Try running the test again (timing may vary)"
echo "  - Check logs manually in the worker terminals"
echo ""
echo "To reset and test again:"
echo "  1. Restart data-shard-proc worker"
echo "  2. Run this script again"
echo ""
