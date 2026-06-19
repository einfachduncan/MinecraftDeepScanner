# GitHub Setup

Dieses Repo ist bereit fuer GitHub.

## Variante 1: Mit GitHub CLI

Falls `gh` installiert und eingeloggt ist:

```powershell
gh repo create MinecraftDeepScanner --public --source . --remote origin --push
```

## Variante 2: Ohne GitHub CLI

1. Auf GitHub ein neues Repo namens `MinecraftDeepScanner` erstellen.
2. Danach im lokalen Repo ausfuehren:

```powershell
git remote add origin https://github.com/einfachduncan/MinecraftDeepScanner.git
git branch -M main
git push -u origin main
```

## Sicherer Start ueber GitHub

Nach dem Upload kann das Skript sicher heruntergeladen und lokal gestartet werden:

```powershell
Invoke-RestMethod "https://raw.githubusercontent.com/einfachduncan/MinecraftDeepScanner/main/MinecraftDeepScanner.ps1" -OutFile ".\MinecraftDeepScanner.ps1"
powershell -ExecutionPolicy Bypass -File ".\MinecraftDeepScanner.ps1"
```

Danach diesen Pfad eingeben, wenn du dein Modrinth-Profil scannen willst:

```text
C:\Users\dunca\AppData\Roaming\ModrinthApp\profiles\mt 1.21.11
```

Direkt mit Minecraft-Ordner:

```powershell
Invoke-RestMethod "https://raw.githubusercontent.com/einfachduncan/MinecraftDeepScanner/main/MinecraftDeepScanner.ps1" -OutFile ".\MinecraftDeepScanner.ps1"
powershell -ExecutionPolicy Bypass -File ".\MinecraftDeepScanner.ps1" -Path "$env:APPDATA\.minecraft"
```

Nicht empfohlen:

```powershell
Invoke-Expression (Invoke-RestMethod "https://raw.githubusercontent.com/einfachduncan/MinecraftDeepScanner/main/MinecraftDeepScanner.ps1")
```

Der sichere Weg laedt die Datei erst herunter, damit man sie ansehen kann, und startet sie danach lokal.
