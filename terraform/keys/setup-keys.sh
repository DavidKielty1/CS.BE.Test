#!/bin/bash

# Create keys directory if it doesn't exist
mkdir -p keys

# Generate SSH key pair if it doesn't exist
if [ ! -f keys/redis ]; then
    echo "Generating new SSH key pair for Redis..."
    ssh-keygen -t rsa -b 2048 -f keys/redis -N "" -C "redis@clearscore"
    
    # Set correct permissions
    chmod 400 keys/redis
    chmod 444 keys/redis.pub
    
    echo "✅ SSH key pair generated:"
    echo "   - Private key: keys/redis"
    echo "   - Public key:  keys/redis.pub"
else
    echo "⚠️  SSH key pair already exists in keys/redis"
fi

# Verify files exist
if [ -f keys/redis ] && [ -f keys/redis.pub ]; then
    echo "✅ Key files present and ready for use"
    echo "To connect to Redis after deployment:"
    echo "ssh -i keys/redis ubuntu@<redis-ip>"
else
    echo "❌ Error: Key files not created properly"
    exit 1
fi 