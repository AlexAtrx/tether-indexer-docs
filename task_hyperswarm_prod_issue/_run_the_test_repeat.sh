for i in {1..5}; do
  echo "=== Test run $i ==="
  ./cleanup_mongo_test_wallets.sh
  ./test_pool_destruction_v4.sh
  echo ""
  sleep 3
done