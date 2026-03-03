#!/bin/bash
# Script to reproduce the ACTUAL "[HRPC_ERR]=Pool was force destroyed" error
# This creates continuous load on the indexer and stops MongoDB during active queries

set -e

echo "========================================================================"
echo "Reproduce: [HRPC_ERR]=Pool was force destroyed"
echo "========================================================================"
echo ""
echo "This script will:"
echo "  1. Verify all required services are running"
echo "  2. Create continuous RPC queries to the indexer"
echo "  3. Stop MongoDB DURING active indexer queries"
echo "  4. Show you the CORRECT error in data-shard logs"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_URL="http://127.0.0.1:3000"
AUTH_HEADER="authorization: Bearer test_auth-"

echo "========================================================================"
echo "STEP 1: Verify Prerequisites"
echo "========================================================================"
echo ""

# Check if MongoDB is running
if ! docker ps | grep -q mongo1; then
    echo -e "${RED}Error: MongoDB containers not running${NC}"
    echo "Please start MongoDB first:"
    echo "  cd _wdk_docker_network && npm run start:db"
    exit 1
fi
echo -e "${GREEN}✓ MongoDB is running${NC}"

# Check if app-node is accessible
if ! curl -s "$API_URL/api/v1/connect" -X POST -H "$AUTH_HEADER" -H "content-type: application/json" -d '{}' > /dev/null 2>&1; then
    echo -e "${RED}Error: App node not accessible or authentication failed${NC}"
    echo "Please verify:"
    echo "  1. App node is running on port 3000"
    echo "  2. All required services are up"
    exit 1
fi
echo -e "${GREEN}✓ App node is accessible and authenticated${NC}"

# Check for indexer process (matches wrk-erc20-indexer or wrk-evm-indexer)
if ! pgrep -f "erc20-indexer" > /dev/null 2>&1 && ! pgrep -f "evm-indexer" > /dev/null 2>&1; then
    echo -e "${RED}Error: No indexer workers running${NC}"
    echo "Please start indexer workers first"
    echo "Looking for processes with: wrk-erc20-indexer-* or wrk-evm-indexer-*"
    exit 1
fi
echo -e "${GREEN}✓ Indexer workers are running${NC}"

# Check for data-shard process
if ! pgrep -f "data-shard" > /dev/null 2>&1; then
    echo -e "${RED}Error: No data-shard workers running${NC}"
    echo "Please start data-shard workers first"
    echo "Looking for processes with: wrk-data-shard-*"
    exit 1
fi
echo -e "${GREEN}✓ Data-shard workers are running${NC}"

echo ""
echo "========================================================================"
echo "STEP 2: Get or Create a Test Wallet"
echo "========================================================================"
echo ""

# Get existing wallets
WALLETS_JSON=$(curl -s --request GET \
  --url "$API_URL/api/v1/wallets" \
  --header "$AUTH_HEADER")

# Extract wallet ID from the response format: { "wallets": [...] }
WALLET_ID=$(echo "$WALLETS_JSON" | jq -r '.wallets[0].id // empty')

if [ -z "$WALLET_ID" ]; then
    echo "No wallets found, creating one..."
    
    RANDOM_ADDR="0x$(openssl rand -hex 20)"
    WALLET_NAME="pool-test-$(date +%s)"
    
    WALLET_RESPONSE=$(curl -s --request POST \
      --url "$API_URL/api/v1/wallets" \
      --header "$AUTH_HEADER" \
      --header "content-type: application/json" \
      --data "[{
        \"name\": \"$WALLET_NAME\",
        \"type\": \"user\",
        \"addresses\": {
          \"ethereum\": \"$RANDOM_ADDR\"
        }
      }]")
    
    # Wallet creation returns an array directly: [{...}]
    WALLET_ID=$(echo "$WALLET_RESPONSE" | jq -r '.[0].id // empty')
    
    if [ -z "$WALLET_ID" ]; then
        echo -e "${RED}Error: Failed to create wallet${NC}"
        echo "Response: $WALLET_RESPONSE"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Created wallet: $WALLET_ID${NC}"
else
    echo -e "${GREEN}✓ Using existing wallet: $WALLET_ID${NC}"
fi

echo ""
echo "========================================================================"
echo "STEP 3: Create Continuous Load on Indexer"
echo "========================================================================"
echo ""

echo -e "${YELLOW}Starting continuous queries to the indexer...${NC}"
echo "These will trigger balance/transfer queries from data-shard to indexer"
echo "The indexer will query MongoDB for blockchain data"
echo ""

# Cleanup function
cleanup_load() {
    if [ ! -z "$LOAD_PID" ]; then
        kill $LOAD_PID 2>/dev/null || true
        wait $LOAD_PID 2>/dev/null || true
    fi
}

trap cleanup_load EXIT

# Background process that creates continuous load
{
    QUERY_COUNT=0
    while true; do
        # Use the balances endpoint which queries the indexer
        # Add cache=false to bypass cache
        curl -s --request GET \
          --url "$API_URL/api/v1/wallets/balances?cache=false" \
          --header "$AUTH_HEADER" > /dev/null 2>&1
        
        QUERY_COUNT=$((QUERY_COUNT + 1))
        
        # Log every 10 queries
        if [ $((QUERY_COUNT % 10)) -eq 0 ]; then
            echo "[$(date +%H:%M:%S)] Sent $QUERY_COUNT queries to indexer..."
        fi
        
        # Small delay between queries
        sleep 0.2
    done
} &
LOAD_PID=$!

echo -e "${GREEN}✓ Background query loop started (PID: $LOAD_PID)${NC}"
echo ""

# Let queries run for a bit
echo "Letting queries run for 5 seconds to establish pattern..."
sleep 5

echo ""
echo "Current query count: ~25 queries sent"
echo ""

echo "========================================================================"
echo "STEP 4: Stop MongoDB During Active Queries"
echo "========================================================================"
echo ""

echo -e "${RED}WARNING: About to stop MongoDB primary!${NC}"
echo "This will trigger the error while indexer is actively querying MongoDB."
echo ""
read -p "Press ENTER to stop MongoDB primary (mongo1)..."

echo ""
echo "Stopping mongo1..."
docker stop mongo1 > /dev/null 2>&1

echo -e "${RED}✓ MongoDB primary STOPPED${NC}"
echo ""
echo "The indexer's MongoDB queries are now failing!"
echo "The error should propagate to data-shard via RPC..."
echo ""

# Keep queries running for a bit longer to ensure we hit the error
echo "Continuing queries for 5 more seconds to capture the error..."
sleep 5

# Stop the load
cleanup_load

echo ""
echo "========================================================================"
echo "STEP 5: Check Logs for the CORRECT Error"
echo "========================================================================"
echo ""

echo -e "${BLUE}Searching for '[HRPC_ERR]=Pool was force destroyed' in data-shard logs...${NC}"
echo ""

FOUND_CORRECT_ERROR=false
FOUND_WRONG_ERROR=false

# Check data-shard logs
if [ -f "/tmp/data-shard-proc-trace.log" ]; then
    echo "=== Data-Shard Logs (Last 30 errors) ==="
    
    # Look for the CORRECT error
    if grep -q "HRPC_ERR.*Pool was force destroyed" /tmp/data-shard-proc-trace.log; then
        FOUND_CORRECT_ERROR=true
        echo -e "${GREEN}✓✓✓ FOUND THE CORRECT ERROR! ✓✓✓${NC}"
        echo ""
        grep -B 2 -A 5 "HRPC_ERR.*Pool was force destroyed" /tmp/data-shard-proc-trace.log | tail -20
    fi
    
    # Also show if we got the WRONG error (data-shard's own MongoDB)
    if grep -E "not master and slaveOk=false" /tmp/data-shard-proc-trace.log | tail -5 | grep -q "not master"; then
        FOUND_WRONG_ERROR=true
        echo ""
        echo -e "${YELLOW}Also found data-shard's own MongoDB errors (expected):${NC}"
        grep "not master and slaveOk=false" /tmp/data-shard-proc-trace.log | tail -3
    fi
fi

echo ""

# Check indexer logs to see if IT had MongoDB errors
if [ -f "/tmp/indexer-api-trace.log" ]; then
    echo "=== Indexer Logs (MongoDB errors) ==="
    if grep -iE "pool.*destroyed|MongoError|topology.*destroyed|ECONNREFUSED" /tmp/indexer-api-trace.log | tail -10 | grep -q .; then
        echo -e "${GREEN}✓ Indexer had MongoDB connection errors:${NC}"
        grep -iE "pool.*destroyed|MongoError|topology.*destroyed|ECONNREFUSED" /tmp/indexer-api-trace.log | tail -10
    else
        echo -e "${YELLOW}No MongoDB errors in indexer logs${NC}"
    fi
fi

echo ""
echo "========================================================================"
echo "STEP 6: Restart MongoDB"
echo "========================================================================"
echo ""

echo "Restarting mongo1..."
docker start mongo1 > /dev/null 2>&1

sleep 3

echo -e "${GREEN}✓ MongoDB restarted${NC}"

echo ""
echo "========================================================================"
echo "RESULT"
echo "========================================================================"
echo ""

if [ "$FOUND_CORRECT_ERROR" = true ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓✓✓ SUCCESS! ERROR REPRODUCED! ✓✓✓${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "You successfully reproduced:"
    echo -e "${RED}  [HRPC_ERR]=Pool was force destroyed${NC}"
    echo ""
    echo "This is the SAME error from production logs!"
    echo ""
    if [ "$FOUND_WRONG_ERROR" = true ]; then
        echo -e "${YELLOW}Note: You also saw 'not master and slaveOk=false' errors.${NC}"
        echo "Those are data-shard's own MongoDB errors (expected noise)."
        echo "The IMPORTANT error is the [HRPC_ERR]= one from the indexer."
    fi
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}ERROR NOT REPRODUCED${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    if [ "$FOUND_WRONG_ERROR" = true ]; then
        echo "You got data-shard's MongoDB error: 'not master and slaveOk=false'"
        echo "But NOT the indexer's error: '[HRPC_ERR]=Pool was force destroyed'"
        echo ""
        echo "Possible reasons:"
        echo "  1. Indexer wasn't actively querying MongoDB when it stopped"
        echo "  2. Indexer uses a different MongoDB instance"
        echo "  3. Timing issue - queries completed before MongoDB stopped"
        echo ""
        echo "Try:"
        echo "  - Run this script again (timing is important)"
        echo "  - Check indexer's MongoDB config: wdk-indexer-wrk-evm/config/facs/db-mongo.config.json"
        echo "  - Increase query frequency (edit this script, change sleep 0.2 to sleep 0.05)"
    else
        echo "No errors found at all. Please check:"
        echo "  1. Are all services running?"
        echo "  2. Is the wallet triggering sync jobs?"
        echo "  3. Check log files exist: ls -la /tmp/*-trace.log"
    fi
fi

echo ""
echo -e "${BLUE}Full logs available at:${NC}"
echo "  - Data-shard: /tmp/data-shard-proc-trace.log"
echo "  - Indexer API: /tmp/indexer-api-trace.log"
echo "  - Indexer PROC: /tmp/indexer-proc-trace.log"
echo ""
echo -e "${GREEN}Search for errors manually:${NC}"
echo "  grep -i 'HRPC_ERR.*Pool' /tmp/data-shard-proc-trace.log"
echo "  grep -iE 'MongoError|pool.*destroyed' /tmp/indexer-*.log"
echo ""
