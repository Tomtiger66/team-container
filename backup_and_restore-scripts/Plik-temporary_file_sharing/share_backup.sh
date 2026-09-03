#!/usr/bin/env bash
#
# Share (Plik) Backup-Skript
#
# Hinweis: Es wird nur das gemountete Verzeichnis
# /home/plik/server/files (die hochgeladenen Dateien) gesichert.
# Plik legt seine Metadaten-Datenbank (Downloadlinks, Ablaufdaten
# etc.) laut Deployment moeglicherweise NICHT auf diesem PVC ab -
# im Zweifel sichert dieses Skript also nur die Rohdateien, nicht
# die interne Plik-Datenbank. Bitte nach dem ersten Lauf pruefen,
# ob das Archiv sinnvollen Inhalt hat.
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CONTAINER="share"

select_pod "Share (Plik)"
NAMESPACE="$SELECTED_NAMESPACE"
POD="$SELECTED_POD"

log "Dateien im Pod archivieren..."
kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- \
    sh -c "cd /home/plik/server/files && tar czf /tmp/share_backup.tar.gz ." \
    || fail "tar im Pod fehlgeschlagen."

OUT_FILE="$BACKUP_DIR/share_backup_$TIMESTAMP.tar.gz"
kubectl cp "$NAMESPACE/$POD:/tmp/share_backup.tar.gz" "$OUT_FILE" -c "$CONTAINER" \
    || fail "kubectl cp fehlgeschlagen."

kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- rm -f /tmp/share_backup.tar.gz

verify_file "$OUT_FILE"
ftp_upload "$OUT_FILE"

log "Share-Backup abgeschlossen: $OUT_FILE"
