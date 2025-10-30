# DevOps Stage 3 - Alert Runbook

## Overview

This runbook describes alert types, their meanings, and the required operator actions for the Blue/Green deployment monitoring system.

---

## Alert Types

### 🔄 Failover Detected

**Severity:** Warning  
**Trigger:** Traffic switches from one pool to another (Blue ↔ Green)

#### What It Means

The active pool has failed health checks or become unavailable, causing Nginx to automatically route traffic to the backup pool.

#### Example Alert

```
🔄 Failover Detected
• Previous Pool: blue
• Current Pool: green
• Time: 2025-10-30 14:32:15
• Action: Verify blue pool health and investigate cause
```

#### Operator Actions

1. **Immediate Response (0-5 minutes)**

   - Verify the backup pool (green) is handling traffic correctly
   - Check Slack for error rate alerts that may indicate wider issues
   - Monitor application metrics and response times

2. **Investigation (5-15 minutes)**

   - Check logs of the failed pool:
     ```bash
     docker logs app_blue
     # OR
     docker logs app_green
     ```
   - Review Nginx error logs:
     ```bash
     docker exec nginx tail -f /var/log/nginx/error.log
     ```
   - Check container health:
     ```bash
     docker ps
     docker inspect app_blue
     docker inspect app_green
     ```

3. **Resolution**

   - If the primary container crashed:
     ```bash
     # Restart the failed pool
     docker restart app_blue
     # OR
     docker restart app_green
     ```
   - If you want to manually switch pools:

     ```bash
     # Switch to green pool
     echo "ACTIVE_POOL=green" > .env
     docker compose up -d nginx

     # Switch back to blue pool
     echo "ACTIVE_POOL=blue" > .env
     docker compose up -d nginx
     ```

   - If it's a code issue, deploy a hotfix
   - If it's infrastructure, scale resources or investigate host issues

4. **Post-Incident**
   - Document root cause
   - Update monitoring thresholds if needed
   - Consider adding preventive measures

---

### ⚠️ High Error Rate Detected

**Severity:** Critical  
**Trigger:** Upstream 5xx error rate exceeds threshold (default: 2%) over rolling window

#### What It Means

The application is returning server errors at an elevated rate, indicating application-level problems even if containers remain healthy.

#### Example Alert

```
⚠️ High Error Rate Detected
• Error Rate: 5.23% (11/200 requests)
• Threshold: 2%
• Window Size: 200 requests
• Action Required: Check upstream application health
```

#### Operator Actions

1. **Immediate Response (0-2 minutes)**

   - Assess blast radius - is this affecting all users or specific endpoints?
   - Check if error rate is rising or stable
   - Review recent deployments or configuration changes

2. **Investigation (2-10 minutes)**

   - Examine application logs for both pools:
     ```bash
     docker logs app_blue --tail 100
     docker logs app_green --tail 100
     ```
   - Check for common errors:
     - Database connection failures
     - External API timeouts
     - Memory/CPU exhaustion
     - Configuration errors

3. **Mitigation Options**

   **Option A: Toggle to healthy pool**

   ```bash
   # If blue pool is failing, switch to green
   echo "ACTIVE_POOL=green" > .env
   docker compose up -d nginx
   ```

   **Option B: Restart affected containers**

   ```bash
   docker restart app_blue app_green
   ```

   **Option C: Scale back deployment**

   ```bash
   # Rollback to previous version by updating .env
   # Edit BLUE_IMAGE or GREEN_IMAGE to previous version
   docker compose down
   docker compose up -d
   ```

4. **Post-Incident**
   - Determine if threshold needs adjustment
   - Add application-level alerts
   - Implement circuit breakers if API timeouts are common

---

### ✅ Pool Recovery

**Severity:** Info/Success  
**Trigger:** Traffic returns to primary pool after failover

#### What It Means

The previously failed pool has recovered and is now serving traffic again.

#### Example Alert

```
✅ Pool Recovery
• Pool blue is now serving traffic
• Previous: green
• System stabilized
```

#### Operator Actions

1. **Verification (0-5 minutes)**

   - Monitor error rates for next 15 minutes
   - Confirm no immediate re-failover occurs
   - Check application metrics are nominal

2. **Documentation**
   - Log the incident duration
   - Note any manual interventions performed
   - Update incident timeline

---

## Maintenance Mode

To suppress alerts during planned maintenance:

```bash
# Enable maintenance mode
echo "MAINTENANCE_MODE=true" >> .env
docker compose up -d alert_watcher

# Disable maintenance mode after maintenance
echo "MAINTENANCE_MODE=false" >> .env
docker compose up -d alert_watcher
```

**⚠️ Remember:** Always disable maintenance mode after planned work!

---

## Testing Alerts

### Test Failover Alert

```bash
# Stop blue pool to trigger failover
docker stop app_blue

# Generate some traffic
for i in {1..50}; do curl http://localhost:8080/; done

# Restart blue pool
docker start app_blue
```

### Test Error Rate Alert

```bash
# Pause the active container to cause timeouts
# If blue is active:
docker exec app_blue kill -SIGSTOP 1

# Generate traffic to trigger errors
for i in {1..250}; do curl http://localhost:8080/; done

# Resume the container
docker exec app_blue kill -SIGCONT 1
```

---

## Configuration Tuning

### Error Rate Threshold

- **Default:** 2%
- **Low-traffic apps:** Consider 5% to avoid false positives
- **High-criticality apps:** Consider 0.5% for early detection

### Window Size

- **Default:** 200 requests
- **High-traffic:** Increase to 500-1000 for smoother detection
- **Low-traffic:** Decrease to 50-100 for faster response

### Alert Cooldown

- **Default:** 300 seconds (5 minutes)
- **Adjust based on:** How long it takes your team to respond
- **Too short:** Alert spam
- **Too long:** Miss recurring issues

---

## Common Issues

### No Alerts Received

**Check 1: Webhook URL**

```bash
docker logs alert_watcher | grep WEBHOOK
```

**Check 2: Watcher is running**

```bash
docker ps | grep alert_watcher
```

**Check 3: Test webhook manually**

```bash
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test alert"}' \
  $SLACK_WEBHOOK_URL
```

### Too Many Alerts

Enable maintenance mode temporarily:

```bash
echo "MAINTENANCE_MODE=true" >> .env
docker compose up -d alert_watcher
```

### Logs Not Parsing

Check log format in Nginx:

```bash
docker exec nginx tail /var/log/nginx/access.log
```

Verify format matches pattern in watcher.py.

---
