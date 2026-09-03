#!/usr/bin/env bash
#
# RustDesk Backup-Skript (Server-Schluesselpaar + interne DB unter /root)
#
# Hinweis: hbbs und hbbr teilen sich dieselbe PVC "rustdesk-storage"
# unter /root - ein Backup ueber einen der beiden Container reicht,
# hier wird hbbs verwendet.
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CONTAINER="hbbs"

select_pod "RustDesk"
NAMESPACE="$SELECTED_NAMESPACE"
POD="$SELECTED_POD"

log "Schluesselpaar/DB im Pod archivieren (Container $CONTAINER, /root)..."
kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- \
    sh -c "cd /root && tar czf /tmp/rustdesk_backup.tar.gz ." \
    || fail "tar im Pod fehlgeschlagen."

OUT_FILE="$BACKUP_DIR/rustdesk_backup_$TIMESTAMP.tar.gz"
kubectl cp "$NAMESPACE/$POD:/tmp/rustdesk_backup.tar.gz" "$OUT_FILE" -c "$CONTAINER" \
    || fail "kubectl cp fehlgeschlagen."

kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- rm -f /tmp/rustdesk_backup.tar.gz

verify_file "$OUT_FILE"
ftp_upload "$OUT_FILE"

log "RustDesk-Backup abgeschlossen: $OUT_FILE"
