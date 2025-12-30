# LogBot

Zentraler Log-Server für Linux/Windows/Netzwerkgeräte mit Web-UI.

## Features

- **Syslog-Server** (UDP/TCP 514) - Auto-Discovery von Agents
- **Web-UI** - Dashboard, Logs, Agents, Webhooks, User-Management
- **UniFi Support** - CEF-Format Parsing für Controller + APs
- **Docker-basiert** - Ein Installer, alles drin

## Quick Start

```bash
# Debian 12 / Ubuntu 22.04+
sudo bash logbot-install.sh
```

**Web-UI:** `http://<server-ip>` → Login: `admin` / `admin`

## Architektur

```
Port 80/443 ──► Caddy ──► Frontend (Vue 3)
                      ──► Backend (FastAPI)
Port 514 ──────────────► Syslog Server ──► PostgreSQL
```

## Syslog-Geräte anbinden

| Einstellung | Wert |
|-------------|------|
| Server | `<logbot-ip>` |
| Port | `514` |
| Protokoll | UDP oder TCP |

Agents werden automatisch erstellt wenn Logs ankommen.

## Verzeichnisse

```
/opt/logbot/
├── docker-compose.yml
├── .env                 # Credentials (auto-generiert)
├── backend/             # FastAPI
├── frontend/            # Vue 3
├── syslog/              # Python Syslog Server
└── data/                # Persistente Daten
```

## Commands

```bash
cd /opt/logbot

# Status
sudo docker compose ps

# Logs
sudo docker compose logs -f syslog

# Neustart
sudo docker compose restart

# Backup DB
sudo docker exec logbot-db pg_dump -U logbot logbot > backup.sql
```

## Troubleshooting

```bash
# Syslog Test
echo "<14>Test message" | nc -u -w1 localhost 514

# Traffic prüfen
sudo tcpdump -i any port 514 -nn

# DB Check
sudo docker exec -it logbot-db psql -U logbot -d logbot -c "\dt"
```

## Ports

| Port | Dienst |
|------|--------|
| 80/443 | Web-UI |
| 514 | Syslog (UDP/TCP) |
| 9001 | Portainer Agent |


# n8n Integration

n8n Workflow zur automatisierten Log-Analyse via Telegram mit Claude AI.

## Beschreibung

Dieser Workflow ermöglicht es, Logs über Telegram abzufragen und automatisch von Claude Haiku analysieren zu lassen.

### Ablauf

```
Telegram Nachricht → Logs abrufen → Prüfen ob Logs vorhanden → Claude Analyse → Antwort via Telegram
```

## Voraussetzungen

- n8n (self-hosted oder Cloud)
- Telegram Bot Token
- Anthropic API Key
- Logbot Webhook Endpoint

## Installation

1. Workflow in n8n importieren
2. Credentials anlegen:
   - `Telegram account` - Bot Token
   - `Anthropic account` - API Key
3. Umgebungsvariable setzen:
   - `LOGBOT_WEBHOOK_URL` - URL zum Log-Endpoint

## Umgebungsvariablen

| Variable | Beschreibung |
|----------|--------------|
| `LOGBOT_WEBHOOK_URL` | Webhook URL für Log-Abruf |

## Credentials

Die Credential-IDs müssen nach dem Import durch eigene ersetzt werden:

- `{{ ANTHROPIC_CREDENTIAL_ID }}` → Anthropic API Credential
- `{{ TELEGRAM_CREDENTIAL_ID }}` → Telegram Bot Credential

## Nodes

| Node | Funktion |
|------|----------|
| Telegram Trigger | Empfängt Nachrichten |
| HTTP: Logs abrufen | Holt Logs vom Webhook |
| IF: Logs vorhanden | Prüft ob Logs existieren |
| Code: Logs formatieren | Bereitet Logs für Claude auf |
| AI Agent | Claude Haiku Analyse |
| Telegram: Analyse senden | Sendet Ergebnis zurück |

## Lizenz

MIT

## Autor

PF | Claude Opus 4
