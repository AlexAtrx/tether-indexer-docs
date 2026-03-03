#!/bin/bash

# Quick check script to verify the setup for reproducing the issue

echo "=========================================="
echo "Setup Verification for Pool Timeout Test"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ISSUES=0

# Check 1: XAUT indexer running
echo -n "1. XAUT indexer running... "
XAUT_COUNT=$(ps aux | grep -E "xaut.*(proc|api)" | grep -v grep | wc -l | tr -d ' ')
if [ "$XAUT_COUNT" -ge 2 ]; then
  echo -e "${GREEN}✓ ($XAUT_COUNT processes)${NC}"
else
  echo -e "${RED}✗ (Expected 2, found $XAUT_COUNT)${NC}"
  echo "   Run: node worker.js --wtype wrk-evm-indexer-proc --chain eth --ccy xaut"
  echo "   Run: node worker.js --wtype wrk-evm-indexer-api --chain eth --ccy xaut --proc-rpc <KEY>"
  ISSUES=$((ISSUES + 1))
fi

# Check 2: Data shard running
echo -n "2. Data shard workers running... "
SHARD_COUNT=$(ps aux | grep "wrk-data-shard" | grep -v grep | wc -l | tr -d ' ')
if [ "$SHARD_COUNT" -ge 2 ]; then
  echo -e "${GREEN}✓ ($SHARD_COUNT processes)${NC}"
else
  echo -e "${RED}✗ (Expected 2, found $SHARD_COUNT)${NC}"
  echo "   Run data-shard-proc and data-shard-api"
  ISSUES=$((ISSUES + 1))
fi

# Check 3: Org service running
echo -n "3. Org service running... "
ORK_COUNT=$(ps aux | grep "wrk-ork" | grep -v grep | wc -l | tr -d ' ')
if [ "$ORK_COUNT" -ge 1 ]; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${YELLOW}⚠ (Optional but recommended)${NC}"
fi

# Check 4: HTTP app running
echo -n "4. HTTP app node running (port 3000)... "
if lsof -i :3000 >/dev/null 2>&1; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗ (Not running)${NC}"
  echo "   Run: node worker.js --wtype wrk-node-http --port 3000"
  ISSUES=$((ISSUES + 1))
fi

# Check 5: Config file
echo -n "5. Config updated (poolLinger=30s)... "
POOL_LINGER=$(grep -A 2 "netOpts" /Users/alexa/Documents/repos/tether/_INDEXER_clean/rumble-data-shard-wrk/config/common.json | grep "poolLinger" | grep -o "[0-9]*")
if [ "$POOL_LINGER" = "30000" ]; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗ (poolLinger=$POOL_LINGER, expected 30000)${NC}"
  ISSUES=$((ISSUES + 1))
fi

# Check 6: Sync job schedule
echo -n "6. Sync job schedule (every 10s)... "
if grep -q '"syncWalletTransfers": "\*/10 \* \* \* \* \*"' /Users/alexa/Documents/repos/tether/_INDEXER_clean/rumble-data-shard-wrk/config/common.json; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗ (Not configured)${NC}"
  ISSUES=$((ISSUES + 1))
fi

# Check 7: XAUT in blockchains config
echo -n "7. XAUT configured in blockchains... "
if grep -q '"xaut"' /Users/alexa/Documents/repos/tether/_INDEXER_clean/rumble-data-shard-wrk/config/common.json; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗ (XAUT not in config)${NC}"
  ISSUES=$((ISSUES + 1))
fi

# Check 8: API accessible
echo -n "8. API accessible at http://127.0.0.1:3000... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/api/v1/wallets -H "authorization: Bearer test_auth-")
if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗ (HTTP $HTTP_CODE)${NC}"
  ISSUES=$((ISSUES + 1))
fi

echo ""
echo "=========================================="
if [ $ISSUES -eq 0 ]; then
  echo -e "${GREEN}✓ All checks passed! Ready to test.${NC}"
  echo ""
  echo "Run the test:"
  echo "  cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/_docs/hyperswarm_prod_issue"
  echo "  ./test_pool_timeout.sh"
else
  echo -e "${RED}✗ Found $ISSUES issue(s). Fix them first.${NC}"
  echo ""
  echo "Quick fix guide:"
  echo "  1. Stop all services (Ctrl+C)"
  echo "  2. Follow: RESTART_SERVICES.md"
fi
echo "=========================================="
echo ""
