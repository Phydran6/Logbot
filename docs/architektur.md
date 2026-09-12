# Architektur

Wie die Teile zusammenspielen — von der Logzeile auf dem Switch bis zur Antwort
im Telegram-Chat.

← [Übersicht](../README.md) · [Komponenten](komponenten.md) · [Wegweiser](wegweiser.md)

---

## Das Gesamtbild

```mermaid
flowchart TB
    subgraph Q["Quellen"]
        direction LR
        Q1["Linux-Agent<br/>install-linux.sh"]
        Q2["Windows-Agent<br/>install-windows.ps1"]
        Q3["Netzwerkgeräte<br/>UniFi, Cisco, Fortinet, FRITZ!Box"]
        Q4["Sammler<br/>n8n im Namen anderer Geräte"]
    end

    subgraph S["Logbot-Server — ein Docker-Stack"]
        direction TB
        SY["syslog<br/>UDP/TCP 514"]
        BE["backend — FastAPI<br/>Parser, Auth, API, Patchmanagement,<br/>Sicherung, KI, Mail, Terminal"]
        DB[("postgres<br/>Logs, Benutzer, Geräte,<br/>Einstellungen")]
        FE["frontend — Vue 3<br/>Oberfläche, Sprachen, Design"]
        CA["caddy<br/>Reverse Proxy, TLS, 80/443"]
    end

    subgraph V["Verbraucher"]
        direction LR
        V1["Browser"]
        V2["Android-App"]
        V3["n8n-Flows"]
        V4["KI: Claude / ChatGPT"]
        V5["Webhooks, Mail"]
    end

    Q1 & Q2 -->|"HTTPS + Agent-Token<br/>POST /api/agents/ingest"| CA
    Q3 -->|"Syslog"| SY
    Q4 -->|"HTTPS im Namen<br/>fremder Geräte"| CA
    SY --> DB
    CA --> BE
    CA --> FE
    BE --> DB
    FE -->|"REST + EventSource"| CA
    CA --> V1
    CA --> V2
    BE -->|"API /api/app"| V2
    BE <-->|"Webhook"| V3
    BE -->|"optional, nie voreingestellt"| V4
    BE --> V5
    V3 --> V4
```

---

## Datenwege

Es gibt genau drei Wege, auf denen eine Logzeile in LogBot landet:

| Weg | Wer | Wie | Wohin |
|---|---|---|---|
| **Syslog** | Switches, APs, Firewalls, alles mit Syslog | UDP/TCP 514, RFC 5424 und 3164 | Dienst `syslog` → PostgreSQL |
| **Agent** | Linux- und Windows-Rechner, auch aus fremden Netzen | HTTPS, `Authorization: Bearer <AGENT-TOKEN>`, `POST /api/agents/ingest` | Backend → PostgreSQL |
| **Sammler** | n8n und Ähnliches, das für Geräte ohne eigenen Agent liefert (z. B. FRITZ!Box) | wie der Agent, nur mit fremdem `hostname`/`device_type` | Backend → PostgreSQL |

Und drei Wege wieder heraus:

| Weg | Wofür |
|---|---|
| **Browser** | Oberfläche, Filter in der Adresse, Export als CSV/JSON |
| **App** (`/api/app/*`) | schlanker Zweig für das Handy: `bootstrap`, `logs`, `logs/tail`, `summary`, `devices` |
| **Webhook / KI** | Auswertung durch Claude, ChatGPT oder einen n8n-Ablauf |

---

## Anmeldung und Token

Drei Sorten Zugang, die man nicht verwechseln sollte:

```mermaid
flowchart LR
    U["Benutzer"] -->|"Passwort<br/>(+ MFA/Passkey)"| T1["Session-Token<br/>Bearer, kurzlebig"]
    U -->|"aus angemeldeter<br/>Web-Session"| T2["App-Token<br/>QR-Code ans Handy"]
    A["Rechner / Sammler"] -->|"bei Einrichtung<br/>vergeben"| T3["Agent-Token<br/>nur Ingest"]

    T1 --> API["API"]
    T2 --> API
    T3 --> ING["POST /api/agents/ingest"]
```

- **Session-Token** — aus `POST /api/auth/login`. Bei aktivem MFA in zwei
  Schritten über `POST /api/auth/login/mfa`.
- **App-Token** — entsteht nur aus einer bereits angemeldeten Web-Session und
  geht als QR-Code (`{"url": "...", "token": "..."}`) ans Handy. Die App legt
  ihn verschlüsselt ab (`EncryptedSharedPreferences`).
- **Agent-Token** — darf ausschließlich Logs abliefern.

Zwei Ausnahmen von der Kopfzeile: Ereignisstrom (`EventSource`) und Terminal
(`WebSocket`) tragen den Token als `?token=` — geprüft wird er genauso streng.

→ Einzelheiten: [API-Doku im Server-Repo](https://github.com/Phydran6/Logbot-Server/blob/main/docs/api/README.md)

---

## Der Weg einer Anfrage aus der App

```mermaid
sequenceDiagram
    participant App as Android-App
    participant Caddy as Caddy (443)
    participant API as Backend (FastAPI)
    participant DB as PostgreSQL

    App->>Caddy: GET /api/app/bootstrap (Bearer App-Token)
    Caddy->>API: weiterreichen
    API->>DB: Server, Benutzer, Farben, Filterwerte
    DB-->>API: Datensatz
    API-->>App: alles für den Start in einem Aufruf<br/>inkl. api_level + capabilities
    App->>Caddy: GET /api/app/logs?before_id=…
    Caddy->>API: weiterreichen
    API->>DB: Seite Logzeilen
    DB-->>API: Zeilen
    API-->>App: Liste (per Cursor blätterbar)
    loop während die App offen ist
        App->>API: GET /api/app/logs/tail?since_id=…
        API-->>App: nur das Neue
    end
```

`bootstrap` meldet `api_level` und `capabilities` — daran erkennt eine ältere
App, was der Server schon kann.

---

## Der Weg einer KI-Auswertung

```mermaid
sequenceDiagram
    participant TG as Telegram
    participant N8N as n8n-Workflow
    participant LB as LogBot-API
    participant AI as Claude (Anthropic)

    TG->>N8N: Nachricht an den Bot
    N8N->>LB: Logs holen (Token)
    LB-->>N8N: Logzeilen oder leer
    alt keine Logs
        N8N-->>TG: "Keine Logs da."
    else Logs vorhanden
        N8N->>AI: Logs + Frage
        AI-->>N8N: Zusammenfassung
        N8N-->>TG: Analyse in den Chat
    end
```

Der Ablauf liegt zweimal: eigenständig in
[Logbot-n8n-flow](https://github.com/Phydran6/Logbot-n8n-flow) und mitgeliefert
unter [`Logbot-Server/n8n/`](https://github.com/Phydran6/Logbot-Server/tree/main/n8n).

Läuft n8n als Container neben LogBot, lautet die interne Adresse
`http://logbot-n8n:5678/webhook/logbot` — dann bleiben die Daten im Docker-Netz,
solange der Workflow sie nicht weitergibt.

---

## Dienste und Häfen

| Dienst | Image / Bau | Port | Bemerkung |
|---|---|---|---|
| `caddy` | `caddy:2-alpine` | **80**, **443** | einziger Weg von außen; TLS und DNS im Browser einstellbar |
| `syslog` | eigenes Dockerfile | **514/udp**, **514/tcp** | nimmt Rohzeilen an |
| `backend` | FastAPI | 8000 *(intern)* | API, Auth, Parser, Verwaltung |
| `frontend` | Vue 3 hinter nginx | 80 *(intern)* | ausgelieferte Oberfläche |
| `postgres` | `postgres:17-alpine` | 5432, gebunden an `127.0.0.1` | über `DB_BIND` steuerbar |

Zuschaltbar, nie voreingestellt: **Portainer**, **Watchtower**, **n8n**, **Postfix**.

Compose-Varianten liegen unter
[`deploy/`](https://github.com/Phydran6/Logbot-Server/tree/main/deploy):
externe Datenbank, gehärteter Betrieb, Zusatzdienste.

---

## Voraussetzungen

- Linux (Ubuntu 20.04+ oder vergleichbar), x86_64 oder ARM64
- Docker mit Compose-Plugin *(installiert der Installer bei Bedarf selbst)*
- Root-Zugriff
- 1 GB RAM und 4 GB Platte für LogBot allein — mehr je nach Zusatzdiensten
- Für die App: Android 7.0 (API 24) oder neuer

Ob die Maschine reicht, sagt die Systemprüfung:

```bash
sudo bash install/preflight.sh                 # nur LogBot
sudo bash install/preflight.sh portainer n8n   # mit Zusatzdiensten
```

---

## Weiter

- [Komponenten im Detail](komponenten.md)
- [Wegweiser — alle Links](wegweiser.md)
- [Entwickeln](entwickeln.md)
