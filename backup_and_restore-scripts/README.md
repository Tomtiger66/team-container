# Teamserver Backup/Restore-Skripte

Analog zu `nextcloud_backup.sh` / `nextcloud_restore.sh`: interaktive
Pod-Auswahl, Backup wird **erst im Pod** erzeugt und danach per
`kubectl cp` herauskopiert (kein Live-Streaming in den Backupordner),
Backup-Datei wird nach dem Kopieren auf Größe > 0 geprüft.

## Installation

Alle Dateien in einen Ordner legen (z.B. `~/backup-scripts/`) und
ausführbar machen:

```bash
chmod +x *.sh
```

Optional: `config.example.conf` nach `~/.backup-teamserver.conf`
kopieren und anpassen, falls automatischer FTP-Upload gewünscht ist.
Ohne diese Datei (bzw. ohne gesetztes `FTP_HOST`) bleibt es beim rein
lokalen Backup unter `$HOME/Backup`.

## Dateien

| Skript | Dienst | Was wird gesichert |
|---|---|---|
| `wireguard_backup.sh` / `_restore.sh` | WireGuard VPN | Server-/Peer-Keys + Konfiguration (`/config`) |
| `rustdesk_backup.sh` / `_restore.sh` | RustDesk | Server-Schlüsselpaar + interne DB (`/root`, PVC `rustdesk-storage`) |
| `stalwart_backup.sh` / `_restore.sh` | Stalwart Mail | Maildaten (RocksDB) + Konfiguration |
| `share_backup.sh` / `_restore.sh` | Share (Plik) | Hochgeladene Dateien (`/home/plik/server/files`) |
| `openslides_backup.sh` / `_restore.sh` | OpenSlides | Komplettes Datenverzeichnis (All-in-One-Image) |
| `chat_backup.sh` / `_restore.sh` | Rocket.Chat | MongoDB-Dump (`mongodump`/`mongorestore`) + Uploads |

Alle Skripte fragen (wie im Nextcloud-Skript) Namespace und Pod
interaktiv über eine nummerierte Liste ab, statt Helm-Release-Namen
fest zu verdrahten.

## Wichtige Hinweise / offene Punkte

- **RustDesk hat entgegen der `values-rust.yaml` sehr wohl
  persistente Daten**: Das Deployment mountet eine PVC
  `rustdesk-storage` nach `/root` in beiden Containern (`hbbs`,
  `hbbr`). Dort liegt das Schlüsselpaar, mit dem sich alle Clients
  authentifizieren – ohne Backup muss nach einem Datenverlust jeder
  Client neu konfiguriert werden.
- **Share (Plik)**: Es wird nur der Datei-Mount gesichert. Ob Plik
  seine Metadaten-Datenbank (Downloadlinks, Ablaufdaten) ebenfalls
  dort ablegt oder an anderer, nicht-persistenter Stelle, ist aus dem
  Deployment nicht ersichtlich – nach dem ersten Backup-Lauf bitte
  kurz den Archivinhalt prüfen.
- **OpenSlides**: Das gelieferte Deployment zeigt nur einen
  Pod/eine PVC (All-in-One-Image `jamct/openslides`). Falls es
  zusätzlich einen separaten Datenbank-Pod gibt, bitte Bescheid
  geben – dann braucht es einen DB-Dump-Schritt wie bei Chat.
- **Stalwart**: RocksDB ist eine eingebettete Datenbank ohne
  mysqldump-Äquivalent. Der tar-Snapshot bei laufendem Server ist
  in der Praxis unkritisch, aber nicht zu 100% atomar. Für maximale
  Konsistenz kann der Pod vor dem Backup manuell auf 0 Replicas
  skaliert werden (macht das Skript nicht automatisch, um keine
  ungewollte Mail-Ausfallzeit zu erzeugen).
- **LibreSign**: braucht kein eigenes Skript – läuft laut Kommentar
  in der `values-libresign.yaml` ohne eigenen Pod und legt seine
  Daten im Nextcloud-PVC ab, ist also bereits im Nextcloud-Backup
  enthalten.
- **Coturn**: kein `storage`-Abschnitt, keine PVC im Deployment –
  rein zustandslos (nur ein Secret), kein Backup nötig.
