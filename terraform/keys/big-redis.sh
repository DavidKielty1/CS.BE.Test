
# Commenting out Redis configuration as it's already set up and running
    # /*
# locals {
#   redis_init = <<EOF
#     #!/bin/bash
#     sudo yum update -y
#     sudo yum install -y amazon-linux-extras
#     sudo amazon-linux-extras enable redis6
#     sudo yum install redis6 -y
    
#     # Configure Redis
#     sudo tee /etc/redis6/redis6.conf > /dev/null <<EOL
#     bind 0.0.0.0
#     protected-mode no
#     port 6379
#     timeout 0
#     tcp-keepalive 300
#     daemonize yes
#     supervised auto
#     loglevel notice
#     logfile "/var/log/redis/redis.log"
#     dir /var/lib/redis6
#     # Persistence configuration
#     appendonly yes
#     appendfilename "appendonly.aof"
#     appendfsync everysec
#     # Snapshotting
#     save 900 1
#     save 300 10
#     save 60 10000
#     EOL
    
#     # Create data directory with correct permissions
#     sudo mkdir -p /var/lib/redis6
#     sudo chown redis:redis /var/lib/redis6
    
#     sudo systemctl enable redis6
#     sudo systemctl start redis6
    
#     # Verify installation
#     redis6-cli ping
    
#     # Configure Redis backups
#     sudo mkdir -p /etc/cron.daily
#     sudo tee /etc/cron.daily/redis-backup <<EOL
#     #!/bin/bash
#     BACKUP_DIR="/var/lib/redis6/backups"
#     mkdir -p \$BACKUP_DIR
#     DATE=\$(date +%Y%m%d)
#     redis6-cli SAVE
#     cp /var/lib/redis6/dump.rdb \$BACKUP_DIR/dump-\$DATE.rdb
#     find \$BACKUP_DIR -type f -mtime +7 -delete
#     EOL
    
#     sudo chmod +x /etc/cron.daily/redis-backup
#     EOF
# }