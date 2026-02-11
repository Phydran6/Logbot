# Logbot – n8n Workflow

Ein n8n-Workflow, der per Telegram-Nachricht Logs von einem Logbot-Endpoint abruft, sie mit Claude (Anthropic AI) analysiert und die Auswertung zurück an Telegram sendet.

## Ablauf

1. **Telegram Trigger** – Eingehende Nachricht startet den Workflow
2. **HTTP Request** – Logs werden vom Logbot-API-Endpoint abgerufen
3. **If-Node** – Prüft, ob Logs vorhanden sind
   - **Ja** → Logs werden aufbereitet und an den AI Agent übergeben
   - **Nein** → Telegram-Nachricht: „Keine Logs da."
4. **AI Agent (Claude)** – Analysiert die Logs und erstellt eine lesbare Zusammenfassung
5. **Code-Node** – Extrahiert Chat-ID und bereinigt den Output
6. **Telegram** – Sendet die Analyse zurück an den Chat

## Setup

### Voraussetzungen

- n8n-Instanz (self-hosted oder Cloud)
- Telegram Bot Token
- Anthropic API Key
- Logbot-Endpoint mit API-Token

### Installation

1. `Logbot.json` in n8n importieren (**Workflows → Import from File**)
2. Credentials anlegen und zuweisen:
   - **Telegram API** – Bot Token eintragen
   - **Anthropic API** – API Key eintragen
3. Im Node **„Logs werden vom Logbot geholt"** die URL + Token auf deinen Endpoint anpassen
4. Workflow aktivieren

## Platzhalter

| Platzhalter | Ersetzen durch |
|---|---|
| `YOUR_CREDENTIAL_ID` | Wird automatisch von n8n beim Import gesetzt |
| `YOUR_CREDENTIAL_NAME` | Wird automatisch von n8n beim Import gesetzt |
| `YOUR_LOGBOT_URL` | Deine Logbot-Domain (z.B. `logbot.example.de`) |
| `YOUR_TOKEN` | Dein Logbot-API-Token |

## Lizenz

MIT
