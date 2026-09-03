#!/usr/bin/env bash
#
# WireGuard Backup-Skript (Server-/Peer-Keys + Konfiguration unter /config)
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CONTAINER="wireguard"

select_pod "WireGuard"
NAMESPACE="$SELECTED_NAMESPACE"
POD="$SELECTED_POD"

echo ""
echo "============================================================"
echo "  WireGuard-Backup: $POD (Namespace: $NAMESPACE)"
echo "============================================================"

log "Konfiguration/Keys im Pod archivieren..."
kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- \
    sh -c "cd /config && tar czf /tmp/wg_backup.tar.gz ." \
    || fail "tar im Pod fehlgeschlagen."

log "Archiv herauskopieren..."
OUT_FILE="$BACKUP_DIR/wireguard_backup_$TIMESTAMP.tar.gz"
kubectl cp "$NAMESPACE/$POD:/tmp/wg_backup.tar.gz" "$OUT_FILE" -c "$CONTAINER" \
    || fail "kubectl cp fehlgeschlagen."

kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- rm -f /tmp/wg_backup.tar.gz

verify_file "$OUT_FILE"
ftp_upload "$OUT_FILE"

echo ""
log "WireGuard-Backup abgeschlossen: $OUT_FILE"
