#!/usr/bin/env bash
#
# common.sh - gemeinsame Funktionen fuer die Teamserver Backup/Restore-Skripte
# Wird von den einzelnen *_backup.sh / *_restore.sh Skripten per "source" eingebunden.
#

# ------------------------------------------------------------------
# Konfiguration laden (optional, fuer FTP-Zugangsdaten etc.)
# Erwartet unter ~/.backup-teamserver.conf, siehe config.example.conf
# ------------------------------------------------------------------
CONFIG_FILE="${CONFIG_FILE:-$HOME/.backup-teamserver.conf}"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

BACKUP_DIR="${BACKUP_DIR:-$HOME/Backup}"
TIMESTAMP="$(date +%d-%m-%Y_%H%M%S)"

mkdir -p "$BACKUP_DIR"

# ------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------
log()  { echo "==> $*"; }
warn() { echo "WARNUNG: $*" >&2; }
fail() { echo "FEHLER: $*" >&2; exit 1; }

# ------------------------------------------------------------------
# Interaktive Pod-Auswahl (wie im bestehenden Nextcloud-Skript)
# Setzt nach Aufruf: SELECTED_NAMESPACE, SELECTED_POD
# ------------------------------------------------------------------
select_pod() {
    local PROMPT_LABEL="$1"

    mapfile -t PODS < <(kubectl get pods --all-namespaces --no-headers \
        | awk '{print $1, $2, $4}')

    if [ ${#PODS[@]} -eq 0 ]; then
        fail "Keine Pods gefunden! Ist kubectl konfiguriert?"
    fi

    echo ""
    echo "============================================================"
    echo "  Bitte den Pod fuer '$PROMPT_LABEL' auswaehlen:"
    echo "============================================================"
    echo ""
    for i in "${!PODS[@]}"; do
        printf "    [%2d]  %-25s  %-45s  %s\n" \
            "$((i+1))" \
            "$(echo "${PODS[$i]}" | awk '{print $1}')" \
            "$(echo "${PODS[$i]}" | awk '{print $2}')" \
            "$(echo "${PODS[$i]}" | awk '{print $3}')"
    done
    echo ""
    read -rp "    Nummer eingeben: " AUSWAHL

    if ! [[ "$AUSWAHL" =~ ^[0-9]+$ ]] || \
       [ "$AUSWAHL" -lt 1 ] || \
       [ "$AUSWAHL" -gt "${#PODS[@]}" ]; then
        fail "Ungueltige Auswahl!"
    fi

    SELECTED_NAMESPACE=$(echo "${PODS[$((AUSWAHL-1))]}" | awk '{print $1}')
    SELECTED_POD=$(echo "${PODS[$((AUSWAHL-1))]}" | awk '{print $2}')
}

# ------------------------------------------------------------------
# Interaktive Backup-Datei-Auswahl (wie im bestehenden Nextcloud-Skript)
# Setzt nach Aufruf: SELECTED_FILE
# ------------------------------------------------------------------
select_backup_file() {
    local PATTERN="$1"
    local LABEL="$2"

    local LATEST
    LATEST=$(ls -t "$BACKUP_DIR"/$PATTERN 2>/dev/null | head -1)

    if [ -z "$LATEST" ]; then
        fail "Keine $LABEL-Backup-Dateien in $BACKUP_DIR gefunden!"
    fi

    echo ""
    echo "==> Verfuegbare $LABEL-Backups:"
    ls -lh "$BACKUP_DIR"/$PATTERN
    echo ""
    echo "    Neueste Datei: $LATEST"
    read -rp "    Datei verwenden (Enter fuer neueste, sonst Pfad angeben): " AUSWAHL

    if [ -z "$AUSWAHL" ]; then
        SELECTED_FILE="$LATEST"
    else
        [ -f "$AUSWAHL" ] || fail "Datei $AUSWAHL nicht gefunden!"
        SELECTED_FILE="$AUSWAHL"
    fi
}

# ------------------------------------------------------------------
# Backup-Datei nach dem Herauskopieren verifizieren (nicht leer)
# ------------------------------------------------------------------
verify_file() {
    local FILE="$1"
    if [ -s "$FILE" ]; then
        log "OK: $(ls -lh "$FILE" | awk '{print $5}')  ->  $FILE"
    else
        fail "Backup-Datei $FILE ist leer oder fehlt - Backup fehlgeschlagen!"
    fi
}

# ------------------------------------------------------------------
# Optionaler FTP-Upload einer fertigen, bereits lokal verifizierten
# Backup-Datei. Wird uebersprungen, wenn FTP_HOST nicht gesetzt ist.
#
# Benoetigte Variablen (in ~/.backup-teamserver.conf):
#   FTP_HOST, FTP_USER, FTP_PASS, FTP_DIR (optional, Default "/")
# ------------------------------------------------------------------
ftp_upload() {
    local FILE="$1"
    local BASENAME
    BASENAME="$(basename "$FILE")"

    if [ -z "${FTP_HOST:-}" ]; then
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        warn "curl nicht gefunden - FTP-Upload von $BASENAME uebersprungen."
        return 0
    fi

    local FTP_TARGET_DIR="${FTP_DIR:-/}"
    FTP_TARGET_DIR="${FTP_TARGET_DIR%/}/"

    log "Lade $BASENAME auf FTP-Speicher hoch (${FTP_HOST}${FTP_TARGET_DIR}) ..."

    if curl --ftp-create-dirs -s -S \
        -T "$FILE" \
        "ftp://${FTP_HOST}${FTP_TARGET_DIR}${BASENAME}" \
        --user "${FTP_USER}:${FTP_PASS}"; then
        log "FTP-Upload von $BASENAME erfolgreich."
    else
        warn "FTP-Upload von $BASENAME fehlgeschlagen - lokale Kopie bleibt in $BACKUP_DIR erhalten."
    fi
}
