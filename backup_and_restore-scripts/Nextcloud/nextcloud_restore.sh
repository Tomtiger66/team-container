#!/bin/bash

# ============================================================
# Nextcloud Restore-Skript (Optimiert für Kubernetes/k3s)
# ============================================================

DB_NAME="nextcloud"
DB_USER="nextcloud"
DB_PASS="kIrthoHer19Vollauf20"
NEXTCLOUD_CONTAINER="web"
BACKUP_DIR="$HOME/Backup"

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

# Hilfsfunktion: Backup-Datei auswählen
select_file() {
    local PATTERN=$1
    local LABEL=$2

    LATEST=$(ls -t "$BACKUP_DIR"/$PATTERN 2>/dev/null | head -1)

    if [ -z "$LATEST" ]; then
        echo "FEHLER: Keine $LABEL-Backup-Dateien in $BACKUP_DIR gefunden!"
        exit 1
    fi

    echo ""
    echo "==> Verfügbare $LABEL-Backups:"
    ls -lh "$BACKUP_DIR"/$PATTERN
    echo ""
    echo "    Neueste Datei: $LATEST"
    read -rp "    Datei verwenden (Enter für neueste, sonst Pfad angeben): " AUSWAHL

    if [ -z "$AUSWAHL" ]; then
        SELECTED_FILE="$LATEST"
    else
        if [ ! -f "$AUSWAHL" ]; then
            echo "FEHLER: Datei $AUSWAHL nicht gefunden!"
            exit 1
        fi
        SELECTED_FILE="$AUSWAHL"
    fi
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

# Backup-Dateien auswählen
select_file "nextcloud_db_backup_*.sql" "Datenbank"
DB_FILE="$SELECTED_FILE"

select_file "nextcloud_data_backup_*.tar.gz" "Datei"
DATA_FILE="$SELECTED_FILE"

# Zusammenfassung
echo ""
echo "============================================================"
echo "  Folgende Wiederherstellung wird durchgeführt:"
echo "  MariaDB   : $MARIADB_POD  (Namespace: $MARIADB_NAMESPACE)"
echo "  Nextcloud : $NEXTCLOUD_POD  (Namespace: $NEXTCLOUD_NAMESPACE)"
echo "  Datenbank : $DB_FILE"
echo "  Dateien   : $DATA_FILE"
echo "============================================================"
echo ""
read -rp "Bist du sicher? Alle aktuellen Daten werden überschrieben! (ja/nein): " CONFIRM

if [ "$CONFIRM" != "ja" ]; then
    echo "Abgebrochen."
    exit 0
fi

# Cleanup-Routine bei Fehler/Abbruch
cleanup() {
    echo ""
    echo "==> Deaktiviere Wartungsmodus (Cleanup)..."
    kubectl exec "$NEXTCLOUD_POD" -n "$NEXTCLOUD_NAMESPACE" -c "$NEXTCLOUD_CONTAINER" -- \
        su -s /bin/bash www-data -c "php occ maintenance:mode --off" >/dev/null 2>&1
}
trap cleanup EXIT

echo ""
echo "==> Wartungsmodus aktivieren..."
kubectl exec "$NEXTCLOUD_POD" -n "$NEXTCLOUD_NAMESPACE" -c "$NEXTCLOUD_CONTAINER" -- \
    su -s /bin/bash www-data -c "php occ maintenance:mode --on"

echo "==> Datenbank wiederherstellen..."

RESTORE_BIN=$(kubectl exec "$MARIADB_POD" -n "$MARIADB_NAMESPACE" -- \
    sh -c 'command -v mariadb || command -v mysql' | tr -d '\r')

if [ -z "$RESTORE_BIN" ]; then
    echo "FEHLER: Weder mariadb noch mysql im Container gefunden!"
    exit 1
fi

# Step 1: SQL-Datei in den Pod kopieren
kubectl cp "$DB_FILE" "$MARIADB_NAMESPACE/$MARIADB_POD:/tmp/nc_restore.sql"

# Step 2: Datenbank lokal im Pod einlesen
kubectl exec "$MARIADB_POD" -n "$MARIADB_NAMESPACE" -- \
    sh -c "$RESTORE_BIN -u \"$DB_USER\" -p\"$DB_PASS\" \"$DB_NAME\" < /tmp/nc_restore.sql"

# Step 3: Temp-Datei löschen
kubectl exec "$MARIADB_POD" -n "$MARIADB_NAMESPACE" -- rm -f /tmp/nc_restore.sql

echo "==> Dateien wiederherstellen..."
# Step 1: Tar-Archiv in den Nextcloud-Pod kopieren
kubectl cp "$DATA_FILE" "$NEXTCLOUD_NAMESPACE/$NEXTCLOUD_POD:/tmp/nc_data_restore.tar.gz" -c "$NEXTCLOUD_CONTAINER"

# Step 2: Entpacken im Arbeitsverzeichnis /var/www/html
kubectl exec "$NEXTCLOUD_POD" -n "$NEXTCLOUD_NAMESPACE" -c "$NEXTCLOUD_CONTAINER" -- \
    tar xzf /tmp/nc_data_restore.tar.gz -C /var/www/html

# Step 3: Temp-Datei löschen
kubectl exec "$NEXTCLOUD_POD" -n "$NEXTCLOUD_NAMESPACE" -c "$NEXTCLOUD_CONTAINER" -- rm -f /tmp/nc_data_restore.tar.gz

echo "==> Berechtigungen setzen..."
kubectl exec "$NEXTCLOUD_POD" -n "$NEXTCLOUD_NAMESPACE" -c "$NEXTCLOUD_CONTAINER" -- \
    chown -R www-data:www-data /var/www/html/data /var/www/html/config

echo "==> Nextcloud-Reparatur/Cache-Leerung..."
kubectl exec "$NEXTCLOUD_POD" -n "$NEXTCLOUD_NAMESPACE" -c "$NEXTCLOUD_CONTAINER" -- \
    su -s /bin/bash www-data -c "php occ maintenance:repair"

echo ""
echo "==> Restore erfolgreich abgeschlossen!"