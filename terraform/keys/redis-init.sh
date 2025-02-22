# Configure Redis
ssh -i my-key-pair.pem ec2-user@52.56.244.42


sudo tee /etc/redis6/redis6.conf > /dev/null <<'EOF'
bind 0.0.0.0
protected-mode no
port 6379
timeout 300
tcp-keepalive 300
daemonize yes
supervised auto
loglevel notice
logfile "/var/log/redis/redis.log"
dir /var/lib/redis6
appendonly yes
appendfilename "appendonly.aof"
appendfsync no
save 900 1
save 300 10
save 60 10000
maxmemory 512mb
maxmemory-policy allkeys-lru
databases 1
maxclients 10000
EOF

# Verify Redis is running
MAX_ATTEMPTS=30
ATTEMPT=0
until redis6-cli ping; do
  echo "Waiting for Redis to start..."
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "Redis failed to start after $MAX_ATTEMPTS attempts"
    exit 1
  fi
  sleep 1
done

echo "Redis is running and accepting connections" 


# Restart Redis to apply changes
sudo systemctl restart redis6

# Verify it's listening on all interfaces
ss -tunlp | grep 6379 