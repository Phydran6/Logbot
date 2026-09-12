# Komponenten

Was in welchem Repo steckt, womit es gebaut ist und wo man hineinspringt.

← [Übersicht](../README.md) · [Architektur](architektur.md) · [Wegweiser](wegweiser.md)

---

## 🖥️ Logbot-Server

> Der Kern. Nimmt Logs an, macht sie lesbar, zeigt sie und verwaltet sich selbst.

**[github.com/Phydran6/Logbot-Server](https://github.com/Phydran6/Logbot-Server)** ·
[Releases](https://github.com/Phydran6/Logbot-Server/releases) ·
[Issues](https://github.com/Phydran6/Logbot-Server/issues) ·
[Changelog](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/README.md)

| | |
|---|---|
| **Technik** | Docker Compose, FastAPI (Python), Vue 3 + Tailwind, PostgreSQL 17, Caddy 2 |
| **Installation** | ein Befehl: `curl -sSL …/install.sh \| sudo bash` |
| **Betrieb** | alles im Browser — keine Konfigurationsdatei anfassen |
| **Lizenz** | MIT |

### Verzeichnisse

| Verzeichnis | Inhalt | README |
|---|---|---|
| [`backend/`](https://github.com/Phydran6/Logbot-Server/tree/main/backend) | FastAPI: API, Auth, Parser, Patchmanagement, Sicherung, KI, Mail, Terminal | [→](https://github.com/Phydran6/Logbot-Server/blob/main/backend/README.md) |
| [`frontend/`](https://github.com/Phydran6/Logbot-Server/tree/main/frontend) | Vue 3: Oberfläche, Sprachen, Design-System | [→](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/README.md) |
| [`syslog/`](https://github.com/Phydran6/Logbot-Server/tree/main/syslog) | Syslog-Empfänger auf UDP/TCP 514 | [→](https://github.com/Phydran6/Logbot-Server/blob/main/syslog/README.md) |
| [`db/`](https://github.com/Phydran6/Logbot-Server/tree/main/db) | Schema, Migration, PostgreSQL-Upgrade | [→](https://github.com/Phydran6/Logbot-Server/blob/main/db/README.md) |
| [`caddy/`](https://github.com/Phydran6/Logbot-Server/tree/main/caddy) | Reverse Proxy und TLS | [→](https://github.com/Phydran6/Logbot-Server/blob/main/caddy/README.md) |
| [`agents/`](https://github.com/Phydran6/Logbot-Server/tree/main/agents) | Installer für Linux und Windows | [→](https://github.com/Phydran6/Logbot-Server/blob/main/agents/README.md) |
| [`deploy/`](https://github.com/Phydran6/Logbot-Server/tree/main/deploy) | Compose-Varianten: externe DB, gehärtet, Zusatzdienste | [→](https://github.com/Phydran6/Logbot-Server/blob/main/deploy/README.md) |
| [`install/`](https://github.com/Phydran6/Logbot-Server/tree/main/install) | Systemprüfung vor der Installation | [→](https://github.com/Phydran6/Logbot-Server/blob/main/install/README.md) |
| [`n8n/`](https://github.com/Phydran6/Logbot-Server/tree/main/n8n) | mitgelieferte Workflows | [→](https://github.com/Phydran6/Logbot-Server/blob/main/n8n/README.md) |
| [`docs/`](https://github.com/Phydran6/Logbot-Server/tree/main/docs) | die ganze Dokumentation | [→](https://github.com/Phydran6/Logbot-Server/blob/main/docs/README.md) |
| [`CHANGELOG/`](https://github.com/Phydran6/Logbot-Server/tree/main/CHANGELOG) | Änderungen je Bereich | [→](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/README.md) |

### Dokumentation

| Thema | Steht in |
|---|---|
| Voraussetzungen, Systemprüfung, Zusatzdienste, Hardware-Bedarf | [Installation](https://github.com/Phydran6/Logbot-Server/blob/main/docs/install/README.md) |
| Tägliche Handgriffe, Menüführung, Sprache, Systemcheck, Terminal | [Betrieb](https://github.com/Phydran6/Logbot-Server/blob/main/docs/operate/README.md) |
| Patchmanagement, Release-Auswahl, Sofortmeldung | [Updates](https://github.com/Phydran6/Logbot-Server/blob/main/docs/updates/README.md) |
| Sichern, Zurückspielen, Verschlüsselung, Versionsprüfung | [Sicherung](https://github.com/Phydran6/Logbot-Server/blob/main/docs/backup/README.md) |
| Webhooks, n8n, KI, Mail, Portainer, Watchtower | [Integrationen](https://github.com/Phydran6/Logbot-Server/blob/main/docs/integrations/README.md) |
| REST-API, Agent-Ingest, App-Schnittstelle | [API](https://github.com/Phydran6/Logbot-Server/blob/main/docs/api/README.md) |

---

## 📱 Logbot-Android-App

> Die eigene Instanz am Handy: gehärtete WebView auf den eigenen Server, Token
> verschlüsselt auf dem Gerät, Sperre per Biometrie.

**[github.com/Phydran6/Logbot-Android-App](https://github.com/Phydran6/Logbot-Android-App)** ·
[Releases](https://github.com/Phydran6/Logbot-Android-App/releases) ·
[Issues](https://github.com/Phydran6/Logbot-Android-App/issues) ·
[Changelog](https://github.com/Phydran6/Logbot-Android-App/blob/main/CHANGELOG.md) ·
[GitLab-Spiegel](https://gitlab.com/Phydran6/Logbot-Android-App)

| | |
|---|---|
| **Technik** | Kotlin, Android SDK, Gradle (Kotlin DSL), XML-Layouts |
| **Paket** | `de.phytech.logbot` |
| **Android** | ab 7.0 (minSdk 24), gebaut gegen SDK 36 |
| **Bauen** | `./gradlew assembleDebug` bzw. `assembleRelease` |
| **CI** | [build-debug.yml](https://github.com/Phydran6/Logbot-Android-App/blob/main/.github/workflows/build-debug.yml) — APK 30 Tage als Artifact |
| **Spiegelung** | [mirror-to-gitlab.yml](https://github.com/Phydran6/Logbot-Android-App/blob/main/.github/workflows/mirror-to-gitlab.yml) — 1:1 nach GitLab, damit F-Droid die GitLab-Quelle nutzen kann |

### Wichtige Dateien

| Datei | Wofür |
|---|---|
| [`MainActivity.kt`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/src/main/java/de/phytech/logbot/MainActivity.kt) | Vollbild-WebView mit Sicherheits-Hardening, Token als Header und in `localStorage` |
| [`SetupActivity.kt`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/src/main/java/de/phytech/logbot/SetupActivity.kt) | Einrichtung: URL + Token manuell oder per QR-Code, danach verschlüsselt abgelegt |
| [`LogbotBridge.kt`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/src/main/java/de/phytech/logbot/LogbotBridge.kt) | `window.LogbotApp` für die Web-UI: Biometrie-Status, App-Version |
| [`app/build.gradle.kts`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/build.gradle.kts) | Versionen, Signing, Build-Varianten |

### Gut zu wissen

- **App-Lock** per `BiometricPrompt` (`BIOMETRIC_STRONG` + Geräte-PIN als
  Fallback). Bricht die Prüfung ab, wird die App geschlossen, ohne den Token zu
  entschlüsseln.
- **MFA** braucht in der App keine Änderung — der zweistufige Login erscheint im
  WebView von selbst.
- **Kein Certificate Pinning.** Bewusste Entscheidung des Autors; im offenen
  Netz sollte man das Risiko kennen. Einzelheiten im
  [README der App](https://github.com/Phydran6/Logbot-Android-App#-sicherheitshinweis--certificate-pinning).

---

## 🔀 Logbot-n8n-flow

> Telegram fragt, Claude antwortet — anhand der Logs aus LogBot.

**[github.com/Phydran6/Logbot-n8n-flow](https://github.com/Phydran6/Logbot-n8n-flow)** ·
[Issues](https://github.com/Phydran6/Logbot-n8n-flow/issues) ·
[`Logbot.json`](https://github.com/Phydran6/Logbot-n8n-flow/blob/main/Logbot.json)

| | |
|---|---|
| **Technik** | n8n (self-hosted oder Cloud), Anthropic API, Telegram Bot |
| **Braucht** | n8n-Instanz, Telegram-Bot-Token, Anthropic-API-Key, LogBot-Endpoint mit Token |
| **Import** | n8n → *Workflows → Import from File* → `Logbot.json` |

### Ablauf

1. **Telegram-Trigger** — eingehende Nachricht startet den Ablauf
2. **HTTP Request** — Logs vom LogBot-Endpoint holen
3. **If** — sind überhaupt Logs da? Wenn nein: „Keine Logs da."
4. **AI Agent (Claude)** — analysiert und fasst zusammen
5. **Code** — Chat-ID heraustrennen, Ausgabe säubern
6. **Telegram** — Analyse zurück in den Chat

### Platzhalter beim Import

| Platzhalter | Ersetzen durch |
|---|---|
| `YOUR_CREDENTIAL_ID` / `YOUR_CREDENTIAL_NAME` | setzt n8n beim Import selbst |
| `YOUR_LOGBOT_URL` | eigene LogBot-Domain, z. B. `logbot.example.de` |
| `YOUR_TOKEN` | eigener LogBot-API-Token |

> **Hinweis:** Derselbe Ablauf liegt zusätzlich im Server-Repo unter
> [`n8n/`](https://github.com/Phydran6/Logbot-Server/tree/main/n8n) — dort
> zusammen mit einem Grundgerüst-Workflow. Dieses Repo hier ist die
> eigenständige Fassung zum Einzelimport.

---

## 🧭 Logbot *(diese Repo)*

> Die Landkarte. Kein Code, keine Releases, keine Tags — nur Übersicht.

**[github.com/Phydran6/Logbot](https://github.com/Phydran6/Logbot)**

| Datei | Inhalt |
|---|---|
| [`README.md`](../README.md) | Einstieg: was LogBot ist, die Bausteine, Schnellstart |
| [`docs/architektur.md`](architektur.md) | Zusammenspiel, Datenwege, Token, Dienste und Häfen |
| [`docs/komponenten.md`](komponenten.md) | diese Seite |
| [`docs/wegweiser.md`](wegweiser.md) | jeder wichtige Link an einer Stelle |
| [`docs/entwickeln.md`](entwickeln.md) | Versionsschema, Changelog-Regeln, Branches, CI |
| [`docs/assets/`](assets/README.md) | Zeichen und Bilder |

---

## Weiter

- [Architektur](architektur.md)
- [Wegweiser — alle Links](wegweiser.md)
- [Entwickeln](entwickeln.md)
