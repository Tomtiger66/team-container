#!/usr/bin/env bash
#
# Share (Plik) Restore-Skript
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CONTAINER="share"

select_pod "Share (Plik)"
NAMESPACE="$SELECTED_NAMESPACE"
POD="$SELECTED_POD"

select_backup_file "share_backup_*.tar.gz" "Share"
ARCHIVE="$SELECTED_FILE"

echo ""
echo "Pod: $POD ($NAMESPACE)   Archiv: $ARCHIVE"
read -rp "Bist du sicher? Alle aktuellen Dateien werden ueberschrieben! (ja/nein): " CONFIRM
[ "$CONFIRM" = "ja" ] || { echo "Abgebrochen."; exit 0; }

kubectl cp "$ARCHIVE" "$NAMESPACE/$POD:/tmp/share_restore.tar.gz" -c "$CONTAINER" \
    || fail "kubectl cp fehlgeschlagen."

kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- \
    sh -c "tar xzf /tmp/share_restore.tar.gz -C /home/plik/server/files && rm -f /tmp/share_restore.tar.gz" \
    || fail "Entpacken im Pod fehlgeschlagen."

log "Share-Restore abgeschlossen."
