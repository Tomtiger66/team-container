# team-container

**team-container** is a collection of Helm charts that set up a complete, self-hosted collaboration server on Kubernetes (K3s). It was originally created by Jan Mahn for c't magazine and has since been extended with additional services, modernized for Traefik v3, and updated for current Kubernetes versions.

This fork adds significant new functionality on top of the original project while maintaining full compatibility with the original installation workflow.

> The original article (German, behind paywall): [c't 9/2020](https://www.heise.de/select/ct/2020/9/2007712573850503640) — the setup works without the article.

---

> ⚠️ **IMPORTANT NOTE:**
>
> Throughout this guide, as well as in all `values-*.yaml` files, **`example.org`** is used consistently as a placeholder.
> **You must ALWAYS replace `example.org` with your own, actual domain!**


---

## What's new in this fork

Compared to the original ct-Open-Source/team-container:

| Feature | Original | This fork |
|---------|----------|-----------|
| Traefik version | v2.2 | **v3.3** |
| Kubernetes API | v1beta1 (deprecated) | **v1** |
| OS Support | Ubuntu 18.04 | **Ubuntu 22.04 up to 26.04** (and other K3s-compatible Linux distros) |
| Nextcloud Talk HPB | ❌ | **✅ 3 variants** |
| Nextcloud Office | ❌ | **✅ Collabora** |
| Realtime whiteboards | ❌ | **✅ Nextcloud Whiteboard** |
| PDF signatures | ❌ | **✅ LibreSign** |
| Client Push | ❌ | **✅ notify_push** |
| Mail server | ❌ | **✅ Stalwart** |
| Remote access | ❌ | **✅ RustDesk** |
| TURN server | ❌ | **✅ coturn** |
| VPN server | ❌ | **✅ WireGuard** |

---

## Services included

### Core (original)
- **[Traefik v3](https://traefik.io)** — Reverse proxy and SSL termination via Let's Encrypt
- **[Nextcloud](https://nextcloud.com)** — File sharing, calendars, contacts
- **[Rocket.Chat](https://rocket.chat)** — Browser-based team chat
- **[Jitsi Meet](https://jitsi.org)** — Video conferencing
- **[Openslides](https://openslides.com)** — Assembly management
- **[Plik](https://github.com/root-gg/plik)** — Temporary file sharing

### New in this fork

#### Nextcloud extensions
- **[Collabora Online](https://www.collaboraonline.com/collabora-online/)** (`team-nextcloud`) — Full office suite in the browser (Writer, Calc, Impress)
- **[notify_push](https://github.com/nextcloud/notify_push)** (`team-nextcloud`) — Instant push notifications for desktop and mobile clients
- **[LibreSign](https://libresign.coop/)** (`team-libresign`) — PDF digital signatures with self-signed CA
- **[Nextcloud Whiteboard](https://github.com/nextcloud/whiteboard)** (`team-nextcloud`) — Realtime collaborative whiteboards (Excalidraw-based), separate WebSocket backend for live cursor/element sync between users

#### Communication
- **[Nextcloud Talk](https://nextcloud.com/talk/) HPB – AIO** (`team-nextcloud`, `hpb.enabled: true`) — All-in-one High Performance Backend for Talk (Signaling + Janus MCU + TURN), one Nextcloud instance
- **[Nextcloud Talk](https://nextcloud.com/talk/) HPB – Enterprise** (`team-signaling`) — Standalone signaling server (strukturag) + Janus MCU + coturn, supports multiple Nextcloud instances
- **[coturn](https://github.com/coturn/coturn)** (`team-coturn`) — Lightweight STUN/TURN server for small Talk deployments

#### Infrastructure
- **[Stalwart Mail Server](https://stalw.art/)** (`team-stalwart`) — Modern all-in-one mail server (SMTP, IMAP, JMAP, WebAdmin)
- **[RustDesk Server](https://rustdesk.com/)** (`team-rust`) — Self-hosted remote desktop server
- **[WireGuard](https://www.wireguard.com/)** (`team-wireguard`) — Self-hosted VPN server, e.g. to give clients a fixed server-side IP/location or for secure remote access to internal services

---

## Requirements

- **Operating System:** Tested on **Ubuntu Server 22.04 LTS up to 26.04** (Ubuntu was used by Jan Mahn and the maintainer). However, any Linux distribution supported by K3s can also be used.
- **Domain name:** Wildcard DNS (`*.example.org`) or individual subdomains pointing to your server IP.
- **Root or sudo access**
- **Basic Linux terminal experience**

No prior knowledge of Kubernetes, Helm or container technology required.

---

## Architecture

```
Internet
    │
    ▼ Port 80/443
Traefik v3 (SSL termination, Let's Encrypt)
    │
    ├── cloud.example.org      → Nextcloud
    ├── office.example.org     → Collabora Online
    ├── talk.example.org       → HPB Signaling Server
    ├── whiteboard.example.org → Nextcloud Whiteboard WebSocket server
    ├── video.example.org      → Jitsi Meet
    ├── chat.example.org       → Rocket.Chat
    ├── mail.example.org       → Stalwart WebAdmin
    └── www.example.org        → Landing page

hostPort (raw TCP/UDP, not via Traefik):
    ├── :25, :465, :587        → Stalwart SMTP
    ├── :143, :993             → Stalwart IMAP
    ├── :3478                  → TURN server
    ├── :31115-31119           → RustDesk
    └── :51820/udp             → WireGuard VPN
```

---

## Getting started

### 1. Clone and install

```bash
# Clone this repository
git clone https://github.com/Tomtiger66/team-container
cd team-container

# Run the install script - this will:
#   - Install current K3s (with built-in Traefik disabled)
#   - Install Helm
#   - Set required environment variables (KUBECONFIG, HELM_EXPERIMENTAL_OCI)
sudo ./install.sh

# Reboot your server before continuing!
sudo reboot
```

> **Why disable K3s built-in Traefik?**
> K3s ships with its own Traefik instance. The install script disables it (`--disable traefik`) so that team-container Traefik v3 can be installed manually without conflicts.

### 2. Install Traefik (router + SSL)

```bash
# Edit values-setup.yaml: enter your email address, domain, set production: true
helm install setup team-setup --values values-setup.yaml
```

Wait until `https://www.example.org` shows the landing page with a valid Let's Encrypt certificate.

### 3. Install Nextcloud

```bash
# Edit values-nextcloud.yaml: enter domain, admin credentials
helm install nextcloud team-nextcloud --values values-nextcloud.yaml
```

Nextcloud will be available at `https://cloud.example.org` after a few minutes. This also deploys the Nextcloud Whiteboard realtime backend — see [Nextcloud Whiteboard Setup](#nextcloud-whiteboard-setup-team-nextcloud) below for the config values and a known false-positive on the admin connection test.

### 4. Install optional services

```bash
# Jitsi Meet
helm install video team-video --values values-video.yaml

# Rocket.Chat
helm install chat team-chat --values values-chat.yaml

# Stalwart Mail Server
helm install mail team-stalwart --values values-stalwart.yaml

# team-signaling and team-coturn are alternatives - before installing either,
# set hpb.enabled: false in your values-nextcloud.yaml (see the scenario table
# under "Jitsi Meet – Audio/Video optimisation" to pick the right one)

# Enterprise Signaling Server (for multiple Nextcloud instances)
helm install signaling team-signaling --values values-signaling.yaml

# Lightweight TURN server (for small Talk deployments)
helm install coturn team-coturn --values values-coturn.yaml

# RustDesk remote desktop server
helm install rustdesk team-rust --values values-rust.yaml

# PDF digital signatures
helm install libresign team-libresign --values values-libresign.yaml

# WireGuard VPN server
helm install wireguard team-wireguard --values values-wireguard.yaml
```

---

## Stalwart Mail Server Setup (`team-stalwart`)

`team-stalwart` deploys the modern, Rust-based [Stalwart Mail Server](https://stalwart.io) providing SMTP, SMTPS, Submission, IMAP, IMAPS, JMAP, and a WebAdmin interface.

> **K3s Requirement Note:** Stalwart requires K3s v1.27+ (for containerd zstd compression support). The `install.sh` script automatically fetches a current version of K3s that fulfills this prerequisite. This note is relevant if you plan to integrate `team-stalwart` into an existing, standalone Kubernetes cluster.

> **Firewall:** See the central [Firewall](#firewall) section below for the required ports (SMTP/SMTPS/Submission/IMAP/IMAPS).

### 1. DNS Requirements
Configure the following DNS records for your domain in your registrar's panel (e.g. Netcup, Hetzner, Cloudflare). 

> **Important:** Host values for root records must be set to `@` (do not enter your full domain name into the host field).

| Host | Type | MX | Destination / Value | Description |
|:---|:---|:---|:---|:---|
| `@` | A | | `<Server-IP>` | Main domain IP |
| `*` | A | | `<Server-IP>` | Wildcard for web subdomains |
| `mail.example.org` | A | | `<Server-IP>` | Mail server domain |
| `@` | MX | 10 | `mail.example.org` | Primary mail server |
| `@` | TXT | | `v=spf1 mx ip4:<Server-IP> ~all` | SPF authentication |
| `_dmarc` | TXT | | `v=DMARC1; p=none; rua=mailto:postmaster@example.org` | DMARC policy |
| `v1-ed25519-<YYYYMMDD>._domainkey` | TXT | | `v=DKIM1; k=ed25519; h=sha256; p=<generated_key>` | Stalwart DKIM Key 1 (Ed25519) |
| `v1-rsa-<YYYYMMDD>._domainkey` | TXT | | `v=DKIM1; k=rsa; h=sha256; p=<generated_key>` | Stalwart DKIM Key 2 (RSA) |

- **Reverse DNS (PTR):** Must be configured directly in your hosting provider's panel: `<Server-IP>` → `mail.example.org`.

### 2. Finding the Complete DNS Zone File in Stalwart WebAdmin
Stalwart provides auto-generated, complete DNS records (including both DKIM selector keys, DANE, and autodiscovery records) directly inside the WebAdmin interface:
1. Log into `https://mail.example.org` using your administrator account (initial credentials can be read from `kubectl logs <stalwart-pod>`).
2. Click on the **Monitor icon** at the bottom left corner of the navigation sidebar (this expands the **Management** menu).
3. In the Management sub-tree, click on **Domains**.
4. You will see a tabular list of your configured domains. On the far right of your domain's row, in the **Actions** column, click the **three horizontal dots (`...`)**.
5. In the drop-down menu, select **View Zone File**.
6. Copy the exact DNS records provided into your domain registrar's DNS management panel.

### 3. Emergency Access / Password Recovery
If you lose or forget your WebAdmin administrator password, `values-stalwart.yaml` includes a built-in recovery mechanism:

```yaml
recovery:
  enabled: true       # Set to true to activate emergency login
  username: notfall   # Recovery username
  password: "letMeIn123!" # Temporary password
```

**Important Security Rule:** After using the emergency credentials to log in and set a new admin password, you **must set `enabled: false` again** in `values-stalwart.yaml` and redeploy (`helm upgrade mail team-stalwart --values values-stalwart.yaml`) to disable emergency access.  
  
**Account Setup for Your Email Clients**  
While email addresses should be set up using `name@mydomain.de`, you must use your full email address (`myname@mydomain.de`) as the username - not just `myname` - when configuring your address book and calendar.  
Additionally, use `mail.mydomain.de` as the CalDAV/CardDAV server address, not just `mydomain`.
 

---

## Nextcloud Whiteboard Setup (`team-nextcloud`)

`team-nextcloud` also deploys the [Nextcloud Whiteboard](https://github.com/nextcloud/whiteboard) collaboration backend, enabling realtime, multi-user whiteboard editing (built on Excalidraw). Unlike Collabora, it talks to Nextcloud via a JWT-signed WebSocket connection rather than WOPI, and runs as its own service on a dedicated subdomain.

### 1. Configuration

Set the following in `values-nextcloud.yaml` before installing:

```yaml
whiteboard:
  subdomain: whiteboard
  imageTag: "stable"
  storageStrategy: "lru"   # "redis" only needed if you scale to multiple replicas
  jwtSecretKey: "<generate with: openssl rand --hex 32>"
```

### 2. Automatic `occ` configuration

Manually entering `collabBackendUrl` and `jwt_secret_key` in **Administration → Whiteboard** after every install is easy to forget and easy to typo — the values must match `values-nextcloud.yaml` exactly. A Helm post-install/post-upgrade hook Job automates this: after every `helm install`/`helm upgrade`, it waits for the Nextcloud pod to become `Running`, then runs the two `occ config:app:set` calls for you. No manual admin-UI step required, and it re-applies automatically if you ever rotate `jwtSecretKey`.

You can still verify (or override) the values manually at any time:
```bash
kubectl exec "$(kubectl get pods -l app=nextcloud-team-nextcloud-nc -o jsonpath='{.items[0].metadata.name}')" -- \
  php occ config:app:get whiteboard collabBackendUrl
```

### 3. ⚠️ "Timeout" / "websocket error" on the admin settings page — usually a false positive

The **Administration → Whiteboard** "Verify connection" button is known to report `websocket error` or `timeout` even when the Whiteboard server is fully functional. Two confirmed causes, neither of which indicates an actual outage:

1. **Stale Content-Security-Policy after first install.** Nextcloud computes the page's CSP (including which WebSocket domains are allowed under `connect-src`) using cached app config on the PHP-FPM worker. If the Whiteboard app was configured *after* the Nextcloud pod was already running, the CSP served to the browser may still be missing `whiteboard.example.org`, causing the browser to block the connection outright (visible in the browser console as `Refused to connect ... violates Content Security Policy`).
   **Fix:** `kubectl rollout restart deployment/nextcloud-team-nextcloud-nc`, then hard-reload the admin page (or use a private/incognito window — some browsers cache CSP headers more aggressively than a normal reload clears).

2. **Server-side connection-test timeout on high-latency links.** Once the CSP issue above is resolved, the admin test button may *still* report `timeout` — this is a short client-side timeout on the Socket.IO handshake (polling → upgrade), which can be tight on high-latency connections (e.g. testing from overseas). **This does not mean the Whiteboard server is broken.**

**The reliable test is not the admin settings page — it's opening an actual whiteboard file.** A small wifi/no-connection icon appears in the bottom-right corner of the whiteboard editor if the realtime backend isn't reachable; if that icon is absent (or disappears after a reload), the connection is working. For full confidence, open the same whiteboard as two different users simultaneously and confirm edits sync live between them.

---

## WireGuard VPN Setup (`team-wireguard`)

`team-wireguard` deploys a [WireGuard](https://www.wireguard.com/) VPN server (`lscr.io/linuxserver/wireguard`) directly on the host network (`hostNetwork: true`) — WireGuard's UDP handshakes don't reliably survive being proxied through kube-proxy/conntrack on an idle connection, so it bypasses the usual Service/Ingress path entirely.

### 1. Configuration

Set the following in `values-wireguard.yaml` before installing:

```yaml
app:
  name: vpn              # subdomain -> vpn.example.org
  domain: example.org
wireguard:
  serverPort: "51820"
  peers: "4"                   # one config per device
  peerDns: "1.1.1.1,1.0.0.1"   # do NOT use "auto" - see note below
  internalSubnet: "10.13.13.0"
  allowedIps: "0.0.0.0/0"      # full-tunnel: ALL client traffic routes through this server
```

> **Why not `peerDns: "auto"`?** The upstream image disables its own internal DNS forwarder whenever it detects an already-populated `/etc/resolv.conf` at boot — which is always the case with `hostNetwork: true` on K3s (K3s injects its cluster-DNS IP there). `"auto"` silently leaves peers without any working DNS. Public resolvers sidestep the problem entirely and, as a side effect, aren't subject to typical ISP-level DNS filtering.

Firewall: see the central [Firewall](#firewall) section below (UDP port only, must match `serverPort`).

### 2. Automatic interface-detection fix (`postup-fix` hook)

In server mode, this image's `PostUp`/`PostDown` NAT rule is hardcoded to interface `eth+` with no way to configure it — not a bug as such: in the image's officially supported deployment style (plain Docker bridge network), the container's own interface is always named `eth0` by Docker convention, so `eth+` always matches there. It only breaks because this chart uses `hostNetwork: true` (WireGuard's UDP handshakes don't reliably survive kube-proxy/conntrack on an idle connection), which exposes the container to the *host's* real interface name instead — `ens3`, `enp0s3`, etc. on most current KVM/Ubuntu servers, which `eth+` never matches. Without a fix, peers get a successful handshake but no internet access through the tunnel. (The README also mentions an `INTERFACE` variable for server mode — don't bother setting it, it's an internal helper variable computed from `INTERNAL_SUBNET` and gets overwritten immediately; see [linuxserver/docker-wireguard#417](https://github.com/linuxserver/docker-wireguard/issues/417) for the full story.)

A Helm post-install/post-upgrade hook Job (`templates/hook-postup-fix.yaml`) works around this automatically: after every `helm install`/`helm upgrade`, it waits for `wg0.conf` to be generated, patches the `PostUp`/`PostDown` lines to detect the actual default-route interface at runtime (`ip route get 1.1.1.1`) and inserts the FORWARD accept rules at the top of the chain (`-I FORWARD 1` instead of `-A`, so they aren't shadowed by kube-router's/UFW's own forward-chain rules), then restarts the pod. No manual steps required — this runs automatically on every install/upgrade.

### 3. Retrieving peer configs

```bash
# Pod name (excludes the postup-fix hook pod)
kubectl get pods | grep wireguard-team-wireguard- | grep -v postup-fix | sed 's/ .*//'

# Peer config as text
kubectl exec "$(kubectl get pods | grep wireguard-team-wireguard- | grep -v postup-fix | sed 's/ .*//')" -- cat /config/peer1/peer1.conf

# Peer config as a scannable QR code (for mobile clients)
kubectl exec "$(kubectl get pods | grep wireguard-team-wireguard- | grep -v postup-fix | sed 's/ .*//')" -- sh -c "qrencode -t ansiutf8 < /config/peer1/peer1.conf"

# Peer config as a PNG (use "kubectl cp", not "exec -it" - a TTY corrupts binary output)
kubectl cp "default/$(kubectl get pods | grep wireguard-team-wireguard- | grep -v postup-fix | sed 's/ .*//'):/config/peer1/peer1.png" ./peer1.png
```
Replace `peer1` with `peer2`, `peer3`, ... for additional devices (one is generated per `peers` in `values-wireguard.yaml`).

### 4. Adding the connection on a client

- **iOS/Android:** Scan the QR code (PNG or ASCII) with the official WireGuard app.
- **Linux (NetworkManager):**
  ```bash
  sudo nmcli connection import type wireguard file peer1.conf
  ```
  (Some distros' GUI import dialogs default to an OpenVPN-only file filter and reject a perfectly valid WireGuard file with a misleading error — `nmcli` bypasses this.)

Verify from the server side:
```bash
kubectl exec "$(kubectl get pods | grep wireguard-team-wireguard- | grep -v postup-fix | sed 's/ .*//')" -- wg show
```
Non-zero `transfer` in **both** directions (not just `received`) confirms the tunnel has working NAT, not just a handshake.

---

## Firewall

This list can be run via copy/paste as a script to open the required ports. Simply comment out any ports for applications you don't need using a hash (#).

```bash  
# ==============================================================================
# FIREWALL CONFIGURATION (COMPLETE LIST)
# ==============================================================================

# System Access & File Transfer
sudo ufw allow 22/tcp comment 'Standard SSH port'
sudo ufw allow 1022/tcp comment 'Alternative SSH port'
sudo ufw allow 21/tcp comment 'FTP control port'
sudo ufw allow 990/tcp comment 'FTPS implicit TLS'

# Web Traffic & K3s Ingress
sudo ufw allow 80/tcp comment 'K3s Ingress HTTP traffic'
sudo ufw allow 443/tcp comment 'K3s Ingress HTTPS traffic'

# K3s Standalone Orchestration
sudo ufw allow 6443/tcp comment 'Kubernetes API Server'

# RustDesk Remote Desktop
sudo ufw allow 31115/tcp comment 'RustDesk hbbs NAT-Test'
sudo ufw allow 31116/tcp comment 'RustDesk hbbs ID-Register TCP'
sudo ufw allow 31116/udp comment 'RustDesk hbbs ID-Register UDP'
sudo ufw allow 31117/tcp comment 'RustDesk hbbr Relay'
sudo ufw allow 31119/tcp comment 'RustDesk hbbr WebSocket'

# TURN Server (Coturn / Team-Signaling)
sudo ufw allow 3478/tcp comment 'Turnserver TCP'
sudo ufw allow 3478/udp comment 'Turnserver UDP'
sudo ufw allow 49152:65535/udp comment 'TURN/STUN media relay ports'

# Jitsi Videokonferenz (JVB)
sudo ufw allow 30000/udp comment 'Jitsi JVB UDP media'
sudo ufw allow 30001/tcp comment 'Jitsi JVB TCP'

# Stalwart Mail Server
sudo ufw allow 25/tcp comment 'Stalwart SMTP'
sudo ufw allow 465/tcp comment 'Stalwart SMTPS'
sudo ufw allow 587/tcp comment 'Stalwart Submission'
sudo ufw allow 143/tcp comment 'Stalwart IMAP'
sudo ufw allow 993/tcp comment 'Stalwart IMAPS'

# WireGuard VPN
sudo ufw allow 51820/udp comment 'WireGuard VPN'

```

---

## Jitsi Meet – Audio/Video optimisation

The `team-video` chart includes advanced configuration options for audio and video quality, particularly useful for **music lessons** or other scenarios where standard video conferencing settings are too aggressive.

All options are **disabled by default** for normal video conferencing. Enable them in `values-video.yaml` as needed:

| Option | Description | Music lessons |
|--------|-------------|---------------|
| `forceVideoKeepAlive` | Never disable video due to low bandwidth | ✅ enable |
| `audioFirstMusicMode` | Drop framerate instead of resolution on low bandwidth – keeps details (e.g. guitar strings) visible | ✅ enable |
| `optimizeScreenshareForPDF` | Limit screenshare to 5 fps – ideal for static sheets/plans, not for video | optional |
| `autoGainControl` | Automatic volume levelling – keeps all participants at equal volume. **Disable for music lessons** as it would constantly "correct" | ❌ disable for music |
| `ENABLE_AUDIO_PROCESSING` | **GLOBAL MAIN SWITCH:** Activates WebRTC audio processing in the browser. Must be set to "true" to allow targeted control of the underlying filters (NS, HPF). | ❌ disable for music |
| `DISABLE_NS` | Disable noise suppression – prevents music being filtered as background noise | ✅ enable |
| `DISABLE_HPF` | Disable high-pass filter – preserves bass frequencies (low guitar strings etc.) | ✅ enable |
| `ENABLE_STEREO` | Enable high-quality stereo audio via Opus | ✅ enable |
| `jvbTrustBwe` | Set to `false` to prevent automatic video suspension on bandwidth estimation. **Also fixes PDF screensharing in planning meetings** – JVB sometimes misreads bandwidth when a high-resolution PDF is shared and incorrectly disables video streams | set to `false` for music lessons and PDF-heavy meetings |

For students without headphones who need echo cancellation, use a special URL parameter that overrides the server settings per session:
```
https://video.example.org/ROOMNAME#config.audioQuality.stereo=false&config.disableAEC=false
```

---

### Choosing a TURN/Signaling setup by scale

| Scenario | Solution |
|----------|----------|
| Small groups (up to ~4 participants) | `team-coturn` only |
| One Nextcloud, up to ~10 participants | `hpb.enabled: true` in `values-nextcloud.yaml` |
| Multiple Nextcloud instances or large meetings | `team-signaling` (separate chart) |

---

## Known issues

- IPv6 certificate generation may not work in all configurations

---

## Contributing

This fork welcomes contributions! If you have improvements, bug fixes or new service charts, please open a Pull Request.

For the original project roadmap and issues, see the [ct-Open-Source/team-container project board](https://github.com/ct-Open-Source/team-container/projects/1).

---

## Acknowledgements

This project is based on the excellent original work by **Jan Mahn** and the team at **c't magazine**.

Special thanks and acknowledgement are extended to the AI systems from **Claude** (Anthropic) and **Google** (Gemini), without whose assistance the migration to Traefik v3, code optimization, bug fixes, and feature extensions of the Teamserver project would not have been possible.

---

## Upgrading from Traefik v2 (original c't project)

> **Important Note:** Users of the original c't Teamserver setup running Traefik v2 **must migrate their installation to Traefik v3.3** before using this updated repository/fork.

If you are upgrading an existing installation of the original ct-Open-Source/team-container running Traefik v2:

### 1. Apply new CRDs
```bash
kubectl apply -f team-setup/crds/traefik-crds.yaml
```

### 2. Apply updated RBAC
```bash
kubectl apply -f team-setup/templates/ingress/01-role.yml
```

### 3. Clean up legacy Traefik v2 CRDs (Recommended)
If upgrading a cluster that has been running Traefik v2 for a long time, clean up the obsolete CRDs under the old `traefik.containo.us` API group to prevent conflicts:
```bash
kubectl delete crd ingressroutes.traefik.containo.us \
  ingressroutetcps.traefik.containo.us \
  ingressrouteudps.traefik.containo.us \
  middlewares.traefik.containo.us \
  tlsoptions.traefik.containo.us \
  tlsstores.traefik.containo.us \
  traefikservices.traefik.containo.us
```

### 4. Upgrade Traefik
```bash
helm upgrade setup team-setup --values values-setup.yaml
```

### 5. IngressRoute API Migration
All custom resource definitions (CRDs) and ingress routes in this fork have been migrated to the Traefik v3 API group:
- **Old (Traefik v2):** `apiVersion: traefik.containo.us/v1alpha1`
- **New (Traefik v3):** `apiVersion: traefik.io/v1alpha1`
