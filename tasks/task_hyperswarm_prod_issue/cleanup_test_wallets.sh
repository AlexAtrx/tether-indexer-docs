#!/bin/bash

# Cleanup script - removes test wallets created during pool destruction tests

echo "=== Test Wallet Cleanup ==="
echo "This script will list and optionally delete test wallets"
echo ""

# Configuration
API_URL="http://127.0.0.1:3000"
AUTH_HEADER="authorization: Bearer test_auth-"

# Step 1: Connect to establish session
echo "[1] Connecting to API..."
CONNECT_RESPONSE=$(curl -s --request POST \
  --url "$API_URL/api/v1/connect" \
  --header "$AUTH_HEADER" \
  --header "content-type: application/json" \
  --data '{}')

if [ $? -ne 0 ]; then
  echo "❌ Failed to connect to API"
  exit 1
fi

echo "✅ Connected"
echo ""

# Step 2: Get all wallets
echo "[2] Fetching all wallets..."
WALLETS=$(curl -s --request GET \
  --url "$API_URL/api/v1/wallets" \
  --header "$AUTH_HEADER")

if [ $? -ne 0 ]; then
  echo "❌ Failed to fetch wallets"
  exit 1
fi

# Display wallets nicely
echo "Current wallets:"
echo "$WALLETS" | jq -r '.[] | "  - ID: \(.id // ._id)  Name: \(.name)  Status: \(if .enabled then "enabled" else "disabled" end)"' 2>/dev/null || echo "$WALLETS"
echo ""

# Count test wallets (those starting with "pool-test-")
TEST_WALLET_COUNT=$(echo "$WALLETS" | jq -r '[.[] | select(.name | startswith("pool-test-"))] | length' 2>/dev/null || echo "0")

echo "Found $TEST_WALLET_COUNT test wallet(s) matching pattern 'pool-test-*'"
echo ""

if [ "$TEST_WALLET_COUNT" -eq "0" ]; then
  echo "✅ No test wallets to clean up"
  exit 0
fi

# Ask for confirmation before deleting
read -p "Do you want to delete these test wallets? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled"
  exit 0
fi

# Delete test wallets
echo ""
echo "[3] Deleting test wallets..."

echo "$WALLETS" | jq -r '.[] | select(.name | startswith("pool-test-")) | .id // ._id' 2>/dev/null | while read -r WALLET_ID; do
  if [ -n "$WALLET_ID" ]; then
    echo "Deleting wallet: $WALLET_ID"
    
    DELETE_RESPONSE=$(curl -s --request DELETE \
      --url "$API_URL/api/v1/wallets/$WALLET_ID" \
      --header "$AUTH_HEADER")
    
    if [ $? -eq 0 ]; then
      echo "  ✅ Deleted"
    else
      echo "  ❌ Failed to delete"
    fi
  fi
done

echo ""
echo "=== Cleanup Complete ==="
