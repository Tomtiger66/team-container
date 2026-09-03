#!/usr/bin/env bash
#
# RustDesk Restore-Skript
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CONTAINER="hbbs"

select_pod "RustDesk"
NAMESPACE="$SELECTED_NAMESPACE"
POD="$SELECTED_POD"

select_backup_file "rustdesk_backup_*.tar.gz" "RustDesk"
ARCHIVE="$SELECTED_FILE"

echo ""
echo "Pod: $POD ($NAMESPACE)   Archiv: $ARCHIVE"
read -rp "Bist du sicher? Der Server-Schluessel wird ueberschrieben - bestehende Clients kennen ggf. noch den alten Schluessel! (ja/nein): " CONFIRM
[ "$CONFIRM" = "ja" ] || { echo "Abgebrochen."; exit 0; }

kubectl cp "$ARCHIVE" "$NAMESPACE/$POD:/tmp/rustdesk_restore.tar.gz" -c "$CONTAINER" \
    || fail "kubectl cp fehlgeschlagen."

kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- \
    sh -c "tar xzf /tmp/rustdesk_restore.tar.gz -C /root && rm -f /tmp/rustdesk_restore.tar.gz" \
    || fail "Entpacken im Pod fehlgeschlagen."

log "RustDesk-Pod neu starten (hbbs UND hbbr teilen sich die Daten)..."
kubectl delete pod "$POD" -n "$NAMESPACE" \
    || warn "Bitte manuell neu starten: kubectl delete pod $POD -n $NAMESPACE"

log "RustDesk-Restore abgeschlossen."
