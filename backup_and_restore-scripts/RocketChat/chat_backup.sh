#!/usr/bin/env bash
#
# Rocket.Chat Backup-Skript (MongoDB-Dump + Uploads)
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CHAT_CONTAINER="chat"
DB_NAME="rocketchat"

echo "Zuerst den MongoDB-Pod auswaehlen:"
select_pod "MongoDB (Chat)"
MONGO_NAMESPACE="$SELECTED_NAMESPACE"
MONGO_POD="$SELECTED_POD"

echo ""
echo "Jetzt den Rocket.Chat-Pod auswaehlen:"
select_pod "Rocket.Chat"
CHAT_NAMESPACE="$SELECTED_NAMESPACE"
CHAT_POD="$SELECTED_POD"

if ! kubectl exec "$MONGO_POD" -n "$MONGO_NAMESPACE" -- command -v mongodump >/dev/null 2>&1; then
    fail "mongodump nicht im MongoDB-Container gefunden!"
fi

log "MongoDB-Dump im Pod erstellen..."
kubectl exec "$MONGO_POD" -n "$MONGO_NAMESPACE" -- \
    sh -c "mongodump --archive=/tmp/rc_mongo_dump.gz --gzip --db=$DB_NAME" \
    || fail "mongodump im Pod fehlgeschlagen."

DB_OUT="$BACKUP_DIR/chat_db_backup_$TIMESTAMP.gz"
kubectl cp "$MONGO_NAMESPACE/$MONGO_POD:/tmp/rc_mongo_dump.gz" "$DB_OUT" \
    || fail "kubectl cp (DB) fehlgeschlagen."
kubectl exec "$MONGO_POD" -n "$MONGO_NAMESPACE" -- rm -f /tmp/rc_mongo_dump.gz
verify_file "$DB_OUT"

log "Uploads im Rocket.Chat-Pod archivieren..."
kubectl exec "$CHAT_POD" -n "$CHAT_NAMESPACE" -c "$CHAT_CONTAINER" -- \
    sh -c "cd /app/uploads && tar czf /tmp/rc_uploads_backup.tar.gz ." \
    || fail "tar im Pod fehlgeschlagen."

DATA_OUT="$BACKUP_DIR/chat_data_backup_$TIMESTAMP.tar.gz"
kubectl cp "$CHAT_NAMESPACE/$CHAT_POD:/tmp/rc_uploads_backup.tar.gz" "$DATA_OUT" -c "$CHAT_CONTAINER" \
    || fail "kubectl cp (Uploads) fehlgeschlagen."
kubectl exec "$CHAT_POD" -n "$CHAT_NAMESPACE" -c "$CHAT_CONTAINER" -- rm -f /tmp/rc_uploads_backup.tar.gz
verify_file "$DATA_OUT"

ftp_upload "$DB_OUT"
ftp_upload "$DATA_OUT"

log "Rocket.Chat-Backup abgeschlossen: $DB_OUT + $DATA_OUT"
