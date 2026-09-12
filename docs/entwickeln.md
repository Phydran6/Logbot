# Entwickeln

Regeln und Handgriffe, die in allen Logbot-Repos gleich gelten — und was je
Repo eigen ist.

← [Übersicht](../README.md) · [Komponenten](komponenten.md) · [Wegweiser](wegweiser.md)

---

## Wo arbeite ich?

Diese Repo enthält **keinen Code**. Änderungen am Programm gehören immer in das
Repo, in dem der betroffene Teil liegt:

| Ich ändere … | Repo |
|---|---|
| API, Oberfläche, Parser, Installer, Agents, Syslog, Datenbank, Compose | [Logbot-Server](https://github.com/Phydran6/Logbot-Server) |
| App: Einrichtung, WebView, App-Lock, Build, Icon | [Logbot-Android-App](https://github.com/Phydran6/Logbot-Android-App) |
| n8n-Ablauf: Nodes, Prompt, Telegram-Anbindung | [Logbot-n8n-flow](https://github.com/Phydran6/Logbot-n8n-flow) |
| Übersicht, Architekturbild, Links, Erklärungen | **Logbot** *(hier)* |

---

## Versionsschema

Alle Repos verwenden datumsbasierte Versionen:

```
JAHR.MONAT.TAG.STUNDE.MINUTE.SEKUNDE      z. B. 2026.09.09.22.00.00
```

Kein SemVer — der Zeitstempel ist die Version. Er steht im Datei-Kopf des
geänderten Bausteins und wandert von dort in die Changelogs.

### Server: die Version steht an fünf Stellen

Bei jedem Release überall mitziehen:

| Ort | Bedeutung |
|---|---|
| [`VERSION`](https://github.com/Phydran6/Logbot-Server/blob/main/VERSION) | Maßstab für die Update-Prüfung — wird gegen GitHub verglichen |
| [`backend/app/config.py`](https://github.com/Phydran6/Logbot-Server/blob/main/backend/app/config.py) → `app_version` | Version in API und Sicherungen |
| [`frontend/package.json`](https://github.com/Phydran6/Logbot-Server/blob/main/frontend/package.json) | Version im Seitenmenü |
| [`install.sh`](https://github.com/Phydran6/Logbot-Server/blob/main/install.sh) → `LOGBOT_VERSION` | Version in der Installer-Ausgabe |
| [`CHANGELOG/releases.md`](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/releases.md) | der Eintrag zum Release |

Die Haupt-READMEs tragen bewusst **keine** Version: sie beschreiben, was LogBot
*ist* und *kann* — nicht, welcher Stand gerade läuft.

### App

`versionCode` hochzählen und `versionName` auf den Zeitstempel setzen — beides in
[`app/build.gradle.kts`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/build.gradle.kts),
dazu der Eintrag in
[`CHANGELOG.md`](https://github.com/Phydran6/Logbot-Android-App/blob/main/CHANGELOG.md).

---

## Changelog-Regeln

Im Server-Repo wird **pro Bereich** dokumentiert
([Übersicht](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/README.md)),
in der App in einer Datei nach
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

- Neueste Version steht oben.
- Kategorien: **Neu**, **Geändert**, **Behoben**, **Entfernt**, **Sicherheit**.
- Ein Änderungsblock pro Version; die Version entspricht dem `Version:`-Stempel
  im Datei-Kopf des Bereichs.
- Nur den Bereich versionieren, der tatsächlich geändert wurde.
- Ein Eintrag sagt, **was** sich geändert hat und **warum** — nicht, welche Zeile
  angefasst wurde. Bei Fehlerbehebungen gehört die Ursache dazu.

---

## Datei-Köpfe

Quelldateien tragen einen Kopf mit Datei, Projekt, Autor, Version und
Beschreibung — Vorbild ist
[`MainActivity.kt`](https://github.com/Phydran6/Logbot-Android-App/blob/main/app/src/main/java/de/phytech/logbot/MainActivity.kt):

```kotlin
/**
 * Datei:        MainActivity.kt
 * Projekt:      Logbot
 * Paket:        de.phytech.logbot
 * Autor:        Phydran6
 * Version:      2.0 – 17.04.2026 (16:31)
 *
 * Beschreibung: …
 */
```

Wer eine Datei anfasst, zieht den Versionsstand im Kopf mit.

---

## Branches und Pull Requests

- Gearbeitet wird auf Zweigen, nicht direkt auf `main`.
- Größere Änderungen vorher als Issue besprechen.
- Pull Requests sind willkommen — auch für Dinge, die der Autor selbst nicht
  vorhat (etwa Certificate Pinning in der App).
- Ein PR bringt mit: Changelog-Eintrag, mitgezogene Version, angepasste
  Dokumentation.

---

## Bauen und prüfen

```bash
# Server: Stack lokal starten
git clone https://github.com/Phydran6/Logbot-Server && cd Logbot-Server
cp .env.example .env
docker compose up -d
docker compose logs -f backend

# Server: Systemprüfung
sudo bash install/preflight.sh

# App: Debug-Build
git clone https://github.com/Phydran6/Logbot-Android-App && cd Logbot-Android-App
./gradlew assembleDebug
```

Die App baut zusätzlich in der CI:
[`build-debug.yml`](https://github.com/Phydran6/Logbot-Android-App/blob/main/.github/workflows/build-debug.yml)
legt die APK 30 Tage als Artifact ab — praktisch zum Testen ohne Android Studio.

Jeder Push auf `main` und jedes `v*`-Tag spiegelt das App-Repo außerdem
1:1 nach [GitLab](https://gitlab.com/Phydran6/Logbot-Android-App), damit F-Droid
die GitLab-Quelle nutzen kann
([`mirror-to-gitlab.yml`](https://github.com/Phydran6/Logbot-Android-App/blob/main/.github/workflows/mirror-to-gitlab.yml)).

---

## Releases

| Repo | Releases |
|---|---|
| Logbot-Server | ja — [Releases](https://github.com/Phydran6/Logbot-Server/releases), Verlauf in [`CHANGELOG/releases.md`](https://github.com/Phydran6/Logbot-Server/blob/main/CHANGELOG/releases.md) |
| Logbot-Android-App | ja — [Releases](https://github.com/Phydran6/Logbot-Android-App/releases), Tags `v*` lösen die GitLab-Spiegelung aus |
| Logbot-n8n-flow | keine — der Ablauf ist eine Datei, die man importiert |
| Logbot *(hier)* | **keine.** Diese Repo trägt keine Releases und keine Tags: sie beschreibt nur und würde sonst eine Version vorgeben, die es nicht gibt |

Der Server prüft selbst gegen GitHub, ob ein neuerer Stand vorliegt, und meldet
sich im Web-UI — Einzelheiten unter
[Updates](https://github.com/Phydran6/Logbot-Server/blob/main/docs/updates/README.md).

---

## Dokumentation pflegen

Diese Repo ist die Eingangstür. Wenn sich im Code etwas ändert, das die
Landkarte betrifft, gehört es hierher:

| Geändert | Nachziehen in |
|---|---|
| neues Verzeichnis oder Repo | [Komponenten](komponenten.md), [Wegweiser](wegweiser.md), Diagramm in der [Übersicht](../README.md) |
| neuer Dienst, neuer Port, neuer Datenweg | [Architektur](architektur.md) |
| Datei verschoben oder umbenannt | [Wegweiser](wegweiser.md) |
| neue Regel fürs Entwickeln | diese Seite |

Links gehen bewusst auf `main` — nicht auf Commits. So zeigen sie immer auf den
aktuellen Stand.

---

## Weiter

- [Architektur](architektur.md)
- [Komponenten](komponenten.md)
- [Wegweiser — alle Links](wegweiser.md)
