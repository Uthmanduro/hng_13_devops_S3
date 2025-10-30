#!/bin/sh
set -e

# Determine backup server based on ACTIVE_POOL
if [ "$ACTIVE_POOL" = "green" ]; then
    PRIMARY="green"
    BACKUP="blue"
else
    PRIMARY="blue"
    BACKUP="green"
fi

# Remove default symlinks and create real log files
rm -f /var/log/nginx/access.log /var/log/nginx/error.log
touch /var/log/nginx/access.log /var/log/nginx/error.log
chmod 644 /var/log/nginx/access.log /var/log/nginx/error.log

# Generate nginx config with correct primary/backup assignment and structured logging
cat > /etc/nginx/conf.d/default.conf << EOF
# Custom log format for observability
log_format detailed_log '\$remote_addr - \$remote_user [\$time_local] '
                        '"\$request" \$status \$body_bytes_sent '
                        '"\$http_referer" "\$http_user_agent" '
                        'pool=\$upstream_http_x_app_pool '
                        'release=\$upstream_http_x_release_id '
                        'upstream_status=\$upstream_status '
                        'upstream=\$upstream_addr '
                        'request_time=\$request_time '
                        'upstream_response_time=\$upstream_response_time';

upstream backend {
    # Primary server (active pool: ${PRIMARY})
    server app_${PRIMARY}:3000 max_fails=1 fail_timeout=5s;
    
    # Backup server (switches on primary failure)
    server app_${BACKUP}:3000 backup max_fails=1 fail_timeout=5s;
}

server {
    listen 80;
    server_name localhost;
    
    # Use custom log format for observability
    access_log /var/log/nginx/access.log detailed_log;
    error_log /var/log/nginx/error.log warn;
    
    # Aggressive timeouts for rapid failover detection
    proxy_connect_timeout 2s;
    proxy_send_timeout 3s;
    proxy_read_timeout 3s;
    
    # Retry configuration
    # Retry on: connection errors, timeouts, and all 5xx server errors
    proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
    proxy_next_upstream_tries 2;
    proxy_next_upstream_timeout 10s;
    
    location / {
        proxy_pass http://backend;
        
        # Preserve original request headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Critical: Ensure application headers pass through to clients
        proxy_pass_header X-App-Pool;
        proxy_pass_header X-Release-Id;
        
        # Disable buffering for faster failover response
        proxy_buffering off;
        
        # Use HTTP/1.1 for keepalive connections
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
EOF

echo "✓ Nginx config generated with PRIMARY=${PRIMARY}, BACKUP=${BACKUP}"
echo "✓ Structured logging enabled for observability"
echo "✓ Real log files created (not symlinks)"