#!/bin/bash
# ===========================================
# GREENHOUSE IOT - DATABASE BACKUP SCRIPT
# ===========================================

BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/greenhouse_backup_$DATE.sql"

echo "🗄️ Creating database backup..."

# Create backup directory if not exists
mkdir -p $BACKUP_DIR

# Create backup using docker
docker exec greenhouse-iot-db-1 pg_dump -U greenhouse greenhouse > $BACKUP_FILE

if [ $? -eq 0 ]; then
    # Compress backup
    gzip $BACKUP_FILE
    echo "✅ Backup created: ${BACKUP_FILE}.gz"
    
    # Remove backups older than 30 days
    find $BACKUP_DIR -name "*.gz" -mtime +30 -delete
    echo "🧹 Old backups cleaned up"
else
    echo "❌ Backup failed!"
    exit 1
fi

# Show backup size
ls -lh ${BACKUP_FILE}.gz
