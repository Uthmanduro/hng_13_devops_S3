# DevOps Stage 3: Observability & Alerts for Blue/Green Deployment

This project implements real-time monitoring and Slack alerting for a Blue/Green deployment architecture with automatic failover detection and error-rate monitoring.

## 🎯 Features

- **Structured Nginx Logging** - Captures pool, release ID, upstream status, latency, and upstream address
- **Real-time Log Monitoring** - Python watcher tails Nginx logs continuously
- **Failover Detection** - Alerts when traffic switches between Blue/Green pools
- **Error Rate Monitoring** - Tracks 5xx errors over a sliding window and alerts on threshold breach
- **Slack Integration** - Sends formatted alerts with context and recommended actions
- **Alert Deduplication** - Cooldown periods prevent alert spam
- **Maintenance Mode** - Suppress alerts during planned changes

## 📋 Prerequisites

- Docker & Docker Compose
- Slack workspace with webhook access
- Application images from Stage 2 (blue/green variants)

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone <your-repo-url>
cd devops-stage3
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and configure all required values:

```bash
# Pool configuration
ACTIVE_POOL=blue

# Your application images
BLUE_IMAGE=your-app-image:blue
GREEN_IMAGE=your-app-image:green

# Release tracking
RELEASE_ID_BLUE=blue-v1.0
RELEASE_ID_GREEN=green-v1.0

# Application port
PORT=3000

# Slack webhook (required for alerts)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Alert thresholds
ERROR_RATE_THRESHOLD=2
WINDOW_SIZE=200
ALERT_COOLDOWN_SEC=300
MAINTENANCE_MODE=false
```

**Get a Slack Webhook:**

1. Go to https://api.slack.com/messaging/webhooks
2. Create a new webhook for your workspace
3. Copy the webhook URL to `.env`

### 3. Start Services

```bash
docker compose up -d
```

### 4. Verify Setup

```bash
# Check all services are running
docker compose ps

# View watcher logs
docker logs -f alert_watcher

# View Nginx logs
docker exec nginx tail -f /var/log/nginx/access.log
```

## 🧪 Testing & Verification

### Test 1: Generate Normal Traffic

```bash
# Generate traffic to populate the window
for i in {1..50}; do
  curl -s http://localhost:8080/ > /dev/null
  echo "Request $i completed"
done
```

Check Nginx logs show structured format:

```bash
docker exec nginx tail -5 /var/log/nginx/access.log
```

**Expected output format:**

```
... pool=blue release=blue-v1.0 upstream_status=200 upstream=172.18.0.2:8080 request_time=0.123 upstream_response_time=0.120
```

### Test 2: Failover Detection

**Trigger a failover:**

```bash
# Stop the blue pool to force failover to green
docker stop app_blue

# Generate traffic (will failover to green)
for i in {1..30}; do
  curl -s http://localhost:8080/
  sleep 0.5
done
```

**Expected Slack Alert:**

```
🔄 Failover Detected
• Previous Pool: blue
• Current Pool: green
• Time: 2025-10-30 14:32:15
• Action: Verify blue pool health and investigate cause
```

**Restore:**

```bash
docker start app_blue
```

### Test 3: High Error Rate Alert

**Inject errors:**

```bash
# Pause the blue container to cause timeouts (if blue is active)
docker exec app_blue kill -SIGSTOP 1

# Generate traffic to trigger errors
for i in {1..250}; do
  curl -s http://localhost:8080/ > /dev/null
done

# Resume the container
docker exec app_blue kill -SIGCONT 1
```

**Expected Slack Alert:**

```
⚠️ High Error Rate Detected
• Error Rate: 5.23% (11/200 requests)
• Threshold: 2%
• Window Size: 200 requests
• Action Required: Check upstream application health
```

### Test 4: Verify Log Format

```bash
# Generate a request
curl http://localhost:8080/

# Check log structure
docker exec nginx tail -1 /var/log/nginx/access.log
```

**Verify fields present:**

- ✅ `pool=blue` or `pool=green`
- ✅ `release=<version>`
- ✅ `upstream_status=<code>`
- ✅ `upstream=<ip:port>`
- ✅ `request_time=<seconds>`
- ✅ `upstream_response_time=<seconds>`

## 📸 Required Screenshots

For submission, capture these screenshots:

### Screenshot 1: Slack Failover Alert

- Trigger: Stop app-blue container
- Shows: Failover message with pool change (blue → green)
- Must include: Timestamp, pool names, alert details

### Screenshot 2: Slack High Error Rate Alert

- Trigger: Inject errors using chaos testing
- Shows: Error rate percentage exceeding threshold
- Must include: Error count, rate percentage, threshold value

### Screenshot 3: Container Logs (Nginx)

- Command: `docker exec nginx tail -10 /var/log/nginx/access.log`
- Shows: Structured log entries with all required fields
- Must include: pool, release, upstream_status, latency

## 📊 Viewing Logs

### Nginx Access Logs

```bash
# Real-time tail
docker exec nginx tail -f /var/log/nginx/access.log

# Last 100 lines
docker exec nginx tail -100 /var/log/nginx/access.log

# Search for specific pool
docker exec nginx grep "pool=green" /var/log/nginx/access.log
```

### Watcher Logs

```bash
# Real-time monitoring
docker logs -f alert_watcher

# Search for alerts
docker logs alert_watcher | grep SLACK

# Check for errors
docker logs alert_watcher | grep ERROR
```

### Application Logs

```bash
# Blue pool logs
docker logs app_blue

# Green pool logs
docker logs app_green

# Follow logs in real-time
docker logs -f app_blue
```

## 🔧 Configuration

### Environment Variables

| Variable               | Default | Description                          |
| ---------------------- | ------- | ------------------------------------ |
| `SLACK_WEBHOOK_URL`    | -       | Slack incoming webhook (required)    |
| `ACTIVE_POOL`          | blue    | Initial active pool (blue/green)     |
| `ERROR_RATE_THRESHOLD` | 2       | Error rate % to trigger alert        |
| `WINDOW_SIZE`          | 200     | Number of requests in rolling window |
| `ALERT_COOLDOWN_SEC`   | 300     | Seconds between similar alerts       |
| `MAINTENANCE_MODE`     | false   | Suppress alerts during maintenance   |

### Tuning Guidelines

**For High-Traffic Applications:**

- Increase `WINDOW_SIZE` to 500-1000 for smoother detection
- Keep `ERROR_RATE_THRESHOLD` at 1-2% for early warning

**For Low-Traffic Applications:**

- Decrease `WINDOW_SIZE` to 50-100 for faster response
- Increase `ERROR_RATE_THRESHOLD` to 5% to avoid false positives

**Alert Frequency:**

- Default cooldown (300s) is suitable for most cases
- Reduce to 180s if team responds quickly
- Increase to 600s if alerts cause fatigue

## 🛠️ Maintenance Mode

Enable during planned changes to suppress alerts:

```bash
# Enable
echo "MAINTENANCE_MODE=true" >> .env
docker compose up -d alert_watcher

# Disable
echo "MAINTENANCE_MODE=false" >> .env
docker compose up -d alert_watcher
```

**⚠️ Important:** Always disable maintenance mode after completing work!

## 🐛 Troubleshooting

### No Alerts Received

**Check webhook URL:**

```bash
docker logs alert_watcher | grep -i webhook
```

**Test webhook manually:**

```bash
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test from command line"}' \
  $SLACK_WEBHOOK_URL
```

**Verify watcher is running:**

```bash
docker compose ps alert_watcher
docker logs alert_watcher
```

### Logs Not Parsing

**Verify log format:**

```bash
docker exec nginx cat /etc/nginx/conf.d/default.conf | grep log_format
```

**Check log file location:**

```bash
docker exec nginx ls -la /var/log/nginx/
```

### Alerts Too Frequent

**Option 1: Increase cooldown**

```bash
echo "ALERT_COOLDOWN_SEC=600" >> .env
docker compose up -d alert_watcher
```

**Option 2: Enable maintenance mode temporarily**

```bash
echo "MAINTENANCE_MODE=true" >> .env
docker compose up -d alert_watcher
```

## 📖 Documentation

- **[runbook.md](./runbook.md)** - Complete alert response procedures
- **[.env.example](./.env.example)** - Configuration template

## 🏗️ Architecture

```
┌─────────────────────────┐
│   Nginx (Port 8080)     │ ──> Structured logs ──┐
│  generate-nginx-config  │      (shared volume)   │
│    (Reverse Proxy)      │                        │
└─────────────────────────┘                        ▼
      │                                    ┌──────────────────┐
      │ Failover on failure               │  alert_watcher   │
      ▼                                    │    (Python)      │
┌──────────────┐  ┌──────────────┐        └──────────────────┘
│  app_blue    │  │  app_green   │                │
│  (Port 8081) │  │  (Port 8082) │                │
│  Primary or  │  │  Primary or  │                ▼
│   Backup     │  │   Backup     │        ┌──────────────────┐
└──────────────┘  └──────────────┘        │  Slack Webhook   │
                                           │    (Alerts)      │
                                           └──────────────────┘

Pools switch based on ACTIVE_POOL variable:
• ACTIVE_POOL=blue  → blue is primary, green is backup
• ACTIVE_POOL=green → green is primary, blue is backup
```

## 📝 Project Structure

```
.
├── docker-compose.yml          # Service orchestration
├── generate-nginx-config.sh    # Dynamic Nginx config generator with logging
├── .env.example                # Environment template
├── .env                        # Your configuration (not in git)
├── runbook.md                  # Alert response procedures
├── README.md                   # This file
└── watcher/
    ├── Dockerfile              # Watcher container image
    ├── watcher.py              # Log monitoring script
    └── requirements.txt        # Python dependencies
```

## 🎓 Learning Outcomes

After completing this stage, you will understand:

- ✅ Structured logging for operational visibility
- ✅ Real-time log processing and monitoring
- ✅ Alert design and deduplication strategies
- ✅ Integration with external notification systems
- ✅ Incident response runbook creation
- ✅ Blue/Green deployment observability

## 📦 Submission Checklist

- [ ] GitHub repository is public and accessible
- [ ] All files included (docker-compose.yml, nginx.conf.template, watcher.py, etc.)
- [ ] `.env.example` provided (no secrets committed)
- [ ] `runbook.md` documents all alert types and responses
- [ ] README.md includes setup and testing instructions
- [ ] Screenshot 1: Slack failover alert
- [ ] Screenshot 2: Slack high error rate alert
- [ ] Screenshot 3: Nginx structured log output
- [ ] All Stage 2 tests still pass
- [ ] Failover generates Slack alert
- [ ] Error rate simulation generates alert

## 🔗 References

- Stage 2 repository: [https://github.com/Uthmanduro/hng_13_devops_S3]
- Nginx log format documentation
- Slack webhook guide: https://api.slack.com/messaging/webhooks
