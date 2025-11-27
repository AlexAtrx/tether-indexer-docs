#!/bin/bash
# Simple script to reproduce "Pool was force destroyed" error
# Assumes all 6 instances are already running per QUICK_START.md

set -e

echo "======================================================================"
echo "Reproduce 'Pool was force destroyed' Error"
echo "======================================================================"
echo ""
echo "Prerequisites: All 6 instances should be running"
echo "  - xaut-indexer-proc"
echo "  - xaut-indexer-api" 
echo "  - data-shard-proc"
echo "  - data-shard-api (3 instances)"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}This script will:${NC}"
echo "  1. Stop MongoDB primary (mongo1)"
echo "  2. Wait for errors to appear in logs"
echo "  3. Restart MongoDB primary"
echo ""
echo -e "${YELLOW}The error will appear in data-shard logs because they query the indexer.${NC}"
echo ""

read -p "Press ENTER to continue..."

echo ""
echo "======================================================================"
echo "STEP 1: Stop MongoDB Primary (triggers failover)"
echo "======================================================================"
echo ""

echo "Stopping mongo1..."
docker stop mongo1 2>&1

echo ""
echo -e "${RED}✓ MongoDB primary STOPPED${NC}"
echo ""
echo "The indexer's MongoDB connection pool is now being destroyed..."
echo "Data-shard workers will get errors when querying the indexer."
echo ""

echo "Waiting 10 seconds for errors to propagate..."
sleep 10

echo ""
echo "======================================================================"
echo "STEP 2: Check Data-Shard Logs for the Error"
echo "======================================================================"
echo ""

echo -e "${BLUE}Searching for 'Pool was force destroyed' in data-shard logs...${NC}"
echo ""

# Find data-shard log files
FOUND_ERROR=false

# Check status directory for logs
if [ -d "rumble-data-shard-wrk/status" ]; then
    echo "Checking rumble-data-shard-wrk/status logs..."
    if find rumble-data-shard-wrk/status -name "*.log" -exec grep -l "Pool was force destroyed" {} \; 2>/dev/null | head -1; then
        FOUND_ERROR=true
        echo ""
        echo -e "${GREEN}✓ ERROR FOUND! Here are the error lines:${NC}"
        echo ""
        find rumble-data-shard-wrk/status -name "*.log" -exec grep -A 5 "Pool was force destroyed" {} \; 2>/dev/null | head -20
    fi
fi

echo ""

# Also check /tmp for logs
if [ -d "/tmp" ]; then
    echo "Checking /tmp for data-shard logs..."
    if find /tmp -name "*data-shard*.log" -exec grep -l "Pool was force destroyed" {} \; 2>/dev/null | head -1; then
        FOUND_ERROR=true
        echo ""
        echo -e "${GREEN}✓ ERROR FOUND in /tmp logs!${NC}"
        echo ""
        find /tmp -name "*data-shard*.log" -exec grep -A 5 "Pool was force destroyed" {} \; 2>/dev/null | head -20
    fi
fi

echo ""

if [ "$FOUND_ERROR" = true ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ ERROR SUCCESSFULLY REPRODUCED!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
else
    echo -e "${YELLOW}Error not found in logs yet.${NC}"
    echo "The error appears when data-shard queries the indexer during MongoDB downtime."
    echo ""
    echo "You can manually check logs:"
    echo "  - rumble-data-shard-wrk/status/*.log"
    echo "  - /tmp/*data-shard*.log"
    echo ""
    echo "Search for: grep -r 'Pool was force destroyed' rumble-data-shard-wrk/status/"
fi

echo ""
echo "======================================================================"
echo "STEP 3: Restart MongoDB Primary"
echo "======================================================================"
echo ""

echo "Restarting mongo1..."
docker start mongo1 2>&1

sleep 3

echo ""
echo -e "${GREEN}✓ MongoDB primary restarted${NC}"
echo ""

echo "======================================================================"
echo "REPRODUCTION COMPLETE"
echo "======================================================================"
echo ""
echo -e "${BLUE}What happened:${NC}"
echo "  1. Stopped MongoDB primary → triggered replica set failover"
echo "  2. Indexer's MongoDB pool was destroyed"
echo "  3. Data-shard RPC calls to indexer failed with the error"
echo "  4. MongoDB primary restarted → system recovered"
echo ""
echo -e "${YELLOW}The exact error in production logs:${NC}"
echo -e "${RED}  Error: [HRPC_ERR]=Pool was force destroyed${NC}"
echo -e "${RED}      at NetFacility.handleInputError (hp-svc-facs-net/index.js:58:11)${NC}"
echo -e "${RED}      at blockchain.svc.js:415:21${NC}"
echo ""
echo -e "${BLUE}To see full stack trace:${NC}"
echo "  grep -A 20 'Pool was force destroyed' rumble-data-shard-wrk/status/*.log"
echo ""
