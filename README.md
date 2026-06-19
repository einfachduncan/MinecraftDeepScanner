# MinecraftDeepScanner

`MinecraftDeepScanner.ps1` ist ein sicheres, read-only PowerShell-Skript fuer Windows. Es durchsucht einen Minecraft-Hauptordner komplett rekursiv, also nicht nur `mods`, sondern auch `config`, `versions`, `libraries`, `shaderpacks`, `resourcepacks`, `logs`, `crash-reports`, Profil-Downloads und unbekannte Unterordner.

## Sicherheit

- liest nur Dateien und Metadaten
- loescht nichts
- verschiebt nichts
- veraendert nichts
- sendet keine Dateien ins Internet
- bei aktivierter Modrinth/Megabase-Verifikation werden nur lokale SHA1-Hashes von Mods abgefragt
- erzwingt keine Administratorrechte
- scannt trotz Zugriffsfehlern weiter
- schreibt am Ende nur eine lokale TXT-Reportdatei

Wichtig: Treffer sind nur Hinweise. Ein Fund beweist nicht automatisch Cheating auf diesem Server.

## Start

Im Ordner dieses Repos:

```powershell
powershell -ExecutionPolicy Bypass -File .\MinecraftDeepScanner.ps1
```

Danach fragt das Skript nach dem Minecraft-Hauptordner. Dort kannst du zum Beispiel eingeben:

```text
C:\Users\dunca\AppData\Roaming\ModrinthApp\profiles\mt 1.21.11
```

Mit direktem Ordnerpfad:

```powershell
powershell -ExecutionPolicy Bypass -File .\MinecraftDeepScanner.ps1 -Path "$env:APPDATA\.minecraft"
```

## Start ueber GitHub

Nach dem Upload auf GitHub:

```powershell
Invoke-RestMethod "https://raw.githubusercontent.com/einfachduncan/MinecraftDeepScanner/main/MinecraftDeepScanner.ps1" -OutFile ".\MinecraftDeepScanner.ps1"
powershell -ExecutionPolicy Bypass -File ".\MinecraftDeepScanner.ps1"
```

Danach den Profilpfad eingeben, z. B.:

```text
C:\Users\dunca\AppData\Roaming\ModrinthApp\profiles\mt 1.21.11
```

Beispiele fuer andere Launcher:

```powershell
powershell -ExecutionPolicy Bypass -File .\MinecraftDeepScanner.ps1 -Path "C:\Users\DEINNAME\AppData\Roaming\.minecraft"
powershell -ExecutionPolicy Bypass -File .\MinecraftDeepScanner.ps1 -Path "C:\Users\DEINNAME\AppData\Roaming\ModrinthApp\profiles\DEIN_PROFIL"
powershell -ExecutionPolicy Bypass -File .\MinecraftDeepScanner.ps1 -Path "C:\Users\DEINNAME\AppData\Roaming\PrismLauncher\instances\DEINE_INSTANZ"
powershell -ExecutionPolicy Bypass -File .\MinecraftDeepScanner.ps1 -Path "C:\Users\DEINNAME\AppData\Roaming\MultiMC\instances\DEINE_INSTANZ"
```

## Was markiert wird

Dateitypen:

- `.jar`
- `.exe`
- `.dll`
- `.bat`
- `.cmd`
- `.ps1`
- `.vbs`
- `.zip`
- `.rar`
- `.7z`

Namens-Treffer:

- `vape`, `meteor`, `wurst`, `raven`, `sigma`, `aristois`, `future`, `impact`
- `liquidbounce`, `bleachhack`, `inertia`, `cheat`, `ghost`
- `autoclicker`, `clicker`, `reach`, `velocity`, `killaura`
- `aimassist`, `triggerbot`, `xray`, `esp`, `baritone`
- `crystal`, `autocry`, `injector`, `loader`, `bypass`, `client`

## Kategorien

- `HIGH`: eindeutige verdachtige Namens-Treffer
- `MEDIUM`: ausfuehrbare Dateien oder DLLs im Minecraft-Profil
- `LOW`: Archive oder ungewoehnliche Dateien
- `INFO`: normale Mods/JARs ohne Namens-Treffer

## Log-Scan

Das Skript liest normale `.log`-Dateien, darunter `logs/latest.log`, sofern vorhanden. Es sucht nach geladenen Mods, Fehlern und verdachtigen Begriffen.

Der Report ist uebersichtlich gruppiert:

- `KURZFAZIT`
- `LATEST.LOG - VERDAECHTIGE TREFFER`
- `LATEST.LOG - FEHLER / CRASH-HINWEISE`
- Datei-Kategorien `HIGH`, `MEDIUM`, `LOW`, `INFO`
- Extra-Bereiche fuer `CONFIG`, `LOG-DATEIEN`, `EXECUTABLES`, `ARCHIVE` und `UNBEKANNTE ORDNER`
- weitere Log-Treffer

Wenn in `logs/latest.log` verdachtige Begriffe gefunden werden, stehen sie extra weit oben im Report.

In der PowerShell-Konsole nutzt der Scanner den ModAnalyzer-Stil mit Startlogo, Scan-Passes, farbigen Sektionen, `None`-Zeilen und einer kurzen Zusammenfassung. Der TXT-Report enthaelt dieselben Informationen ausfuehrlicher.

Fabric-Bibliotheken aus `libraries\net\fabricmc` werden nicht als verdachtig gelistet, weil sie normale Loader-/Minecraft-Abhaengigkeiten sind. Auch harmlose `Fabric Loader`-Zeilen in `latest.log` werden nicht als `loader`-Treffer gewertet.

Flag-Bereiche stehen bewusst weiter unten, damit zuerst normale Bereiche wie Config, Archive, unbekannte Ordner und geladene Mods sichtbar sind.

Optional kann `logs/latest.log` lokal neben den Report exportiert werden. Das ist bewusst kein automatischer Upload und keine automatische E-Mail, damit private Log-Inhalte nicht unbemerkt verschickt werden.

```powershell
powershell -ExecutionPolicy Bypass -File .\MinecraftDeepScanner.ps1 -ExportLatestLog
```

Optional kann zusaetzlich eine lokale E-Mail-Draft-Datei fuer `waxedlogs@gmail.com` vorbereitet werden. Sie wird nicht automatisch gesendet.

```powershell
powershell -ExecutionPolicy Bypass -File .\MinecraftDeepScanner.ps1 -ExportLatestLog -PrepareEmailDraft
```

Wie beim ModAnalyzer kann der Scanner Mods aus dem `mods`-Ordner online verifizieren. Dabei wird nur der lokale SHA1-Hash gegen Modrinth und Megabase abgefragt; die Mod-Datei selbst wird nicht hochgeladen.

Standard ist `Y`, du kannst beim Prompt `n` eingeben oder direkt offline starten:

```powershell
powershell -ExecutionPolicy Bypass -File .\MinecraftDeepScanner.ps1 -NoOnlineVerification
```

Komprimierte `.log.gz`-Dateien werden aus Sicherheits- und Performancegruenden nicht entpackt. Sie werden im Report nur als Dateiname aufgefuehrt.

## Report

Der Report wird im Skriptordner gespeichert:

```text
MinecraftDeepScan_Report_YYYY-MM-DD_HH-mm-ss.txt
```

Jede gefundene Datei enthaelt:

- vollstaendigen Pfad
- Dateiname
- Dateiendung
- Groesse
- Erstellungsdatum
- Aenderungsdatum
- SHA256-Hash
- Grund der Markierung

## Hinweis zur Bewertung

Der Scanner ist kein Anti-Cheat und keine Malware-Analyse. Er hilft beim Sortieren und Pruefen von lokalen Hinweisen. Ein Treffer bedeutet nicht automatisch, dass eine Person auf einem bestimmten Server gecheatet hat.
