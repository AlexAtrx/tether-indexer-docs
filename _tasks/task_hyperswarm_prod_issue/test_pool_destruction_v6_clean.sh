# #!/bin/bash

# # Wrapper: cleans user-123 test wallets before running v6

# set -euo pipefail

# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# echo "=== Cleaning existing test wallets (user-123) ==="
# "${SCRIPT_DIR}/cleanup_mongo_test_wallets.sh"
# echo ""

# echo "=== Running Pool Destruction Test v6 ==="
# "${SCRIPT_DIR}/test_pool_destruction_v6.sh"


#!/bin/bash

# Wrapper: runs cleanup + test 10 times with random delays

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ITERATIONS=10

for i in $(seq 1 $ITERATIONS); do
    echo "========================================"
    echo "=== ITERATION $i of $ITERATIONS ==="
    echo "========================================"
    echo ""
    
    echo "=== Cleaning existing test wallets (user-123) ==="
    "${SCRIPT_DIR}/cleanup_mongo_test_wallets.sh"
    echo ""
    
    echo "=== Running Pool Destruction Test v6 ==="
    "${SCRIPT_DIR}/test_pool_destruction_v6.sh"
    echo ""
    
    # Don't sleep after the last iteration
    if [ $i -lt $ITERATIONS ]; then
        # Generate random delay between 1 and 10 seconds
        DELAY=$((RANDOM % 10 + 1))
        echo "--- Waiting ${DELAY} seconds before next iteration ---"
        sleep $DELAY
        echo ""
    fi
done

echo "========================================"
echo "=== ALL $ITERATIONS ITERATIONS COMPLETE ==="
echo "========================================"