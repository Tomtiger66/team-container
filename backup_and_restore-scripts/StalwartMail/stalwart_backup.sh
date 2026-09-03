#!/usr/bin/env bash
#
# Stalwart Mail Backup-Skript (Maildaten + Konfiguration)
#
# Hinweis: Stalwart nutzt eine eingebettete RocksDB (kein separater
# DB-Server, kein mysqldump-Aequivalent). Ein tar-Snapshot bei
# laufendem Server ist ueblicherweise unkritisch, aber nicht zu 100%
# atomar. Fuer maximale Konsistenz vor dem Backup optional kurz
# skalieren:
#   kubectl scale deployment <name> -n <namespace> --replicas=0
# und danach wieder hochskalieren. Macht dieses Skript NICHT
# automatisch, um nicht ungefragt eine Mail-Ausfallzeit zu erzeugen.
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CONTAINER="stalwart"

select_pod "Stalwart Mail"
NAMESPACE="$SELECTED_NAMESPACE"
POD="$SELECTED_POD"

log "Maildaten und Konfiguration im Pod archivieren..."
kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- \
    tar czf /tmp/stalwart_backup.tar.gz --absolute-names /var/lib/stalwart /etc/stalwart \
    || fail "tar im Pod fehlgeschlagen."

OUT_FILE="$BACKUP_DIR/stalwart_backup_$TIMESTAMP.tar.gz"
kubectl cp "$NAMESPACE/$POD:/tmp/stalwart_backup.tar.gz" "$OUT_FILE" -c "$CONTAINER" \
    || fail "kubectl cp fehlgeschlagen."

kubectl exec "$POD" -n "$NAMESPACE" -c "$CONTAINER" -- rm -f /tmp/stalwart_backup.tar.gz

verify_file "$OUT_FILE"
ftp_upload "$OUT_FILE"

log "Stalwart-Backup abgeschlossen: $OUT_FILE"
