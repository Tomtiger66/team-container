#!/usr/bin/env bash
#
# Stalwart Mail Restore-Skript
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CONTAINER="stalwart"

select_pod "Stalwart Mail"
NAMESPACE="$SELECTED_NAMESPACE"
POD="$SELECTED_POD"

select_backup_file "stalwart_backup_*.tar.gz" "Stalwart"
ARCHIVE="$SELECTED_FILE"

echo ""
echo "Pod: $POD ($NAMESPACE)   Archiv: $ARCHIVE"
read -rp "Bist du sicher? Alle aktuellen Maildaten werden ueberschrieben! (ja/nein): " CONFIRM
[ "$CONFIRM" = "ja" ] || { echo "Abgebrochen."; exit 0; }

kubectl cp "$ARCHIVE" "$NAMESPACE/$POD:/tmp/stalwart_restore.tar.gz" -c "$CONTAINER" \
    || fail "kubectl cp fehlgeschlagen."

log "Entpacken (ueberschreibt /var/lib/stalwart und /etc/stalwart)..."
kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- \
    sh -c "tar xzf /tmp/stalwart_restore.tar.gz -C / && rm -f /tmp/stalwart_restore.tar.gz" \
    || fail "Entpacken im Pod fehlgeschlagen."

log "Stalwart-Pod neu starten, damit RocksDB die wiederhergestellten Daten neu einliest..."
kubectl delete pod "$POD" -n "$NAMESPACE" \
    || warn "Bitte manuell neu starten: kubectl delete pod $POD -n $NAMESPACE"

log "Stalwart-Restore abgeschlossen."
