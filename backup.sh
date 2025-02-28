#!/bin/bash

# Simple backup script for Redis
# Usage: ./backup.sh [backup_dir]

BACKUP_DIR=${1:-./backups}
TIMESTAMP=$(date +%Y%m%d%H%M%S)
CONTAINER_NAME="azure-redis-stack"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Creating Redis backup..."

# Trigger Redis to create a new RDB file
docker exec "$CONTAINER_NAME" redis-cli SAVE

# Copy the latest RDB and AOF files from the container
echo "Copying data files from container..."
docker cp "$CONTAINER_NAME":/data/dump.rdb "$BACKUP_DIR/dump_$TIMESTAMP.rdb"
docker cp "$CONTAINER_NAME":/data/appendonly.aof "$BACKUP_DIR/appendonly_$TIMESTAMP.aof"

echo "Backup completed: $BACKUP_DIR/dump_$TIMESTAMP.rdb and $BACKUP_DIR/appendonly_$TIMESTAMP.aof"
