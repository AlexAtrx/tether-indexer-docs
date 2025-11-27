#!/bin/bash

# Monitor script to watch for pool destruction errors in real-time
# Run this in a separate terminal while running the test

echo "=== Monitoring for Pool Destruction Errors ==="
echo "Watching data-shard and ork worker logs..."
echo "Press Ctrl+C to stop"
echo ""

# This assumes you have the workers running and can grep their output
# Adjust the paths/processes as needed for your setup

while true; do
  # Look for the error pattern
  if grep -r "Pool was force destroyed" /tmp/*.log 2>/dev/null; then
    echo "!!! POOL DESTRUCTION ERROR DETECTED !!!"
    echo "Timestamp: $(date)"
  fi
  
  if grep -r "HRPC_ERR" /tmp/*.log 2>/dev/null; then
    echo "!!! HRPC ERROR DETECTED !!!"
    echo "Timestamp: $(date)"
  fi
  
  sleep 1
done
