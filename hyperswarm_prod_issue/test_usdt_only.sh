#!/bin/bash

# Clean test - USDT only (no XAUT)
# This avoids ERR_TOPIC_LOOKUP_EMPTY for XAUT

BASE_URL="http://127.0.0.1:3000"
AUTH_TOKEN="test_auth-"

echo "=========================================="
echo "Hyperswarm Pool Timeout Test - USDT ONLY"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Step 1: Checking for XAUT wallets...${NC}"
XAUT_WALLET_ID=$(curl -s http://127.0.0.1:3000/api/v1/wallets \
  -H "authorization: Bearer ${AUTH_TOKEN}" | \
  jq -r '.wallets[] | select(.addresses.ethereum == "0x68749665ff8d2d112fa859aa293f07a622782f38") | .id')

if [ -n "$XAUT_WALLET_ID" ]; then
  echo -e "${YELLOW}Found XAUT test wallet: $XAUT_WALLET_ID${NC}"
  echo "Disabling it to avoid ERR_TOPIC_LOOKUP_EMPTY..."
  curl -s --request PATCH \
    --url "http://127.0.0.1:3000/api/v1/wallets/$XAUT_WALLET_ID" \
    --header "authorization: Bearer ${AUTH_TOKEN}" \
    --header "content-type: application/json" \
    --data '{"enabled": false}' > /dev/null
  echo -e "${GREEN}✓ XAUT wallet disabled${NC}"
else
  echo -e "${GREEN}✓ No XAUT wallets found${NC}"
fi
echo ""

echo -e "${GREEN}Step 2: Creating USDT-only wallet...${NC}"

# Tether Treasury - lots of USDT activity
USDT_ADDRESS="0x5754284f345afc66a98fbB0a0Afe71e0F007B949"

RESPONSE=$(curl -s --request POST \
  --url "${BASE_URL}/api/v1/wallets" \
  --header "authorization: Bearer ${AUTH_TOKEN}" \
  --header "content-type: application/json" \
  --data "[
    {
      \"name\": \"test-usdt-only-$(date +%s)\",
      \"type\": \"user\",
      \"addresses\": {
        \"ethereum\": \"${USDT_ADDRESS}\"
      }
    }
  ]")

WALLET_ID=$(echo "$RESPONSE" | jq -r '.[0].id // empty')

if [ -n "$WALLET_ID" ]; then
  echo -e "${GREEN}✓ Wallet created: $WALLET_ID${NC}"
else
  echo -e "${YELLOW}⚠ Using existing wallet${NC}"
fi
echo ""

echo -e "${YELLOW}Step 3: Waiting for pool timeout (30 seconds)...${NC}"
echo ""
echo "Configuration:"
echo "  - poolLinger: 30 seconds"
echo "  - syncWalletTransfers: every 10 seconds"
echo "  - Chain: ethereum:usdt"
echo ""

echo "Timeline:"
echo "  0:00 - Starting now"
echo "  0:10 - First sync (✓ pool fresh)"
echo "  0:20 - Second sync (✓ pool alive)"
echo "  0:30 - Third sync (❌ pool destroying)"
echo ""

echo -e "${RED}Watch Terminal 3 (rumble-data-shard-wrk proc) for:${NC}"
echo "  [HRPC_ERR]=Pool was force destroyed"
echo "  ERR_WALLET_TRANSFER_RPC_FAIL: ethereum:usdt:*"
echo ""

echo -e "${YELLOW}Monitoring for 50 seconds...${NC}"
for i in {1..50}; do
  if [ $i -eq 30 ]; then
    echo -e "\n${RED}>>> Pool timeout window! Watch for error now! <<<${NC}\n"
  fi
  echo -ne "  ${i}s / 50s\r"
  sleep 1
done

echo ""
echo ""
echo -e "${GREEN}=========================================="
echo "Test Complete"
echo "==========================================${NC}"
echo ""
echo "Check Terminal 3 (rumble-data-shard-wrk proc) logs."
echo ""
echo "Expected errors around 30s mark:"
echo "  [HRPC_ERR]=Pool was force destroyed"
echo "  ERR_WALLET_TRANSFER_RPC_FAIL: ethereum:usdt:<address>"
echo ""
echo "If you see ERR_TOPIC_LOOKUP_EMPTY:"
echo "  - That's for XAUT (different issue - no indexer running)"
echo "  - Ignore it, focus on USDT errors"
echo ""
