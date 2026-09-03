#!/usr/bin/env bash
#
# OpenSlides Backup-Skript
#
# Hinweis: Das Deployment zeigt nur einen Pod/eine PVC (All-in-One
# Image "jamct/openslides", das Web/App/DB in einem Container
# buendelt). Falls es bei euch zusaetzlich einen separaten
# Datenbank-Pod gibt (nicht im gelieferten Manifest sichtbar), bitte
# Bescheid geben - dann braucht es zusaetzlich einen DB-Dump-Schritt
# wie bei Chat/Nextcloud.
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CONTAINER="openslides"

select_pod "OpenSlides"
NAMESPACE="$SELECTED_NAMESPACE"
POD="$SELECTED_POD"

log "Daten im Pod archivieren..."
kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- \
    sh -c "cd /root/.local/share/openslides && tar czf /tmp/openslides_backup.tar.gz ." \
    || fail "tar im Pod fehlgeschlagen."

OUT_FILE="$BACKUP_DIR/openslides_backup_$TIMESTAMP.tar.gz"
kubectl cp "$NAMESPACE/$POD:/tmp/openslides_backup.tar.gz" "$OUT_FILE" -c "$CONTAINER" \
    || fail "kubectl cp fehlgeschlagen."

kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- rm -f /tmp/openslides_backup.tar.gz

verify_file "$OUT_FILE"
ftp_upload "$OUT_FILE"

log "OpenSlides-Backup abgeschlossen: $OUT_FILE"
