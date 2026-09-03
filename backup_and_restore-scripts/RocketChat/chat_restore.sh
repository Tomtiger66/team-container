#!/usr/bin/env bash
#
# Rocket.Chat Restore-Skript
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

select_backup_file "chat_db_backup_*.gz" "Datenbank"
DB_FILE="$SELECTED_FILE"

select_backup_file "chat_data_backup_*.tar.gz" "Uploads"
DATA_FILE="$SELECTED_FILE"

if ! kubectl exec "$MONGO_POD" -n "$MONGO_NAMESPACE" -- command -v mongorestore >/dev/null 2>&1; then
    fail "mongorestore nicht im MongoDB-Container gefunden!"
fi

echo ""
echo "MongoDB: $MONGO_POD ($MONGO_NAMESPACE) | Chat: $CHAT_POD ($CHAT_NAMESPACE)"
echo "DB: $DB_FILE | Uploads: $DATA_FILE"
read -rp "Bist du sicher? Alle aktuellen Chat-Daten werden ueberschrieben! (ja/nein): " CONFIRM
[ "$CONFIRM" = "ja" ] || { echo "Abgebrochen."; exit 0; }

log "MongoDB-Dump in den Pod kopieren und einspielen..."
kubectl cp "$DB_FILE" "$MONGO_NAMESPACE/$MONGO_POD:/tmp/rc_mongo_restore.gz" \
    || fail "kubectl cp fehlgeschlagen."
kubectl exec "$MONGO_POD" -n "$MONGO_NAMESPACE" -- \
    sh -c "mongorestore --archive=/tmp/rc_mongo_restore.gz --gzip --drop --db=$DB_NAME" \
    || fail "mongorestore im Pod fehlgeschlagen."
kubectl exec "$MONGO_POD" -n "$MONGO_NAMESPACE" -- rm -f /tmp/rc_mongo_restore.gz

log "Uploads wiederherstellen..."
kubectl cp "$DATA_FILE" "$CHAT_NAMESPACE/$CHAT_POD:/tmp/rc_uploads_restore.tar.gz" -c "$CHAT_CONTAINER" \
    || fail "kubectl cp fehlgeschlagen."
kubectl exec "$CHAT_POD" -n "$CHAT_NAMESPACE" -c "$CHAT_CONTAINER" -- \
    sh -c "tar xzf /tmp/rc_uploads_restore.tar.gz -C /app/uploads && rm -f /tmp/rc_uploads_restore.tar.gz" \
    || fail "Entpacken im Pod fehlgeschlagen."

log "Rocket.Chat-Pod neu starten, damit die App die wiederhergestellten Daten neu einliest..."
kubectl delete pod "$CHAT_POD" -n "$CHAT_NAMESPACE" \
    || warn "Bitte manuell neu starten: kubectl delete pod $CHAT_POD -n $CHAT_NAMESPACE"

log "Rocket.Chat-Restore abgeschlossen."
