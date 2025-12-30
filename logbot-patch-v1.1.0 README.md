# LogBot

Ein zentraler Log-Server für Linux, Windows und Netzwerkgeräte mit Web-UI und n8n-Integration.

![Version](https://img.shields.io/badge/version-1.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Syslog-Server** - Empfängt Logs via UDP/TCP Port 514
- **Web-UI** - Moderne Oberfläche für Log-Analyse
- **Auto-Discovery** - Agents werden automatisch bei erstem Log erstellt
- **UniFi Support** - CEF-Format Parsing für Controller + Access Points
- **Webhooks** - n8n/Make/Zapier Integration mit Token-Authentifizierung
- **Multi-User** - Benutzerverwaltung mit Rollen (Admin/Viewer)
- **Export** - CSV und JSON Export
- **Portainer** - Remote-Management via Agent

## Architektur

```
┌─────────────────────────────────────────────────────────────┐
│                        LogBot                                │
├─────────────┬─────────────┬─────────────┬──────────────────┤
│   Syslog    │   Backend   │  Frontend   │     Caddy        │
│  (UDP/TCP)  │  (FastAPI)  │   (Vue 3)   │ (Reverse Proxy)  │
│   :514      │   :8000     │    :80      │    :80/:443      │
├─────────────┴─────────────┴─────────────┴──────────────────┤
│                     PostgreSQL                              │
│                       :5432                                 │
└─────────────────────────────────────────────────────────────┘
```

## Installation

### Voraussetzungen

- Debian 12 / Ubuntu 22.04+
- Root oder sudo-Rechte
- Internetverbindung
- Min. 2GB RAM, 10GB Speicher

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/DEIN-REPO/logbot/main/install.sh | sudo bash
```

### Manuelle Installation

```bash
git clone https://github.com/DEIN-REPO/logbot.git
cd logbot
sudo bash install.sh
```

## Erster Login

- **URL:** `http://DEINE-SERVER-IP`
- **Username:** `admin`
- **Password:** `admin`

⚠️ **Wichtig:** Passwort nach erstem Login ändern!

## Syslog konfigurieren

### Linux (rsyslog)

```bash
echo "*.* @LOGBOT-IP:514" | sudo tee /etc/rsyslog.d/99-logbot.conf
sudo systemctl restart rsyslog
```

### UniFi Controller

1. Settings → System → Remote Logging
2. Syslog Server: `LOGBOT-IP`
3. Port: `514`

### Windows (NXLog)

```xml
<Input eventlog>
    Module im_msvistalog
</Input>
<Output logbot>
    Module om_udp
    Host LOGBOT-IP
    Port 514
</Output>
```

## Webhooks & n8n Integration

LogBot bietet Webhooks die von externen Tools abgefragt werden können.

### Webhook erstellen

1. LogBot UI → Webhooks → "+ Neuer Webhook"
2. Name eingeben
3. Optional: Experten-Modus für Filter aktivieren
4. "Erstellen" klicken
5. **URL + Token kopieren** (Token wird nur einmal angezeigt!)

### n8n Workflow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Schedule   │────▶│ HTTP Request │────▶│     Code     │────▶│    Claude    │
│  (5 min)     │     │ (LogBot URL) │     │ (Format)     │     │  (Analyse)   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

#### HTTP Request Node

- **Method:** GET
- **URL:** `http://LOGBOT-IP/api/webhook/WEBHOOK-ID/call?token=DEIN-TOKEN`
- **Query Parameters:**
  - `since_minutes` - Logs der letzten X Minuten (default: 60)

#### Response Format

```json
{
  "webhook": "n8n-Logs",
  "query": {
    "since_minutes": 60,
    "severities": ["error", "warning"],
    "hostname_filter": null,
    "source_filter": null
  },
  "count": 25,
  "logs": [
    {
      "id": 12345,
      "hostname": "webserver-01",
      "timestamp": "2025-01-15T14:32:18.123Z",
      "level": "error",
      "source": "nginx",
      "message": "connect() failed (111: Connection refused)"
    }
  ]
}
```

#### Code Node (Logs formatieren)

```javascript
const data = $input.first().json;
const logs = data.logs || [];

let text = "Log-Analyse (" + data.count + " Eintraege)\n";
text += "Zeitraum: letzte " + data.query.since_minutes + " Minuten\n\n";

for (const log of logs) {
  text += "[" + log.timestamp + "] " + log.level.toUpperCase() + " - " + log.hostname + "\n";
  text += log.message + "\n\n";
}

return [{ json: { logText: text, count: data.count } }];
```

#### n8n Expressions

| Wert | Expression |
|------|------------|
| Anzahl Logs | `{{ $json.count }}` |
| Alle Logs | `{{ $json.logs }}` |
| Erste Message | `{{ $json.logs[0].message }}` |
| Formatierter Text | `{{ $json.logText }}` |

## API Endpoints

### Authentifizierung

```bash
# Login
curl -X POST http://LOGBOT/api/auth/login \
  -d "username=admin&password=admin"

# Response: {"access_token": "xxx", "token_type": "bearer"}
```

### Logs

```bash
# Logs abrufen
curl -H "Authorization: Bearer TOKEN" \
  http://LOGBOT/api/logs?limit=100&level=error

# Live Logs
curl -H "Authorization: Bearer TOKEN" \
  http://LOGBOT/api/logs/live

# Stats
curl -H "Authorization: Bearer TOKEN" \
  http://LOGBOT/api/logs/stats
```

### Webhooks (Public)

```bash
# Webhook aufrufen (kein Bearer Token nötig)
curl "http://LOGBOT/api/webhook/WEBHOOK-ID/call?token=WEBHOOK-TOKEN&since_minutes=30"
```

## Verzeichnisstruktur

```
/opt/logbot/
├── docker-compose.yml
├── .env                    # Credentials (auto-generated)
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/
│       ├── main.py
│       ├── config/
│       ├── models/
│       └── routes/
├── frontend/
│   ├── Dockerfile
│   └── src/
│       ├── views/
│       ├── components/
│       └── stores/
├── syslog/
│   ├── Dockerfile
│   └── server.py
├── caddy/
│   └── Caddyfile
├── db/
│   └── init/
│       └── 001_schema.sql
└── data/
    ├── postgres/
    ├── caddy_data/
    └── caddy_config/
```

## Docker Commands

```bash
cd /opt/logbot

# Status
sudo docker compose ps

# Logs
sudo docker compose logs -f backend
sudo docker compose logs -f syslog

# Neustart
sudo docker compose restart

# Rebuild nach Änderungen
sudo docker compose build backend frontend
sudo docker compose up -d

# Stoppen
sudo docker compose down

# Komplett entfernen (inkl. Daten)
sudo docker compose down -v
```

## Updates

### Patch einspielen

```bash
curl -fsSL https://raw.githubusercontent.com/DEIN-REPO/logbot/main/patches/v1.1.0-webhooks.sh | sudo bash
```

### Manuelles Update

```bash
cd /opt/logbot
git pull
sudo docker compose build
sudo docker compose up -d
```

## Troubleshooting

### Logs kommen nicht an

```bash
# Syslog-Container prüfen
sudo docker compose logs syslog

# Port prüfen
sudo netstat -ulnp | grep 514

# Test-Log senden
logger -n LOGBOT-IP -P 514 "Test message"
```

### Web-UI nicht erreichbar

```bash
# Container Status
sudo docker compose ps

# Caddy Logs
sudo docker compose logs caddy

# Backend Logs
sudo docker compose logs backend
```

### Datenbank-Probleme

```bash
# DB Container prüfen
sudo docker compose logs postgres

# Direkt verbinden
sudo docker compose exec postgres psql -U logbot -d logbot
```

## Changelog

### v1.1.0 (2024-12-30)
- **NEU:** Incoming Webhooks für n8n/Make/Zapier
- **NEU:** Token-basierte Authentifizierung für Webhooks
- **NEU:** Einfach/Experten-Modus im Webhook-UI
- **NEU:** Log-Filter (Severity, Hostname, Source)
- **FIX:** Verbesserte UniFi AP Log-Parsing

### v1.0.0 (2024-12-29)
- Initial Release
- Syslog Server (UDP/TCP)
- Web-UI mit Vue 3
- User Management
- Agent Auto-Discovery
- UniFi CEF Support

## Lizenz

MIT License - siehe [LICENSE](LICENSE)

## Support

- Issues: [GitHub Issues](https://github.com/DEIN-REPO/logbot/issues)
- Docs: [Wiki](https://github.com/DEIN-REPO/logbot/wiki)
