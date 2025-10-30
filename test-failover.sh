
#!/bin/bash

echo "🧪 Testing Proper Failover Alert (Blue → Green)"
echo "================================================"
echo ""

echo "Step 1: Ensure both pools are running..."
docker start hng_13_devops_s3-app_blue-1 2>/dev/null
docker start hng_13_devops_s3-app_green-1 2>/dev/null
sleep 3
echo "✓ Both pools running"
echo ""

echo "Step 2: Generate baseline traffic on blue pool..."
for i in {1..20}; do 
  curl -s http://localhost:8080/ > /dev/null
done
echo "✓ Baseline complete (blue pool active)"
echo ""

echo "Step 3: Stop ONLY blue pool to trigger failover to green..."
docker stop hng_13_devops_s3-app_blue-1
sleep 2
echo "✓ Blue pool stopped"
echo ""

echo "Step 4: Generate traffic (should failover to green)..."
for i in {1..30}; do 
  curl -s http://localhost:8080/ > /dev/null
  sleep 0.3
done
echo "✓ Traffic sent (should be served by green)"
echo ""

echo "Step 5: Check Slack alerts..."
echo "=============================="
docker logs hng_13_devops_s3-alert_watcher-1 2>&1 | grep -A 1 "\[SLACK\]" | tail -10
echo ""

echo "Step 6: Verify logs show blue → green transition..."
echo "=============================="
echo "Last blue request:"
docker exec hng_13_devops_s3-nginx-1 grep "pool=blue" /var/log/nginx/access.log | tail -1
echo ""
echo "First green request after failover:"
docker exec hng_13_devops_s3-nginx-1 grep "pool=green" /var/log/nginx/access.log | tail -1
echo ""

echo "Step 7: Restart blue pool..."
docker start hng_13_devops_s3-app_blue-1
sleep 3
echo "✓ Blue pool restarted"
echo ""

echo "✅ Test complete!"
echo ""
echo "Expected Slack message:"
echo "  🔄 Failover Detected"
echo "  • Previous Pool: blue"
echo "  • Current Pool: green"
echo "  • Action: Verify blue pool health and investigate cause"