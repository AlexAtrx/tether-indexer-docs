#!/bin/bash

# Force pool timeout by stopping the indexer temporarily

echo "=========================================="
echo "Force Hyperswarm Pool Timeout Test"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}This test requires manual steps:${NC}"
echo ""
echo "1. Make sure rumble-data-shard-wrk proc is running"
echo "2. Make sure USDT indexer (proc + api) are running"
echo "3. Wait for this script to tell you when to stop/start indexer"
echo ""

read -p "Press ENTER when ready to start..."

echo ""
echo -e "${GREEN}Step 1: Current state - syncs should be running...${NC}"
echo "Watch Terminal 3 (data-shard-proc) for sync jobs every 10s"
echo ""
sleep 5

echo -e "${YELLOW}Step 2: Now STOP your USDT indexer workers!${NC}"
echo ""
echo "In Terminal 1 (usdt-eth-proc): Press Ctrl+C"
echo "In Terminal 2 (usdt-eth-api): Press Ctrl+C"
echo ""
echo "This will make the RPC pool idle..."
echo ""

read -p "Press ENTER after you've STOPPED both indexer terminals..."

echo ""
echo -e "${YELLOW}Pool is now idle. Waiting 35 seconds for pool to start destroying...${NC}"
echo "(poolLinger = 30s, so pool destruction starts at 30s)"
echo ""

for i in {1..35}; do
  echo -ne "  ${i}s / 35s\r"
  sleep 1
done

echo ""
echo ""
echo -e "${RED}Step 3: NOW restart your USDT indexer (quickly!)${NC}"
echo ""
echo "Terminal 1:"
echo "  cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-indexer-wrk-evm"
echo "  node worker.js --wtype wrk-evm-indexer-proc --env development --rack eth-proc --chain usdt-eth"
echo ""
echo "Terminal 2 (get proc RPC key from Terminal 1 first):"
echo "  cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-indexer-wrk-evm"
echo "  node worker.js --wtype wrk-evm-indexer-api --env development --rack eth-api --chain usdt-eth --proc-rpc <KEY>"
echo ""

read -p "Press ENTER after you've RESTARTED both indexer terminals..."

echo ""
echo -e "${YELLOW}Waiting 15 seconds for sync job to fire and hit the dying pool...${NC}"
echo ""

for i in {1..15}; do
  echo -ne "  ${i}s / 15s\r"
  sleep 1
done

echo ""
echo ""
echo -e "${GREEN}=========================================="
echo "Test Complete!"
echo "==========================================${NC}"
echo ""
echo -e "${RED}Check Terminal 3 (rumble-data-shard-wrk proc) NOW!${NC}"
echo ""
echo "Expected error (if timing was right):"
echo "  [HRPC_ERR]=Pool was force destroyed"
echo "  ERR_WALLET_TRANSFER_RPC_FAIL: ethereum:usdt:*"
echo ""
echo "OR you might see:"
echo "  ERR_TOPIC_LOOKUP_EMPTY (if indexer not reconnected yet)"
echo ""
echo "If you didn't see the error:"
echo "  - The timing wasn't right (race condition is tricky!)"
echo "  - Try running this test 2-3 more times"
echo "  - Or the pool reconnected too quickly"
echo ""
