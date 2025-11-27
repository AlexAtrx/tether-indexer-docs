#!/bin/bash

# Quick MongoDB cleanup for test wallets
# Since the API only allows ONE user wallet per userId, we need to clean up between test runs

echo "=== MongoDB Test Wallet Cleanup ==="
echo ""

DB_NAME="rumble_data_shard_wrk_data_shard_proc_shard_1"
COLLECTION="wdk_data_shard_wallets"
USER_ID="user-123"  # Default test user ID from test_auth- token

echo "Deleting test wallets for user: $USER_ID"
echo "Database: $DB_NAME"
echo "Collection: $COLLECTION"
echo ""

# Delete wallets
RESULT=$(mongosh "mongodb://localhost:27017/$DB_NAME" --quiet --eval "db.$COLLECTION.deleteMany({userId: '$USER_ID'})" | tail -1)

echo "$RESULT"
echo ""

# Extract deleted count
DELETED_COUNT=$(echo "$RESULT" | grep -o 'deletedCount: [0-9]*' | grep -o '[0-9]*')

if [ -n "$DELETED_COUNT" ] && [ "$DELETED_COUNT" -gt "0" ]; then
  echo "✅ Deleted $DELETED_COUNT test wallet(s)"
else
  echo "ℹ️  No test wallets found to delete"
fi

echo ""
echo "=== Cleanup Complete ==="
