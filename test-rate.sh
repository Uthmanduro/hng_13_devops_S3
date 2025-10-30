#!/bin/bash

echo "🧪 Testing Error Rate Alert (Improved Method)"
echo "=============================================="
echo ""

# Check current configuration
echo "Current Configuration:"
echo "- ERROR_RATE_THRESHOLD: ${ERROR_RATE_THRESHOLD:-2}%"
echo "- WINDOW_SIZE: ${WINDOW_SIZE:-200} requests"
echo ""

# Calculate how many errors needed
THRESHOLD=${ERROR_RATE_THRESHOLD:-2}
WINDOW=${WINDOW_SIZE:-200}
ERRORS_NEEDED=$(echo "scale=0; ($THRESHOLD * $WINDOW / 100) + 1" | bc)

echo "📊 To trigger alert:"
echo "- Need > $THRESHOLD% errors in $WINDOW requests"
echo "- That's at least $ERRORS_NEEDED errors out of $WINDOW requests"
echo ""

echo "Step 1: Ensuring both pools are running..."
docker start hng_13_devops_s3-app_blue-1 2>/dev/null
docker start hng_13_devops_s3-app_green-1 2>/dev/null
sleep 3
echo "✓ Both pools running"
echo ""

echo "Step 2: Generating baseline successful requests (100 requests)..."
for i in {1..100}; do 
  curl -s http://localhost:8080/ > /dev/null 2>&1
done
echo "✓ Baseline complete"
echo ""

echo "Step 3: STOPPING BOTH pools to force 502 errors..."
docker stop hng_13_devops_s3-app_blue-1
docker stop hng_13_devops_s3-app_green-1
sleep 2
echo "✓ Both pools stopped"
echo ""

echo "Step 4: Generating 502 error traffic (120 requests)..."
for i in {1..120}; do 
  curl -s --max-time 2 http://localhost:8080/ > /dev/null 2>&1
  if [ $((i % 20)) -eq 0 ]; then
    echo "  - Sent $i error requests..."
  fi
done
echo "✓ Error traffic complete"
echo ""

echo "Step 5: Restarting both pools..."
docker start hng_13_devops_s3-app_blue-1
docker start hng_13_devops_s3-app_green-1
sleep 5
echo "✓ Pools restarted"
echo ""

echo "Step 6: Checking watcher logs for error detection..."
echo "=============================="
docker logs hng_13_devops_s3-alert_watcher-1 | grep -E "\[ERROR\]|\[INFO\] Error rate|\[ALERT\]" | tail -30
echo ""

echo "Step 7: Checking recent Nginx logs for 502 errors..."
echo "=============================="
docker exec hng_13_devops_s3-nginx-1 grep "upstream_status=502" /var/log/nginx/access.log | tail -5
echo ""

echo "Step 8: Checking if alert was sent to Slack..."
echo "=============================="
docker logs hng_13_devops_s3-alert_watcher-1 | grep "SLACK"
echo ""

echo "✅ Test complete!"
echo ""
echo "Expected: You should see:"
echo "  1. Multiple [ERROR] 5xx detected lines in watcher logs"
echo "  2. [INFO] Error rate showing > 2%"
echo "  3. [ALERT] High error rate alert sent"
echo "  4. [SLACK] Alert sent: high_error_rate"
echo "  5. Slack message in your channel"
echo ""
echo "If no alert was sent, check:"
echo "  - Error rate may not have exceeded threshold (check [INFO] Error rate lines)"
echo "  - Alert may be in cooldown period (300 seconds by default)"

