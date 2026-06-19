<# 
MinecraftDeepScanner.ps1

Read-only Deep Scanner fuer Minecraft-Profile und Launcher-Instanzen.

Sicherheitsversprechen:
- liest nur Dateien und Metadaten
- loescht, verschiebt und veraendert nichts
- sendet keine Dateien und keine Hashes ins Internet
- erzwingt keine Administratorrechte
- scannt auch weiter, wenn einzelne Dateien/Ordner nicht lesbar sind
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [switch]$UseFolderDialog,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeGzLogs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SuspiciousWords = @(
    "vape", "meteor", "wurst", "raven", "sigma", "aristois", "future", "impact",
    "liquidbounce", "bleachhack", "inertia", "cheat", "ghost", "autoclicker",
    "clicker", "reach", "velocity", "killaura", "aimassist", "triggerbot",
    "xray", "esp", "baritone", "crystal", "autocry", "injector", "loader",
    "bypass", "client"
)

$WatchedExtensions = @(
    ".jar", ".exe", ".dll", ".bat", ".cmd", ".ps1", ".vbs", ".zip", ".rar", ".7z"
)

$ExecutableExtensions = @(".exe", ".dll", ".bat", ".cmd", ".ps1", ".vbs")
$ArchiveExtensions = @(".zip", ".rar", ".7z")
$LogInfoWords = @(
    "loading mod", "loaded mod", "loading mods", "loaded mods", "mod list",
    "loading plugin", "loaded plugin"
)
$LogErrorWords = @(
    "error", "exception", "failed", "crash", "mixin apply failed", "unable to load"
)
$LogSuspiciousWords = @(
    "vape", "meteor", "wurst", "raven", "sigma", "aristois", "future", "impact",
    "liquidbounce", "bleachhack", "inertia", "cheat", "ghost", "autoclicker",
    "clicker", "reach", "velocity", "killaura", "aimassist", "triggerbot",
    "xray", "esp", "baritone", "crystal", "autocry", "injector", "loader",
    "bypass", "client"
)

function Write-Title {
    param([string]$Text)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
}

function Select-MinecraftFolder {
    param(
        [string]$InitialPath,
        [bool]$AllowFolderDialog
    )

    if (-not [string]::IsNullOrWhiteSpace($InitialPath)) {
        $resolved = Resolve-Path -LiteralPath $InitialPath -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $resolved.Path -PathType Container)) {
            throw "Der angegebene Pfad ist kein Ordner: $InitialPath"
        }
        return $resolved.Path
    }

    if ($AllowFolderDialog -and ($env:OS -eq "Windows_NT" -or $PSVersionTable.PSEdition -eq "Desktop")) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Waehle den Minecraft-Hauptordner, z. B. .minecraft, Modrinth-, Prism- oder MultiMC-Instanz"
            $dialog.ShowNewFolderButton = $false

            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                return $dialog.SelectedPath
            }
        }
        catch {
            Write-Host "Ordnerauswahl per Fenster nicht verfuegbar. Nutze Texteingabe." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "Bitte Minecraft-Hauptordner eingeben." -ForegroundColor Cyan
    Write-Host "Beispiele:" -ForegroundColor DarkGray
    Write-Host "  $env:APPDATA\.minecraft" -ForegroundColor DarkGray
    Write-Host "  $env:APPDATA\ModrinthApp\profiles\mt 1.21.11" -ForegroundColor DarkGray
    Write-Host "  $env:APPDATA\PrismLauncher\instances\DEINE_INSTANZ" -ForegroundColor DarkGray
    Write-Host ""
    $manualPath = Read-Host "Pfad zum Minecraft-Hauptordner eingeben"
    $manualPath = $manualPath.Trim().Trim('"')
    $resolvedManual = Resolve-Path -LiteralPath $manualPath -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $resolvedManual.Path -PathType Container)) {
        throw "Der angegebene Pfad ist kein Ordner: $manualPath"
    }
    return $resolvedManual.Path
}

function Format-FileSize {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Find-SuspiciousWords {
    param([string]$Text)

    $wordMatches = New-Object System.Collections.ArrayList
    foreach ($word in $SuspiciousWords) {
        if ($Text -match [regex]::Escape($word)) {
            [void]$wordMatches.Add($word)
        }
    }
    return @($wordMatches | Sort-Object -Unique)
}

function Get-RelativePathSafe {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    try {
        $baseUri = [System.Uri]::new(($BasePath.TrimEnd("\") + "\"))
        $fullUri = [System.Uri]::new($FullPath)
        return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fullUri).ToString()).Replace("/", "\")
    }
    catch {
        return $FullPath
    }
}

function Get-CategoryAndReason {
    param(
        [System.IO.FileInfo]$File,
        [string[]]$WordHits
    )

    $extension = $File.Extension.ToLowerInvariant()
    $reasons = New-Object System.Collections.ArrayList

    if ($WordHits.Count -gt 0) {
        [void]$reasons.Add("Dateiname enthaelt verdachtige Begriffe: $($WordHits -join ', ')")
        return [pscustomobject]@{
            Category = "HIGH"
            Reason = ($reasons -join "; ")
        }
    }

    if ($ExecutableExtensions -contains $extension) {
        [void]$reasons.Add("Ausfuehrbare Datei oder DLL innerhalb des Minecraft-Profils")
        return [pscustomobject]@{
            Category = "MEDIUM"
            Reason = ($reasons -join "; ")
        }
    }

    if ($ArchiveExtensions -contains $extension) {
        [void]$reasons.Add("Archivdatei innerhalb des Minecraft-Profils")
        return [pscustomobject]@{
            Category = "LOW"
            Reason = ($reasons -join "; ")
        }
    }

    if ($extension -eq ".jar") {
        [void]$reasons.Add("JAR/Mod-Datei ohne verdachtigen Namenstreffer")
        return [pscustomobject]@{
            Category = "INFO"
            Reason = ($reasons -join "; ")
        }
    }

    [void]$reasons.Add("Ungewoehnlicher beobachteter Dateityp")
    return [pscustomobject]@{
        Category = "LOW"
        Reason = ($reasons -join "; ")
    }
}

function Get-FileHashSafe {
    param([string]$FilePath)

    try {
        return (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256 -ErrorAction Stop).Hash
    }
    catch {
        return "HASH_FEHLER: $($_.Exception.Message)"
    }
}

function New-ScanFinding {
    param(
        [System.IO.FileInfo]$File,
        [string]$RootPath
    )

    $wordHits = @(Find-SuspiciousWords -Text $File.Name.ToLowerInvariant())
    $classification = Get-CategoryAndReason -File $File -WordHits $wordHits

    return [pscustomobject]@{
        Category = $classification.Category
        FullPath = $File.FullName
        RelativePath = Get-RelativePathSafe -BasePath $RootPath -FullPath $File.FullName
        FileName = $File.Name
        Extension = $File.Extension
        SizeBytes = $File.Length
        SizeText = Format-FileSize -Bytes $File.Length
        Created = $File.CreationTime
        Modified = $File.LastWriteTime
        SHA256 = Get-FileHashSafe -FilePath $File.FullName
        Reason = $classification.Reason
    }
}

function Get-FilesDeep {
    param([string]$RootPath)

    $results = New-Object System.Collections.ArrayList
    $errors = New-Object System.Collections.ArrayList
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($RootPath)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        Write-Progress -Activity "Minecraft Deep Scan" -Status "Durchsuche: $current" -PercentComplete -1

        try {
            $directories = @(Get-ChildItem -LiteralPath $current -Directory -Force -ErrorAction Stop)
            foreach ($directory in $directories) {
                $stack.Push($directory.FullName)
            }
        }
        catch {
            [void]$errors.Add([pscustomobject]@{
                Path = $current
                Type = "Ordner"
                Error = $_.Exception.Message
            })
        }

        try {
            $files = @(Get-ChildItem -LiteralPath $current -File -Force -ErrorAction Stop)
            foreach ($file in $files) {
                [void]$results.Add($file)
            }
        }
        catch {
            [void]$errors.Add([pscustomobject]@{
                Path = $current
                Type = "Dateien"
                Error = $_.Exception.Message
            })
        }
    }

    Write-Progress -Activity "Minecraft Deep Scan" -Completed

    return [pscustomobject]@{
        Files = $results.ToArray()
        Errors = $errors.ToArray()
    }
}

function Read-LogFileSafe {
    param(
        [System.IO.FileInfo]$LogFile,
        [string]$RootPath
    )

    $hits = New-Object System.Collections.ArrayList

    try {
        $lineNumber = 0
        Get-Content -LiteralPath $LogFile.FullName -Encoding UTF8 -ErrorAction Stop | ForEach-Object {
            $lineNumber++
            $line = [string]$_
            $lowerLine = $line.ToLowerInvariant()
            $matched = $false

            foreach ($word in $LogSuspiciousWords) {
                if ($lowerLine.Contains($word)) {
                    [void]$hits.Add((New-LogHit -LogFile $LogFile -RootPath $RootPath -LineNumber $lineNumber -Match $word -Kind "SUSPICIOUS" -Text $line))
                    $matched = $true
                    break
                }
            }

            if (-not $matched) {
                foreach ($word in $LogErrorWords) {
                    if ($lowerLine.Contains($word)) {
                        [void]$hits.Add((New-LogHit -LogFile $LogFile -RootPath $RootPath -LineNumber $lineNumber -Match $word -Kind "ERROR" -Text $line))
                        $matched = $true
                        break
                    }
                }
            }

            if (-not $matched) {
                foreach ($word in $LogInfoWords) {
                    if ($lowerLine.Contains($word)) {
                        [void]$hits.Add((New-LogHit -LogFile $LogFile -RootPath $RootPath -LineNumber $lineNumber -Match $word -Kind "INFO" -Text $line))
                        break
                    }
                }
            }
        }
    }
    catch {
        [void]$hits.Add([pscustomobject]@{
            LogFile = $LogFile.FullName
            RelativePath = Get-RelativePathSafe -BasePath $RootPath -FullPath $LogFile.FullName
            IsLatestLog = ($LogFile.Name.ToLowerInvariant() -eq "latest.log")
            Line = 0
            Match = "LOG_LESEN_FEHLER"
            Kind = "ERROR"
            Text = $_.Exception.Message
        })
    }

    return $hits.ToArray()
}

function New-LogHit {
    param(
        [System.IO.FileInfo]$LogFile,
        [string]$RootPath,
        [int]$LineNumber,
        [string]$Match,
        [string]$Kind,
        [string]$Text
    )

    $relativePath = Get-RelativePathSafe -BasePath $RootPath -FullPath $LogFile.FullName
    return [pscustomobject]@{
        LogFile = $LogFile.FullName
        RelativePath = $relativePath
        IsLatestLog = ($relativePath.ToLowerInvariant() -eq "logs\latest.log" -or $LogFile.Name.ToLowerInvariant() -eq "latest.log")
        Line = $LineNumber
        Match = $Match
        Kind = $Kind
        Text = if ($Text.Length -gt 180) { $Text.Substring(0, 180) + "..." } else { $Text }
    }
}

function Get-LogFindings {
    param(
        [System.IO.FileInfo[]]$AllFiles,
        [string]$RootPath,
        [bool]$ScanGzLogs
    )

    $logHits = New-Object System.Collections.ArrayList
    $gzLogs = New-Object System.Collections.ArrayList

    $plainLogs = @($AllFiles | Where-Object { $_.Extension.ToLowerInvariant() -eq ".log" })
    $gzLogFiles = @($AllFiles | Where-Object { $_.Name.ToLowerInvariant().EndsWith(".log.gz") })

    foreach ($logFile in $plainLogs) {
        Write-Progress -Activity "Minecraft Logs lesen" -Status $logFile.FullName -PercentComplete -1
        foreach ($hit in @(Read-LogFileSafe -LogFile $logFile -RootPath $RootPath)) {
            [void]$logHits.Add($hit)
        }
    }

    foreach ($gzLog in $gzLogFiles) {
        [void]$gzLogs.Add([pscustomobject]@{
            FullPath = $gzLog.FullName
            RelativePath = Get-RelativePathSafe -BasePath $RootPath -FullPath $gzLog.FullName
            SizeText = Format-FileSize -Bytes $gzLog.Length
            Note = if ($ScanGzLogs) { "Komprimiertes Log erkannt; Inhalt wird aus Sicherheits-/Performancegruenden nicht entpackt." } else { "Komprimiertes Log erkannt; nur Dateiname angezeigt." }
        })
    }

    Write-Progress -Activity "Minecraft Logs lesen" -Completed

    return [pscustomobject]@{
        PlainLogHits = $logHits.ToArray()
        GzLogs = $gzLogs.ToArray()
    }
}

function Add-Section {
    param(
        [System.Collections.ArrayList]$Lines,
        [string]$Title
    )

    [void]$Lines.Add("")
    [void]$Lines.Add("============================================================")
    [void]$Lines.Add($Title)
    [void]$Lines.Add("============================================================")
}

function Add-FindingLines {
    param(
        [System.Collections.ArrayList]$Lines,
        [object[]]$Findings
    )

    if ($Findings.Count -eq 0) {
        [void]$Lines.Add("Keine Treffer in dieser Kategorie.")
        return
    }

    $index = 1
    foreach ($finding in $Findings) {
        [void]$Lines.Add("")
        [void]$Lines.Add("[$index] [$($finding.Category)] $($finding.RelativePath)")
        [void]$Lines.Add("    Grund:   $($finding.Reason)")
        [void]$Lines.Add("    Datei:   $($finding.FileName) | $($finding.Extension) | $($finding.SizeText)")
        [void]$Lines.Add("    Zeit:    Erstellt $($finding.Created) | Geaendert $($finding.Modified)")
        [void]$Lines.Add("    SHA256:  $($finding.SHA256)")
        [void]$Lines.Add("    Pfad:    $($finding.FullPath)")
        $index++
    }
}

function Add-LogHitLines {
    param(
        [System.Collections.ArrayList]$Lines,
        [object[]]$Hits
    )

    if ($Hits.Count -eq 0) {
        [void]$Lines.Add("Keine Treffer.")
        return
    }

    $index = 1
    foreach ($hit in $Hits) {
        [void]$Lines.Add("")
        [void]$Lines.Add("[$index] [$($hit.Kind)] $($hit.RelativePath):$($hit.Line)")
        [void]$Lines.Add("    Treffer: $($hit.Match)")
        [void]$Lines.Add("    Zeile:   $($hit.Text)")
        $index++
    }
}

function New-Report {
    param(
        [string]$RootPath,
        [object[]]$Findings,
        [object]$LogFindings,
        [object[]]$ScanErrors,
        [int]$TotalFiles,
        [datetime]$StartedAt,
        [datetime]$FinishedAt
    )

    $lines = New-Object System.Collections.ArrayList

    [void]$lines.Add("MinecraftDeepScanner Report")
    [void]$lines.Add("Erstellt: $($FinishedAt.ToString('yyyy-MM-dd HH:mm:ss'))")
    [void]$lines.Add("Gescannter Hauptordner: $RootPath")
    [void]$lines.Add("Dauer: $([math]::Round(($FinishedAt - $StartedAt).TotalSeconds, 2)) Sekunden")
    [void]$lines.Add("Gescannte Dateien gesamt: $TotalFiles")
    [void]$lines.Add("Markierte Dateien: $($Findings.Count)")
    [void]$lines.Add("")
    [void]$lines.Add("WICHTIG: Treffer sind nur Hinweise. Ein Fund beweist nicht automatisch Cheating auf diesem Server.")
    [void]$lines.Add("Das Skript arbeitet read-only, sendet nichts ins Internet und erzwingt keine Admin-Rechte.")

    $highFindings = @($Findings | Where-Object { $_.Category -eq "HIGH" })
    $mediumFindings = @($Findings | Where-Object { $_.Category -eq "MEDIUM" })
    $lowFindings = @($Findings | Where-Object { $_.Category -eq "LOW" })
    $infoFindings = @($Findings | Where-Object { $_.Category -eq "INFO" })
    $latestSuspiciousHits = @($LogFindings.PlainLogHits | Where-Object { $_.IsLatestLog -and $_.Kind -eq "SUSPICIOUS" })
    $latestErrorHits = @($LogFindings.PlainLogHits | Where-Object { $_.IsLatestLog -and $_.Kind -eq "ERROR" })
    $otherSuspiciousHits = @($LogFindings.PlainLogHits | Where-Object { -not $_.IsLatestLog -and $_.Kind -eq "SUSPICIOUS" })
    $infoLogHits = @($LogFindings.PlainLogHits | Where-Object { $_.Kind -eq "INFO" })

    Add-Section -Lines $lines -Title "KURZFAZIT"
    [void]$lines.Add("HIGH Dateien:       $($highFindings.Count)")
    [void]$lines.Add("MEDIUM Dateien:     $($mediumFindings.Count)")
    [void]$lines.Add("LOW Dateien:        $($lowFindings.Count)")
    [void]$lines.Add("INFO JARs/Mods:     $($infoFindings.Count)")
    [void]$lines.Add("latest.log auffaellig: $($latestSuspiciousHits.Count)")
    [void]$lines.Add("latest.log Fehler:     $($latestErrorHits.Count)")
    [void]$lines.Add("Zugriffsfehler:     $($ScanErrors.Count)")

    Add-Section -Lines $lines -Title "LATEST.LOG - VERDAECHTIGE TREFFER"
    Add-LogHitLines -Lines $lines -Hits $latestSuspiciousHits

    Add-Section -Lines $lines -Title "LATEST.LOG - FEHLER / CRASH-HINWEISE"
    Add-LogHitLines -Lines $lines -Hits $latestErrorHits

    foreach ($category in @("HIGH", "MEDIUM", "LOW", "INFO")) {
        $categoryFindings = @($Findings | Where-Object { $_.Category -eq $category } | Sort-Object FullPath)
        Add-Section -Lines $lines -Title "$category - Dateien"
        Add-FindingLines -Lines $lines -Findings $categoryFindings
    }

    Add-Section -Lines $lines -Title "WEITERE LOGS - VERDAECHTIGE TREFFER"
    Add-LogHitLines -Lines $lines -Hits $otherSuspiciousHits

    Add-Section -Lines $lines -Title "LOG-INFO - GELADENE MODS"
    Add-LogHitLines -Lines $lines -Hits $infoLogHits

    Add-Section -Lines $lines -Title "KOMPRIMIERTE LOGS (.log.gz)"
    if ($LogFindings.GzLogs.Count -eq 0) {
        [void]$lines.Add("Keine .log.gz-Dateien gefunden.")
    }
    else {
        foreach ($gz in $LogFindings.GzLogs) {
            [void]$lines.Add("$($gz.RelativePath) | $($gz.SizeText) | $($gz.Note)")
        }
    }

    Add-Section -Lines $lines -Title "ZUGRIFFSFEHLER / UEBERSPRUNGEN"
    if ($ScanErrors.Count -eq 0) {
        [void]$lines.Add("Keine Zugriffsfehler.")
    }
    else {
        foreach ($scanError in $ScanErrors) {
            [void]$lines.Add("$($scanError.Type): $($scanError.Path)")
            [void]$lines.Add("  Fehler: $($scanError.Error)")
        }
    }

    return $lines.ToArray()
}

try {
    Write-Title "MinecraftDeepScanner"
    Write-Host "Read-only Scan: keine Loeschung, keine Veraenderung, kein Internet." -ForegroundColor Green

    $startedAt = Get-Date
    $rootPath = Select-MinecraftFolder -InitialPath $Path -AllowFolderDialog ([bool]$UseFolderDialog)

    Write-Title "Scan startet"
    Write-Host "Ordner: $rootPath"

    $scan = Get-FilesDeep -RootPath $rootPath
    $allFiles = @($scan.Files)
    $scanErrors = @($scan.Errors)

    $watchedFiles = @($allFiles | Where-Object { $WatchedExtensions -contains $_.Extension.ToLowerInvariant() })
    $findings = New-Object System.Collections.ArrayList

    $current = 0
    foreach ($file in $watchedFiles) {
        $current++
        $percent = if ($watchedFiles.Count -gt 0) { [int](($current / $watchedFiles.Count) * 100) } else { 100 }
        Write-Progress -Activity "Dateien bewerten" -Status $file.FullName -PercentComplete $percent
        [void]$findings.Add((New-ScanFinding -File $file -RootPath $rootPath))
    }
    Write-Progress -Activity "Dateien bewerten" -Completed

    $logFindings = Get-LogFindings -AllFiles $allFiles -RootPath $rootPath -ScanGzLogs ([bool]$IncludeGzLogs)

    $finishedAt = Get-Date
    $reportLines = New-Report -RootPath $rootPath -Findings @($findings) -LogFindings $logFindings -ScanErrors $scanErrors -TotalFiles $allFiles.Count -StartedAt $startedAt -FinishedAt $finishedAt

    $reportName = "MinecraftDeepScan_Report_{0}.txt" -f $finishedAt.ToString("yyyy-MM-dd_HH-mm-ss")
    $reportPath = Join-Path -Path $PSScriptRoot -ChildPath $reportName
    $reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

    Write-Title "Report"
    $reportLines | ForEach-Object { Write-Host $_ }

    Write-Title "Fertig"
    Write-Host "Report gespeichert:" -ForegroundColor Green
    Write-Host $reportPath -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Hinweis: Treffer sind nur Hinweise. Ein Fund beweist nicht automatisch Cheating auf diesem Server." -ForegroundColor Yellow
}
catch {
    Write-Host ""
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Es wurden keine Dateien veraendert." -ForegroundColor Yellow
    exit 1
}
