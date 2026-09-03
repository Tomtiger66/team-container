#!/bin/bash

# ============================================================
# Nextcloud Backup-Skript (Optimiert für Kubernetes/k3s)
# ============================================================

DB_NAME="nextcloud"
DB_USER="nextcloud"
DB_PASS="kIrthoHer19Vollauf20"
NEXTCLOUD_CONTAINER="web"
BACKUP_DIR="$HOME/Backup"
TIMESTAMP=$(date +%d-%m-%Y_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Pods einlesen
mapfile -t PODS < <(kubectl get pods --all-namespaces --no-headers \
    | awk '{print $1, $2, $4}')

if [ ${#PODS[@]} -eq 0 ]; then
    echo "FEHLER: Keine Pods gefunden! Ist kubectl konfiguriert?"
    exit 1
fi

# Hilfsfunktion: Pod-Liste anzeigen
show_pods() {
    echo ""
    echo "==> Verfügbare Pods:"
    echo ""
    for i in "${!PODS[@]}"; do
        printf "    [%2d]  %-20s  %-50s  %s\n" \
            "$((i+1))" \
            "$(echo "${PODS[$i]}" | awk '{print $1}')" \
            "$(echo "${PODS[$i]}" | awk '{print $2}')" \
            "$(echo "${PODS[$i]}" | awk '{print $3}')"
    done
    echo ""
}

# MariaDB-Pod auswählen
echo "============================================================"
echo "  Bitte den MariaDB-Pod auswählen:"
echo "============================================================"
show_pods
read -rp "    Nummer eingeben: " AUSWAHL_DB

if ! [[ "$AUSWAHL_DB" =~ ^[0-9]+$ ]] || \
   [ "$AUSWAHL_DB" -lt 1 ] || \
   [ "$AUSWAHL_DB" -gt "${#PODS[@]}" ]; then
    echo "FEHLER: Ungültige Auswahl!"
    exit 1
fi

MARIADB_NAMESPACE=$(echo "${PODS[$((AUSWAHL_DB-1))]}" | awk '{print $1}')
MARIADB_POD=$(echo "${PODS[$((AUSWAHL_DB-1))]}" | awk '{print $2}')

# Nextcloud-Pod auswählen
echo ""
echo "============================================================"
echo "  Bitte den Nextcloud-Pod auswählen:"
echo "============================================================"
show_pods
read -rp "    Nummer eingeben: " AUSWAHL_NC

if ! [[ "$AUSWAHL_NC" =~ ^[0-9]+$ ]] || \
   [ "$AUSWAHL_NC" -lt 1 ] || \
   [ "$AUSWAHL_NC" -gt "${#PODS[@]}" ]; then
    echo "FEHLER: Ungültige Auswahl!"
    exit 1
fi

NEXTCLOUD_NAMESPACE=$(echo "${PODS[$((AUSWAHL_NC-1))]}" | awk '{print $1}')
NEXTCLOUD_POD=$(echo "${PODS[$((AUSWAHL_NC-1))]}" | awk '{print $2}')

# Zusammenfassung
echo ""
echo "============================================================"
echo "  Gewählte Pods:"
echo "  MariaDB   : $MARIADB_POD  (Namespace: $MARIADB_NAMESPACE)"
echo "  Nextcloud : $NEXTCLOUD_POD  (Namespace: $NEXTCLOUD_NAMESPACE)"
echo "  Backup    : $BACKUP_DIR"
echo "  Zeitstempel: $TIMESTAMP"
echo "============================================================"
echo ""

# Sicherheitsfunktion: Wartungsmodus bei Abbruch zuverlässig deaktivieren
cleanup() {
    echo ""
    echo "==> Deaktiviere Wartungsmodus (Cleanup)..."
    kubectl exec "$NEXTCLOUD_POD" -n "$NEXTCLOUD_NAMESPACE" -c "$NEXTCLOUD_CONTAINER" -- \
        su -s /bin/bash www-data -c "php occ maintenance:mode --off" >/dev/null 2>&1
}
trap cleanup EXIT

echo "==> Wartungsmodus aktivieren..."
kubectl exec "$NEXTCLOUD_POD" -n "$NEXTCLOUD_NAMESPACE" -c "$NEXTCLOUD_CONTAINER" -- \
    su -s /bin/bash www-data -c "php occ maintenance:mode --on"

echo "==> Datenbank-Backup erstellen..."

DUMP_BIN=$(kubectl exec "$MARIADB_POD" -n "$MARIADB_NAMESPACE" -- \
    sh -c 'command -v mariadb-dump || command -v mysqldump' | tr -d '\r')

if [ -z "$DUMP_BIN" ]; then
    echo "FEHLER: Weder mariadb-dump noch mysqldump im Container gefunden!"
    exit 1
fi

# Step 1: Dump direkt im Container nach /tmp schreiben
kubectl exec "$MARIADB_POD" -n "$MARIADB_NAMESPACE" -- \
    sh -c "$DUMP_BIN --single-transaction -h 127.0.0.1 -u \"$DB_USER\" -p\"$DB_PASS\" \"$DB_NAME\" > /tmp/nc_db_dump.sql"

# Step 2: Per kubectl cp bitgenau herauskopieren
kubectl cp "$MARIADB_NAMESPACE/$MARIADB_POD:/tmp/nc_db_dump.sql" "$BACKUP_DIR/nextcloud_db_backup_$TIMESTAMP.sql"

# Step 3: Temp-Datei im Container löschen
kubectl exec "$MARIADB_POD" -n "$MARIADB_NAMESPACE" -- rm -f /tmp/nc_db_dump.sql

if [ -s "$BACKUP_DIR/nextcloud_db_backup_$TIMESTAMP.sql" ]; then
    echo "    OK: $(ls -lh "$BACKUP_DIR/nextcloud_db_backup_$TIMESTAMP.sql" | awk '{print $5}')"
else
    echo "FEHLER: Datenbank-Backup fehlgeschlagen!"
    exit 1
fi

echo "==> Datei-Backup erstellen..."
# Step 1: Archive direkt im Container erstellen (im Verzeichnis /var/www/html)
kubectl exec "$NEXTCLOUD_POD" -n "$NEXTCLOUD_NAMESPACE" -c "$NEXTCLOUD_CONTAINER" -- \
    sh -c "cd /var/www/html && tar czf /tmp/nc_data_backup.tar.gz data/ config/config.php"

# Step 2: Per kubectl cp herauskopieren
kubectl cp "$NEXTCLOUD_NAMESPACE/$NEXTCLOUD_POD:/tmp/nc_data_backup.tar.gz" "$BACKUP_DIR/nextcloud_data_backup_$TIMESTAMP.tar.gz" -c "$NEXTCLOUD_CONTAINER"

# Step 3: Temp-Datei im Container löschen
kubectl exec "$NEXTCLOUD_POD" -n "$NEXTCLOUD_NAMESPACE" -c "$NEXTCLOUD_CONTAINER" -- rm -f /tmp/nc_data_backup.tar.gz

if [ -s "$BACKUP_DIR/nextcloud_data_backup_$TIMESTAMP.tar.gz" ]; then
    echo "    OK: $(ls -lh "$BACKUP_DIR/nextcloud_data_backup_$TIMESTAMP.tar.gz" | awk '{print $5}')"
else
    echo "FEHLER: Datei-Backup fehlgeschlagen!"
    exit 1
fi

echo ""
echo "==> Fertig! Backups gespeichert in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"/*"$TIMESTAMP"*