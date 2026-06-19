# MinecraftDeepScanner

`MinecraftDeepScanner.ps1` ist ein sicheres, read-only PowerShell-Skript fuer Windows. Es durchsucht einen Minecraft-Hauptordner komplett rekursiv, also nicht nur `mods`, sondern auch `config`, `versions`, `libraries`, `shaderpacks`, `resourcepacks`, `logs`, `crash-reports`, Profil-Downloads und unbekannte Unterordner.

## Sicherheit

- liest nur Dateien und Metadaten
- loescht nichts
- verschiebt nichts
- veraendert nichts
- sendet keine Dateien, Pfade oder Hashes ins Internet
- erzwingt keine Administratorrechte
- scannt trotz Zugriffsfehlern weiter
- schreibt am Ende nur eine lokale TXT-Reportdatei

Wichtig: Treffer sind nur Hinweise. Ein Fund beweist nicht automatisch Cheating auf diesem Server.

## Start

Im Ordner dieses Repos:

```powershell
powershell -ExecutionPolicy Bypass -File .\MinecraftDeepScanner.ps1
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
