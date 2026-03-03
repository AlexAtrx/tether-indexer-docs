#!/bin/bash

# Reproduce the exact [HRPC_ERR]=Pool was force destroyed error

BASE_URL="http://127.0.0.1:3000"
AUTH_TOKEN="test_auth-"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Reproduce [HRPC_ERR]=Pool was force destroyed"
echo "=========================================="
echo ""

echo -e "${BLUE}Current Setup Check:${NC}"
echo "Commands you ran:"
echo "  Terminal 1: node worker.js --wtype wrk-erc20-indexer-proc --chain xaut-eth"
echo "  Terminal 2: node worker.js --wtype wrk-erc20-indexer-api --chain xaut-eth --proc-rpc <KEY>"
echo "  Terminal 3: node worker.js --wtype wrk-data-shard-proc"
echo "  Terminal 4: node worker.js --wtype wrk-data-shard-api --proc-rpc <KEY>"
echo ""

echo -e "${BLUE}Configuration:${NC}"
echo "  poolLinger: 30 seconds"
echo "  syncWalletTransfers: every 10 seconds"
echo "  Chain: ethereum:xaut"
echo ""

echo -e "${YELLOW}Step 1: Creating XAUT wallet...${NC}"

# XAUT contract address on Ethereum
XAUT_ADDRESS="0x68749665FF8D2d112Fa859AA293F07A622782F38"

RESPONSE=$(curl -s --request POST \
  --url "${BASE_URL}/api/v1/wallets" \
  --header "authorization: Bearer ${AUTH_TOKEN}" \
  --header "content-type: application/json" \
  --data "[{
    \"name\": \"test-pool-destroyed-$(date +%s)\",
    \"type\": \"user\",
    \"addresses\": {
      \"ethereum\": \"${XAUT_ADDRESS}\"
    }
  }]")

echo "Response: $RESPONSE"
echo ""

WALLET_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$WALLET_ID" ]; then
  echo -e "${GREEN}✓ Wallet created: $WALLET_ID${NC}"
  echo "  Address: $XAUT_ADDRESS (XAUT contract)"
else
  echo -e "${YELLOW}⚠ Using existing wallet${NC}"
fi
echo ""

echo -e "${GREEN}Step 2: Verifying current wallets...${NC}"
WALLETS=$(curl -s --request GET \
  --url "${BASE_URL}/api/v1/wallets" \
  --header "authorization: Bearer ${AUTH_TOKEN}")
echo "$WALLETS" | jq '.'
echo ""

echo -e "${BLUE}=========================================="
echo "Timeline for Reproduction"
echo "==========================================${NC}"
echo ""
echo "The error occurs when:"
echo "  1. Pool is created on first sync (0-10s)"
echo "  2. Pool goes idle for 30 seconds"
echo "  3. Pool destruction starts at 30s"
echo "  4. Sync job at 30s tries to use dying pool"
echo ""
echo -e "${YELLOW}Expected Timeline:${NC}"
echo "  00s - Wallet created"
echo "  00s - First sync job (pool created for XAUT)"
echo "  10s - Second sync (pool active)"
echo "  20s - Third sync (pool active)"
echo "  30s - Pool destruction STARTS"
echo "  30s - Fourth sync fires → ${RED}ERROR!${NC}"
echo ""
echo -e "${RED}Watch Terminal 3 (rumble-data-shard-wrk proc) for:${NC}"
echo "  [HRPC_ERR]=Pool was force destroyed"
echo "  ERR_WALLET_TRANSFER_RPC_FAIL: ethereum:xaut:${XAUT_ADDRESS}:*"
echo ""

echo -e "${YELLOW}Monitoring for 50 seconds...${NC}"
echo ""

START_TIME=$(date +%s)

for i in {1..50}; do
  ELAPSED=$(($(date +%s) - START_TIME))

  if [ $i -eq 30 ]; then
    echo ""
    echo -e "${RED}>>> 30 SECONDS - POOL DESTRUCTION STARTING! <<<${NC}"
    echo -e "${RED}>>> WATCH FOR ERROR NOW! <<<${NC}"
    echo ""
  fi

  echo -ne "  ${i}s / 50s (ERROR expected at ~30-35s)\r"
  sleep 1
done

echo ""
echo ""
echo -e "${GREEN}=========================================="
echo "Test Complete!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}What to Check:${NC}"
echo ""
echo "1. In Terminal 3 (rumble-data-shard-wrk proc):"
echo "   Look for errors around 30-35 second mark"
echo ""
echo "2. Expected error format:"
echo '   {"level":40,"err":{"message":"[HRPC_ERR]=Pool was force destroyed"},"msg":"ERR_WALLET_TRANSFER_RPC_FAIL: ethereum:xaut:..."}'
echo ""
echo "3. If you see the error:"
echo "   ✓ Success! Issue reproduced!"
echo "   ✓ Confirms Hyperswarm RPC pool timeout"
echo ""
echo "4. If you DON'T see the error, check:"
echo "   - Terminal 3 shows sync jobs every 10s?"
echo "   - XAUT indexer (Terminals 1 & 2) are running?"
echo "   - Config has poolLinger: 30000?"
echo "   - Workers restarted after config/code changes?"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo ""
echo "Run the setup check:"
echo "  cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/_docs/hyperswarm_prod_issue"
echo "  ./check_setup.sh"
echo ""
echo "View recent logs from Terminal 3:"
echo "  Scroll up in your data-shard-proc terminal"
echo "  Look for timestamps around $(date -u -r $((START_TIME + 30)) '+%Y-%m-%dT%H:%M:%S')"
echo ""
