#!/usr/bin/env python3
"""
Log Watcher - Monitors Nginx logs for failover events and error rates
Sends alerts to Slack when thresholds are exceeded
"""

import os
import re
import time
import json
import requests
from collections import deque
from datetime import datetime
from typing import Optional, Dict

# Configuration from environment
SLACK_WEBHOOK_URL = os.getenv('SLACK_WEBHOOK_URL')
ERROR_RATE_THRESHOLD = float(os.getenv('ERROR_RATE_THRESHOLD', '2'))
WINDOW_SIZE = int(os.getenv('WINDOW_SIZE', '200'))
ALERT_COOLDOWN_SEC = int(os.getenv('ALERT_COOLDOWN_SEC', '300'))
LOG_FILE = os.getenv('LOG_FILE', '/logs/access.log')
MAINTENANCE_MODE = os.getenv('MAINTENANCE_MODE', 'false').lower() == 'true'

# State tracking
last_pool: Optional[str] = None
request_window = deque(maxlen=WINDOW_SIZE)
last_alert_times: Dict[str, float] = {}

# Log parsing regex - handles pool=blue, pool=green, or pool=-
LOG_PATTERN = re.compile(
    r'pool=(?P<pool>[\w\-]+)\s+'
    r'release=(?P<release>[\w\-\.]+)\s+'
    r'upstream_status=(?P<upstream_status>\d+)\s+'
    r'upstream=(?P<upstream>[\w\d\.\:]+)\s+'
    r'request_time=(?P<request_time>[\d\.]+)\s+'
    r'upstream_response_time=(?P<upstream_response_time>[\d\.]+)'
)


def send_slack_alert(message: str, alert_type: str, severity: str = "warning"):
    """Send alert to Slack with cooldown check"""
    if MAINTENANCE_MODE:
        print(f"[MAINTENANCE MODE] Suppressed alert: {message}")
        return
    
    if not SLACK_WEBHOOK_URL:
        print(f"[NO WEBHOOK] Would send: {message}")
        return
    
    # Check cooldown
    now = time.time()
    last_alert = last_alert_times.get(alert_type, 0)
    
    if now - last_alert < ALERT_COOLDOWN_SEC:
        print(f"[COOLDOWN] Skipping {alert_type} alert (last sent {int(now - last_alert)}s ago)")
        return
    
    # Color coding
    colors = {
        "critical": "#d32f2f",
        "warning": "#f57c00",
        "info": "#1976d2",
        "success": "#388e3c"
    }
    
    payload = {
        "attachments": [{
            "color": colors.get(severity, "#757575"),
            "title": f"🚨 Alert: {alert_type}",
            "text": message,
            "footer": "DevOps Stage 3 Alert Watcher",
            "ts": int(now)
        }]
    }
    
    try:
        response = requests.post(
            SLACK_WEBHOOK_URL,
            json=payload,
            timeout=10
        )
        response.raise_for_status()
        last_alert_times[alert_type] = now
        print(f"[SLACK] Alert sent: {alert_type}")
    except Exception as e:
        print(f"[ERROR] Failed to send Slack alert: {e}")


def check_error_rate():
    """Calculate error rate and alert if threshold exceeded"""
    if len(request_window) < WINDOW_SIZE * 0.5:
        return  # Not enough data yet
    
    error_count = sum(1 for status in request_window if status >= 500)
    total_count = len(request_window)
    error_rate = (error_count / total_count) * 100
    
    # Debug: log error rate periodically
    if total_count % 50 == 0:
        print(f"[INFO] Error rate: {error_rate:.2f}% ({error_count}/{total_count}), Threshold: {ERROR_RATE_THRESHOLD}%")
    
    if error_rate > ERROR_RATE_THRESHOLD:
        message = (
            f"⚠️ *High Error Rate Detected*\n"
            f"• Error Rate: {error_rate:.2f}% ({error_count}/{total_count} requests)\n"
            f"• Threshold: {ERROR_RATE_THRESHOLD}%\n"
            f"• Window Size: {WINDOW_SIZE} requests\n"
            f"• Action Required: Check upstream application health"
        )
        send_slack_alert(message, "high_error_rate", "critical")
        print(f"[ALERT] High error rate alert sent: {error_rate:.2f}%")


def check_failover(current_pool: str):
    """Detect and alert on pool failover events"""
    global last_pool
    
    if last_pool is None:
        last_pool = current_pool
        print(f"[INIT] Initial pool: {current_pool}")
        return
    
    if current_pool != last_pool:
        message = (
            f"🔄 *Failover Detected*\n"
            f"• Previous Pool: `{last_pool}`\n"
            f"• Current Pool: `{current_pool}`\n"
            f"• Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
            f"• Action: Verify {last_pool} pool health and investigate cause"
        )
        send_slack_alert(message, "failover", "warning")
        
        # Send recovery alert when switching back
        if current_pool == "blue" or current_pool == "green":
            recovery_msg = (
                f"✅ *Pool Recovery*\n"
                f"• Pool `{current_pool}` is now serving traffic\n"
                f"• Previous: `{last_pool}`\n"
                f"• System stabilized"
            )
            send_slack_alert(recovery_msg, "recovery", "success")
        
        last_pool = current_pool


def parse_log_line(line: str) -> Optional[Dict]:
    """Parse Nginx log line and extract relevant fields"""
    match = LOG_PATTERN.search(line)
    if not match:
        return None
    
    return {
        'pool': match.group('pool'),
        'release': match.group('release'),
        'upstream_status': int(match.group('upstream_status')),
        'upstream': match.group('upstream'),
        'request_time': float(match.group('request_time')),
        'upstream_response_time': float(match.group('upstream_response_time'))
    }


def tail_logs():
    """Tail Nginx log file and process entries in real-time"""
    print(f"[START] Watching {LOG_FILE}")
    print(f"[CONFIG] Error threshold: {ERROR_RATE_THRESHOLD}%, Window: {WINDOW_SIZE}, Cooldown: {ALERT_COOLDOWN_SEC}s")
    
    # Wait for log file to exist
    while not os.path.exists(LOG_FILE):
        print(f"[WAIT] Log file not found, waiting...")
        time.sleep(5)
    
    print(f"[READY] Log file found, starting monitoring...")
    
    # Use subprocess tail -F for reliable following, or implement buffered reading
    # Open file in read mode without seeking
    with open(LOG_FILE, 'r', buffering=1) as f:
        # Read existing content first (catch up)
        print(f"[INFO] Reading existing log entries...")
        line_count = 0
        for line in f:
            line_count += 1
            process_line(line)
        
        print(f"[INFO] Processed {line_count} existing lines. Now monitoring live...")
        
        # Now follow new lines
        while True:
            line = f.readline()
            
            if not line:
                time.sleep(0.1)
                continue
            
            process_line(line)


def process_line(line: str):
    """Process a single log line"""
    # Debug: print raw line occasionally
    if len(request_window) % 10 == 0 and len(request_window) < 50:
        print(f"[DEBUG] Sample log line: {line[:200]}")
    
    # Parse log line
    log_data = parse_log_line(line)
    if not log_data:
        # Debug: show why parsing failed
        if 'pool=' in line:
            print(f"[WARN] Line contains 'pool=' but failed to parse: {line[:150]}")
        return
    
    # Debug: show successful parse
    if len(request_window) < 5:
        print(f"[DEBUG] Parsed: pool={log_data['pool']}, status={log_data['upstream_status']}")
    
    # Track request status
    request_window.append(log_data['upstream_status'])
    
    # Check for failover
    check_failover(log_data['pool'])
    
    # Check error rate
    check_error_rate()
    
    # Log processing
    if log_data['upstream_status'] >= 500:
        print(f"[ERROR] 5xx detected: pool={log_data['pool']}, status={log_data['upstream_status']}, upstream={log_data['upstream']}")


if __name__ == '__main__':
    try:
        tail_logs()
    except KeyboardInterrupt:
        print("\n[STOP] Watcher stopped")
    except Exception as e:
        print(f"[FATAL] {e}")
        import traceback
        traceback.print_exc()
        raise