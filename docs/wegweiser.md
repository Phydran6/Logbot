# Wegweiser

Jeder Link, den man beim Arbeiten an LogBot braucht — an einer Stelle.
Von hier aus kommt man in jede Ecke des Projekts, ohne zu suchen.

← [Übersicht](../README.md) · [Architektur](architektur.md) · [Komponenten](komponenten.md)

---

## Die vier Repos

| Repo | Code | Issues | Commits | Actions | Releases |
|---|---|---|---|---|---|
| **Logbot-Server** | [→](https://github.com/Phydran6/Logbot-Server) | [→](https://github.com/Phydran6/Logbot-Server/issues) | [→](https://github.com/Phydran6/Logbot-Server/commits/main) | [→](https://github.com/Phydran6/Logbot-Server/actions) | [→](https://github.com/Phydran6/Logbot-Server/releases) |
| **Logbot-Android-App** | [→](https://github.com/Phydran6/Logbot-Android-App) | [→](https://github.com/Phydran6/Logbot-Android-App/issues) | [→](https://github.com/Phydran6/Logbot-Android-App/commits/main) | [→](https://github.com/Phydran6/Logbot-Android-App/actions) | [→](https://github.com/Phydran6/Logbot-Android-App/releases) |
| **Logbot-n8n-flow** | [→](https://github.com/Phydran6/Logbot-n8n-flow) | [→](https://github.com/Phydran6/Logbot-n8n-flow/issues) | [→](https://github.com/Phydran6/Logbot-n8n-flow/commits/main) | — | — |
| **Logbot** *(hier)* | [→](https://github.com/Phydran6/Logbot) | [→](https://github.com/Phydran6/Logbot/issues) | [→](https://github.com/Phydran6/Logbot/commits/main) | — | keine |

Weiteres: [GitLab-Spiegel der App](https://gitlab.com/Phydran6/Logbot-Android-App) ·
[alle Repos von Phydran6](https://github.com/Phydran6?tab=repositories)

---

## Dokumentation

### Diese Übersicht

- [Übersicht](../README.md) — was LogBot ist, die Bausteine, Schnellstart
- [Architektur](architektur.md) — Zusammenspiel, Datenwege, Token, Dienste und Häfen
- [Komponenten](komponenten.md) — je Repo: Technik, Verzeichnisse, wichtige Dateien
- [Entwickeln](entwickeln.md) — Versionsschema, Changelog, Branches, Release-Ablauf
- [Bilder und Zeichen](assets/README.md)

### Server-Dokumentation

| Thema | Link |
|---|---|
| Alle Dokumente | [docs/README.md](https://github.com/Phydran6/Logbot-Server/blob/main/docs/README.md) |
| Installation | [docs/install](https://github.com/Phydran6/Logbot-Server/blob/main/docs/install/README.md) |
| ⤷ Systemprüfung | [#systemprüfung](https://github.com/Phydran6/Logbot-Server/blob/main/docs/install/README.md#systemprüfung) |
| ⤷ Zusatzdienste | [#zusatzdienste](https://github.com/Phydran6/Logbot-Server/blob/main/docs/install/README.md#zusatzdienste) |
| Betrieb | [docs/operate](https://github.com/Phydran6/Logbot-Server/blob/main/docs/operate/README.md) |
| ⤷ Sprache | [#sprache](https://github.com/Phydran6/Logbot-Server/blob/main/docs/operate/README.md#sprache) |
| ⤷ Terminal im Browser | [#terminal-im-browser](https://github.com/Phydran6/Logbot-Server/blob/main/docs/operate/README.md#terminal-im-browser) |
| Updates | [docs/updates](https://github.com/Phydran6/Logbot-Server/blob/main/docs/updates/README.md) |
| Sicherung | [docs/backup](https://github.com/Phydran6/Logbot-Server/blob/main/docs/backup/README.md) |
| Integrationen | [docs/integrations](https://github.com/Phydran6/Logbot-Server/blob/main/docs/integrations/README.md) |
| ⤷ KI-Auswertung | [#ki-auswertung](https://github.com/Phydran6/Logbot-Server/blob/main/docs/integrations/README.md#ki-auswertung) |
| ⤷ Mail (Postfix) | [#mail-postfix](https://github.com/Phydran6/Logbot-Server/blob/main/docs/integrations/README.md#mail-postfix) |
| API | [docs/api](https://github.com/Phydran6/Logbot-Server/blob/main/docs/api/README.md) |
| ⤷ Schnittstelle für die App | [#schnittstelle-für-die-app](https://github.com/Phydran6/Logbot-Server/blob/main/docs/api/README.md#schnittstelle-für-die-app) |
| Agents anbinden | [agents/README.md](https://github.com/Phydran6/Logbot-Server/blob/main/agents/README.md) |
| Datenbank / Migration | [db/README.md](https://github.com/Phydran6/Logbot-Server/blob/main/db/README.md) |

### Changelogs

| | |
|---|---|
| Release-Verlauf (Gesamtprojekt) | [CHANGELOG/releases.md](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/releases.md) |
| Übersicht je Bereich | [CHANGELOG/README.md](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/README.md) |
| Backend · Frontend · Syslog | [backend](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/backend.md) · [frontend](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/frontend.md) · [syslog](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/syslog.md) |
| Agents · Datenbank/Deployment | [agents](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/agents.md) · [database](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/database.md) |
| Android-App | [CHANGELOG.md](https://github.com/Phydran6/Logbot-Android-App/blob/main/CHANGELOG.md) |

---

## In den Code springen

### Server — Kern

| Was | Datei |
|---|---|
| Compose-Stack | [`docker-compose.yml`](https://github.com/Phydran6/Logbot-Server/blob/main/docker-compose.yml) |
| Installer | [`install.sh`](https://github.com/Phydran6/Logbot-Server/blob/main/install.sh) · [`install/preflight.sh`](https://github.com/Phydran6/Logbot-Server/blob/main/install/preflight.sh) |
| Versionsstand | [`VERSION`](https://github.com/Phydran6/Logbot-Server/blob/main/VERSION) |
| Beispiel-Umgebung | [`.env.example`](https://github.com/Phydran6/Logbot-Server/blob/main/.env.example) |
| Reverse Proxy | [`caddy/Caddyfile`](https://github.com/Phydran6/Logbot-Server/blob/main/caddy/Caddyfile) |
| Syslog-Empfänger | [`syslog/syslog_server.py`](https://github.com/Phydran6/Logbot-Server/blob/main/syslog/syslog_server.py) |
| Schema | [`db/init.sql`](https://github.com/Phydran6/Logbot-Server/blob/main/db/init.sql) · [`db/migrate.sh`](https://github.com/Phydran6/Logbot-Server/blob/main/db/migrate.sh) |
| Update-Skript | [`backend/scripts/logbot-update.sh`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/scripts/logbot-update.sh) |

### Server — Backend (FastAPI)

| Was | Datei |
|---|---|
| Einstiegspunkt | [`app/main.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/main.py) |
| Datenmodelle · Datenbank · Konfiguration | [`models.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/models.py) · [`database.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/database.py) · [`config.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/config.py) |
| Parser | [`logparse.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/logparse.py) |
| Auth · Schutz · Rate Limit | [`auth.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/auth.py) · [`guard.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/guard.py) · [`limiter.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/limiter.py) |
| KI · Mail · LDAP | [`ai.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/ai.py) · [`mail.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/mail.py) · [`ldap_auth.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/ldap_auth.py) |
| Sicherung · Archivierung · Diagnose | [`backup.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/backup.py) · [`archiving.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/archiving.py) · [`diagnostics.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/diagnostics.py) |
| Ereignisstrom · Host-Ausführung · FRITZ!Box | [`events.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/events.py) · [`hostexec.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/hostexec.py) · [`fritzbox.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/fritzbox.py) |
| **Routen** | [`app/routes/`](https://github.com/Phydran6/Logbot-Server/tree/main/backend/app/routes) |
| ⤷ Agent-Ingest | [`routes/agents.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/agents.py) |
| ⤷ App-Schnittstelle | [`routes/mobile.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/mobile.py) |
| ⤷ Logs · Anmeldung · MFA · Passkey | [`logs.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/logs.py) · [`auth.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/auth.py) · [`mfa.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/mfa.py) · [`passkey.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/passkey.py) |
| ⤷ Updates · Stacks · Netzwerk · Shell | [`updates.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/updates.py) · [`stacks.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/stacks.py) · [`network.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/network.py) · [`shell.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/shell.py) |
| ⤷ Webhooks · Benutzer · Gesundheit | [`webhooks.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/webhooks.py) · [`users.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/users.py) · [`health.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/routes/health.py) |

### Server — Frontend (Vue 3)

| Was | Datei |
|---|---|
| Einstieg · Wurzel · Router | [`main.js`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/main.js) · [`App.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/App.vue) · [`router/index.js`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/router/index.js) |
| Ansichten | [`src/views/`](https://github.com/Phydran6/Logbot-Server/tree/main/frontend/src/views) |
| ⤷ Dashboard · Logs · Geräte-Logs | [`Dashboard.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/Dashboard.vue) · [`Logs.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/Logs.vue) · [`DeviceLogs.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/DeviceLogs.vue) |
| ⤷ Einstellungen · Sicherheit · Branding | [`Settings.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/Settings.vue) · [`SecuritySettings.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/SecuritySettings.vue) · [`BrandingSettings.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/BrandingSettings.vue) |
| ⤷ KI · Mail · LDAP · Archivierung | [`AiSettings.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/AiSettings.vue) · [`MailSettings.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/MailSettings.vue) · [`LdapSettings.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/LdapSettings.vue) · [`ArchivingSettings.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/ArchivingSettings.vue) |
| ⤷ Agents · Tokens · QR für die App | [`Agents.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/Agents.vue) · [`AgentTokens.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/AgentTokens.vue) · [`AppQR.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/AppQR.vue) |
| ⤷ Updates · Sicherung · Stacks · Terminal · Health | [`Updates.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/Updates.vue) · [`Backup.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/Backup.vue) · [`Stacks.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/Stacks.vue) · [`Terminal.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/Terminal.vue) · [`Health.vue`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/views/Health.vue) |
| Bausteine · Stores · Design | [`components/`](https://github.com/Phydran6/Logbot-Server/tree/main/frontend/src/components) · [`stores/`](https://github.com/Phydran6/Logbot-Server/tree/main/frontend/src/stores) · [`assets/css/main.css`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/src/assets/css/main.css) |

### Agents

| Was | Datei |
|---|---|
| Linux | [`agents/install-linux.sh`](https://github.com/Phydran6/Logbot-Server/blob/main/agents/install-linux.sh) |
| Windows (PowerShell / Batch) | [`install-windows.ps1`](https://github.com/Phydran6/Logbot-Server/blob/main/agents/install-windows.ps1) · [`install-windows.bat`](https://github.com/Phydran6/Logbot-Server/blob/main/agents/install-windows.bat) |

### App

| Was | Datei |
|---|---|
| WebView-Activity | [`MainActivity.kt`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/src/main/java/de/phytech/logbot/MainActivity.kt) |
| Einrichtung / QR | [`SetupActivity.kt`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/src/main/java/de/phytech/logbot/SetupActivity.kt) |
| JS-Brücke | [`LogbotBridge.kt`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/src/main/java/de/phytech/logbot/LogbotBridge.kt) |
| Manifest · Build · Abhängigkeiten | [`AndroidManifest.xml`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/src/main/AndroidManifest.xml) · [`app/build.gradle.kts`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/build.gradle.kts) · [`gradle/libs.versions.toml`](https://github.com/Phydran6/Logbot-Android-App/blob/main/gradle/libs.versions.toml) |
| Oberflächen | [`activity_main.xml`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/src/main/res/layout/activity_main.xml) · [`activity_setup.xml`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/src/main/res/layout/activity_setup.xml) |
| Workflows | [`build-debug.yml`](https://github.com/Phydran6/Logbot-Android-App/blob/main/.github/workflows/build-debug.yml) · [`mirror-to-gitlab.yml`](https://github.com/Phydran6/Logbot-Android-App/blob/main/.github/workflows/mirror-to-gitlab.yml) |

### Workflows (n8n)

| Was | Datei |
|---|---|
| Eigenständiger Telegram-Claude-Ablauf | [`Logbot.json`](https://github.com/Phydran6/Logbot-n8n-flow/blob/main/Logbot.json) |
| Mitgeliefert im Server-Repo | [`n8n/logbot.json`](https://github.com/Phydran6/Logbot-Server/blob/main/n8n/logbot.json) · [`n8n/telegram-chat-flow.json`](https://github.com/Phydran6/Logbot-Server/blob/main/n8n/telegram-chat-flow.json) |

---

## Am laufenden Server

Bei eigener Instanz `SERVER-IP` bzw. die eigene Domain einsetzen:

| Ziel | Adresse |
|---|---|
| Oberfläche | `http://SERVER-IP/` |
| API-Doku (OpenAPI/Swagger) | `http://SERVER-IP/api/docs` |
| Gesundheitsprüfung | `http://SERVER-IP/api/health` |
| Ereignisstrom | `http://SERVER-IP/api/events?token=…` |
| Syslog | `SERVER-IP:514` (UDP/TCP) |
| n8n als Container | `http://127.0.0.1:5678` · intern `http://logbot-n8n:5678/webhook/logbot` |

Befehle zum Kopieren:

```bash
# Installation
curl -sSL https://raw.githubusercontent.com/Phydran6/Logbot-Server/main/install.sh | sudo bash

# Installation ohne Rückfragen, mit Zusatzdiensten
curl -sSL https://raw.githubusercontent.com/Phydran6/Logbot-Server/main/install.sh \
  | sudo bash -s -- --with portainer,watchtower --yes

# Systemprüfung vorab
sudo bash install/preflight.sh portainer n8n

# App bauen
git clone https://github.com/Phydran6/Logbot-Android-App && cd Logbot-Android-App
./gradlew assembleDebug
```

---

## Issues und Diskussionen

Ein Fehler gehört dorthin, wo der Code liegt:

| Es geht um … | Issue anlegen bei |
|---|---|
| Oberfläche, API, Installer, Agents, Syslog, Datenbank, Updates, Sicherung | [Logbot-Server](https://github.com/Phydran6/Logbot-Server/issues/new) |
| Android-App: Einrichtung, WebView, App-Lock, Build | [Logbot-Android-App](https://github.com/Phydran6/Logbot-Android-App/issues/new) |
| n8n-Ablauf: Import, Telegram, Claude-Analyse | [Logbot-n8n-flow](https://github.com/Phydran6/Logbot-n8n-flow/issues/new) |
| diese Übersicht: falsche Links, fehlende Erklärung | [Logbot](https://github.com/Phydran6/Logbot/issues/new) |

Offene Punkte über alle Repos hinweg:
[alle offenen Issues](https://github.com/search?q=user%3APhydran6+repo%3APhydran6%2FLogbot-Server+repo%3APhydran6%2FLogbot-Android-App+repo%3APhydran6%2FLogbot-n8n-flow+repo%3APhydran6%2FLogbot+is%3Aissue+is%3Aopen&type=issues) ·
[alle offenen Pull Requests](https://github.com/search?q=repo%3APhydran6%2FLogbot-Server+repo%3APhydran6%2FLogbot-Android-App+repo%3APhydran6%2FLogbot-n8n-flow+repo%3APhydran6%2FLogbot+is%3Apr+is%3Aopen&type=pullrequests)

---

## Suchen statt klicken

| Suche | Link |
|---|---|
| im Server-Code | [github.com/Phydran6/Logbot-Server/search](https://github.com/search?q=repo%3APhydran6%2FLogbot-Server+&type=code) |
| im App-Code | [github.com/Phydran6/Logbot-Android-App/search](https://github.com/search?q=repo%3APhydran6%2FLogbot-Android-App+&type=code) |
| über alle Logbot-Repos | [Codesuche](https://github.com/search?q=repo%3APhydran6%2FLogbot-Server+repo%3APhydran6%2FLogbot-Android-App+repo%3APhydran6%2FLogbot-n8n-flow+repo%3APhydran6%2FLogbot+&type=code) |

Nützliche Adress-Muster im Browser:

| Zweck | Muster |
|---|---|
| Datei mit Zeilenmarke | `…/blob/main/PFAD#L42-L60` |
| Zwei Stände vergleichen | `…/compare/v2026.09.01…v2026.09.10` |
| Datei-Historie | `…/commits/main/PFAD` |
| Rohdatei | `https://raw.githubusercontent.com/Phydran6/REPO/main/PFAD` |

---

## Weiter

- [Architektur](architektur.md)
- [Komponenten](komponenten.md)
- [Entwickeln](entwickeln.md)
