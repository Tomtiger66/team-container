#!/usr/bin/env bash
#
# OpenSlides Restore-Skript
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CONTAINER="openslides"

select_pod "OpenSlides"
NAMESPACE="$SELECTED_NAMESPACE"
POD="$SELECTED_POD"

select_backup_file "openslides_backup_*.tar.gz" "OpenSlides"
ARCHIVE="$SELECTED_FILE"

echo ""
echo "Pod: $POD ($NAMESPACE)   Archiv: $ARCHIVE"
read -rp "Bist du sicher? Alle aktuellen OpenSlides-Daten werden ueberschrieben! (ja/nein): " CONFIRM
[ "$CONFIRM" = "ja" ] || { echo "Abgebrochen."; exit 0; }

kubectl cp "$ARCHIVE" "$NAMESPACE/$POD:/tmp/openslides_restore.tar.gz" -c "$CONTAINER" \
    || fail "kubectl cp fehlgeschlagen."

kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- \
    sh -c "tar xzf /tmp/openslides_restore.tar.gz -C /root/.local/share/openslides && rm -f /tmp/openslides_restore.tar.gz" \
    || fail "Entpacken im Pod fehlgeschlagen."

log "OpenSlides-Pod neu starten, damit die eingebettete Datenbank die wiederhergestellten Daten einliest..."
kubectl delete pod "$POD" -n "$NAMESPACE" \
    || warn "Bitte manuell neu starten: kubectl delete pod $POD -n $NAMESPACE"

log "OpenSlides-Restore abgeschlossen."
