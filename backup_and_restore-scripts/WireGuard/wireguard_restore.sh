#!/usr/bin/env bash
#
# WireGuard Restore-Skript
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CONTAINER="wireguard"

select_pod "WireGuard"
NAMESPACE="$SELECTED_NAMESPACE"
POD="$SELECTED_POD"

select_backup_file "wireguard_backup_*.tar.gz" "WireGuard"
ARCHIVE="$SELECTED_FILE"

echo ""
echo "============================================================"
echo "  Folgende Wiederherstellung wird durchgefuehrt:"
echo "  Pod    : $POD (Namespace: $NAMESPACE)"
echo "  Archiv : $ARCHIVE"
echo "============================================================"
echo ""
read -rp "Bist du sicher? Alle aktuellen WireGuard-Keys/Configs werden ueberschrieben! (ja/nein): " CONFIRM
[ "$CONFIRM" = "ja" ] || { echo "Abgebrochen."; exit 0; }

log "Archiv in den Pod kopieren..."
kubectl cp "$ARCHIVE" "$NAMESPACE/$POD:/tmp/wg_restore.tar.gz" -c "$CONTAINER" \
    || fail "kubectl cp fehlgeschlagen."

log "Entpacken nach /config..."
kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- \
    sh -c "tar xzf /tmp/wg_restore.tar.gz -C /config && rm -f /tmp/wg_restore.tar.gz" \
    || fail "Entpacken im Pod fehlgeschlagen."

log "WireGuard-Pod neu starten, damit die Konfiguration/Keys neu geladen werden..."
kubectl delete pod "$POD" -n "$NAMESPACE" \
    || warn "Pod konnte nicht automatisch neu gestartet werden - bitte manuell: kubectl delete pod $POD -n $NAMESPACE"

echo ""
log "WireGuard-Restore abgeschlossen."
