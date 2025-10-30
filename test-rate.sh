#!/bin/bash

echo "🧪 Testing Error Rate Alert"
echo "=============================="
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

# First, make sure we have a healthy baseline
echo "Step 1: Ensuring blue pool is running..."
docker start hng_13_devops_s3-app_blue-1 2>/dev/null
sleep 3

echo "Step 2: Generating baseline successful requests (first 100)..."
for i in {1..100}; do 
  curl -s http://localhost:8080/ > /dev/null 2>&1
done
echo "✓ Baseline complete"
echo ""

echo "Step 3: Pausing blue container to force errors..."
docker exec hng_13_devops_s3-app_blue-1 kill -SIGSTOP 1
echo "✓ Blue container paused"
echo ""

echo "Step 4: Generating error traffic (150 requests to trigger errors)..."
for i in {1..150}; do 
  curl -s --max-time 5 http://localhost:8080/ > /dev/null 2>&1
  if [ $((i % 20)) -eq 0 ]; then
    echo "  - Sent $i requests..."
  fi
done
echo "✓ Error traffic complete"
echo ""

echo "Step 5: Resuming blue container..."
docker exec hng_13_devops_s3-app_blue-1 kill -SIGCONT 1
echo "✓ Blue container resumed"
echo ""

echo "Step 6: Checking watcher logs..."
echo "=============================="
docker logs hng_13_devops_s3-alert_watcher-1 | tail -20
echo ""

echo "Step 7: Checking Nginx error log..."
echo "=============================="
docker exec hng_13_devops_s3-nginx-1 tail -5 /var/log/nginx/error.log 2>/dev/null || echo "No errors in nginx log"
echo ""

echo "✅ Test complete!"
echo ""
echo "Expected: You should see a high error rate alert in Slack"
echo "If not, check watcher logs above for [ERROR] or error rate calculations"