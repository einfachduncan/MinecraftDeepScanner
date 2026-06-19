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

function Write-Line {
    Write-Host ("-" * 76) -ForegroundColor DarkGray
}

function Show-Banner {
    try {
        if ([Console]::BufferWidth -lt 120) {
            [Console]::BufferWidth = 120
        }
    }
    catch {
        # Manche Hosts erlauben keine Breiten-Aenderung. Der Banner wird trotzdem ausgegeben.
    }

    $block = [char]::ConvertFromUtf32(0x2588)
    $dr = [char]::ConvertFromUtf32(0x2557)
    $v = [char]::ConvertFromUtf32(0x2551)
    $dl = [char]::ConvertFromUtf32(0x2554)
    $ul = [char]::ConvertFromUtf32(0x255A)
    $ur = [char]::ConvertFromUtf32(0x255D)
    $h = [char]::ConvertFromUtf32(0x2550)

    function Convert-BannerLine {
        param ([AllowEmptyString()][string]$Line)
        return $Line.Replace('B', $block).Replace('7', $dr).Replace('|', $v).Replace('/', $dl).Replace('<', $ul).Replace('>', $ur).Replace('=', $h)
    }

    $bannerLines = @(
        'BB7    BB7 BBBBB7 BB7  BB7BBBBBBB7BBBBBB7 ',
        'BB|    BB|BB/==BB7<BB7BB/>BB/====>BB/==BB7',
        'BB| B7 BB|BBBBBBB| <BBB/> BBBBB7  BB|  BB|',
        'BB|BBB7BB|BB/==BB| BB/BB7 BB/==>  BB|  BB|',
        '<BBB/BBB/>BB|  BB|BB/> BB7BBBBBBB7BBBBBB/>',
        ' <==><==> <=>  <=><=>  <=><======><=====> ',
        '',
        'BBB7   BBB7 BBBBBB7 BBBBBB7      BBBBB7 BBB7   BB7 BBBBB7 BB7  BB7   BB7BBBBBBBB7BBBBBBB7BBBBBB7 ',
        'BBBB7 BBBB|BB/===BB7BB/==BB7    BB/==BB7BBBB7  BB|BB/==BB7BB|  <BB7 BB/><==BB/==>BB/====>BB/==BB7',
        'BB/BBBB/BB|BB|   BB|BB|  BB|    BBBBBBB|BB/BB7 BB|BBBBBBB|BB|   <BBBB/>    BB|   BBBBB7  BBBBBB/>',
        'BB|<BB/>BB|BB|   BB|BB|  BB|    BB/==BB|BB|<BB7BB|BB/==BB|BB|    <BB/>     BB|   BB/==>  BB/==BB7',
        'BB| <=> BB|<BBBBBB/>BBBBBB/>    BB|  BB|BB| <BBBB|BB|  BB|BBBBBBB7BB|      BB|   BBBBBBB7BB|  BB|',
        '<=>     <=> <=====> <=====>     <=>  <=><=>  <===><=>  <=><======><=>      <=>   <======><=>  <=>'
    )

    Write-Host ''
    foreach ($line in $bannerLines) {
        Write-Host (Convert-BannerLine -Line $line) -ForegroundColor Cyan
    }
    Write-Host ''
    Write-Host '                 MinecraftDeepScanner - Deep Profile Security Scanner' -ForegroundColor White
    Write-Host '                              Made by einfachduncan' -ForegroundColor DarkGray
    Write-Host ''
    Write-Line
    Write-Host ''
}

function Write-SpinnerStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $true)]
        [int]$Index,

        [Parameter(Mandatory = $true)]
        [int]$Total,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $frames = @("|", "/", "-", "\")
    $frame = $frames[$Index % $frames.Count]
    $shortName = $Name

    if ($shortName.Length -gt 46) {
        $shortName = $shortName.Substring(0, 43) + "..."
    }

    Write-Host ("`r   [{0}] {1}: {2}/{3} - {4}        " -f $frame, $Activity, $Index, $Total, $shortName) -NoNewline -ForegroundColor DarkGray
}

function Clear-SpinnerStatus {
    Write-Host ("`r" + (" " * 100) + "`r") -NoNewline
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

function Get-ProfileArea {
    param([string]$RelativePath)

    $normalized = $RelativePath.Replace("/", "\").TrimStart("\").ToLowerInvariant()
    if ($normalized -eq "") { return "ROOT" }

    $firstPart = $normalized.Split("\")[0]
    switch ($firstPart) {
        "mods" { return "MODS" }
        "config" { return "CONFIG" }
        "versions" { return "VERSIONS" }
        "libraries" { return "LIBRARIES" }
        "shaderpacks" { return "SHADERPACKS" }
        "resourcepacks" { return "RESOURCEPACKS" }
        "logs" { return "LOGS" }
        "crash-reports" { return "CRASH-REPORTS" }
        "downloads" { return "DOWNLOADS" }
        default { return "UNKNOWN" }
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

    $relativePath = Get-RelativePathSafe -BasePath $RootPath -FullPath $File.FullName

    return [pscustomobject]@{
        Category = $classification.Category
        FullPath = $File.FullName
        RelativePath = $relativePath
        Area = Get-ProfileArea -RelativePath $relativePath
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
        [void]$Lines.Add("    Bereich: $($finding.Area)")
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

function Write-ConsoleFindingList {
    param(
        [object[]]$Items,
        [string]$EmptyText = "None",
        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    if ($Items.Count -eq 0) {
        Write-Host ("  {0}" -f $EmptyText) -ForegroundColor DarkGray
        return
    }

    foreach ($item in $Items) {
        Write-Host ("  {0,-8} {1}" -f $item.Category, $item.RelativePath) -ForegroundColor $Color
        Write-Host ("      Reason: {0}" -f $item.Reason) -ForegroundColor DarkGray
        Write-Host ("      Area:   {0} | Size: {1} | SHA256: {2}" -f $item.Area, $item.SizeText, $item.SHA256) -ForegroundColor DarkGray
    }
}

function Write-ConsoleLogList {
    param(
        [object[]]$Hits,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    if ($Hits.Count -eq 0) {
        Write-Host "  None" -ForegroundColor DarkGray
        return
    }

    foreach ($hit in $Hits) {
        Write-Host ("  {0,-10} {1}:{2}" -f $hit.Kind, $hit.RelativePath, $hit.Line) -ForegroundColor $Color
        Write-Host ("      Match: {0}" -f $hit.Match) -ForegroundColor DarkGray
        Write-Host ("      Line:  {0}" -f $hit.Text) -ForegroundColor White
    }
}

function Show-ConsoleReport {
    param(
        [string]$RootPath,
        [object[]]$Findings,
        [object]$LogFindings,
        [object[]]$ScanErrors,
        [int]$TotalFiles,
        [string]$ReportPath,
        [datetime]$StartedAt,
        [datetime]$FinishedAt
    )

    $highFindings = @($Findings | Where-Object { $_.Category -eq "HIGH" } | Sort-Object RelativePath)
    $mediumFindings = @($Findings | Where-Object { $_.Category -eq "MEDIUM" } | Sort-Object RelativePath)
    $lowFindings = @($Findings | Where-Object { $_.Category -eq "LOW" } | Sort-Object RelativePath)
    $infoFindings = @($Findings | Where-Object { $_.Category -eq "INFO" } | Sort-Object RelativePath)
    $configFindings = @($Findings | Where-Object { $_.Area -eq "CONFIG" } | Sort-Object RelativePath)
    $logAreaFindings = @($Findings | Where-Object { $_.Area -eq "LOGS" } | Sort-Object RelativePath)
    $executableFindings = @($Findings | Where-Object { $ExecutableExtensions -contains $_.Extension.ToLowerInvariant() } | Sort-Object RelativePath)
    $archiveFindings = @($Findings | Where-Object { $ArchiveExtensions -contains $_.Extension.ToLowerInvariant() } | Sort-Object RelativePath)
    $unknownAreaFindings = @($Findings | Where-Object { $_.Area -eq "UNKNOWN" } | Sort-Object RelativePath)
    $latestSuspiciousHits = @($LogFindings.PlainLogHits | Where-Object { $_.IsLatestLog -and $_.Kind -eq "SUSPICIOUS" })
    $latestErrorHits = @($LogFindings.PlainLogHits | Where-Object { $_.IsLatestLog -and $_.Kind -eq "ERROR" })
    $otherSuspiciousHits = @($LogFindings.PlainLogHits | Where-Object { -not $_.IsLatestLog -and $_.Kind -eq "SUSPICIOUS" })
    $infoLogHits = @($LogFindings.PlainLogHits | Where-Object { $_.Kind -eq "INFO" })

    Write-Host ""
    Write-Host ("  *  PROFILE SUMMARY  ({0} files scanned)" -f $TotalFiles) -ForegroundColor Cyan
    Write-Line
    Write-Host ("  Path:               {0}" -f $RootPath) -ForegroundColor DarkGray
    Write-Host ("  Duration:           {0}s" -f ([math]::Round(($FinishedAt - $StartedAt).TotalSeconds, 2))) -ForegroundColor White
    Write-Host ("  HIGH files:         {0}" -f $highFindings.Count) -ForegroundColor Red
    Write-Host ("  MEDIUM files:       {0}" -f $mediumFindings.Count) -ForegroundColor Yellow
    Write-Host ("  LOW files:          {0}" -f $lowFindings.Count) -ForegroundColor White
    Write-Host ("  INFO JARs/mods:     {0}" -f $infoFindings.Count) -ForegroundColor Green
    Write-Host ("  latest.log flags:   {0}" -f $latestSuspiciousHits.Count) -ForegroundColor Red
    Write-Host ("  Access errors:      {0}" -f $ScanErrors.Count) -ForegroundColor Yellow
    Write-Host ("  Files changed:      0") -ForegroundColor White
    Write-Line

    Write-Host ""
    Write-Host ("  *  LATEST.LOG FLAGS  ({0})" -f $latestSuspiciousHits.Count) -ForegroundColor Red
    Write-Line
    Write-ConsoleLogList -Hits $latestSuspiciousHits -Color Red

    Write-Host ""
    Write-Host ("  *  LATEST.LOG ERRORS  ({0})" -f $latestErrorHits.Count) -ForegroundColor Yellow
    Write-Line
    Write-ConsoleLogList -Hits $latestErrorHits -Color Yellow

    Write-Host ""
    Write-Host ("  *  FLAGGED FILES  ({0})" -f $highFindings.Count) -ForegroundColor Red
    Write-Line
    Write-ConsoleFindingList -Items $highFindings -Color Red

    Write-Host ""
    Write-Host ("  *  EXECUTABLES / DLL / SCRIPTS  ({0})" -f $executableFindings.Count) -ForegroundColor Yellow
    Write-Line
    Write-ConsoleFindingList -Items $executableFindings -Color Yellow

    Write-Host ""
    Write-Host ("  *  CONFIG AREA  ({0})" -f $configFindings.Count) -ForegroundColor Cyan
    Write-Line
    Write-ConsoleFindingList -Items $configFindings -Color White

    Write-Host ""
    Write-Host ("  *  LOG FILE AREA  ({0})" -f $logAreaFindings.Count) -ForegroundColor Cyan
    Write-Line
    Write-ConsoleFindingList -Items $logAreaFindings -Color White

    Write-Host ""
    Write-Host ("  *  ARCHIVES  ({0})" -f $archiveFindings.Count) -ForegroundColor White
    Write-Line
    Write-ConsoleFindingList -Items $archiveFindings -Color White

    Write-Host ""
    Write-Host ("  *  UNKNOWN FOLDERS  ({0})" -f $unknownAreaFindings.Count) -ForegroundColor Magenta
    Write-Line
    Write-ConsoleFindingList -Items $unknownAreaFindings -Color Magenta

    Write-Host ""
    Write-Host ("  *  CLEAN / INFO JARS  ({0})" -f $infoFindings.Count) -ForegroundColor Green
    Write-Line
    Write-ConsoleFindingList -Items $infoFindings -Color Green

    Write-Host ""
    Write-Host ("  *  OTHER LOG FLAGS  ({0})" -f $otherSuspiciousHits.Count) -ForegroundColor Yellow
    Write-Line
    Write-ConsoleLogList -Hits $otherSuspiciousHits -Color Yellow

    Write-Host ""
    Write-Host ("  *  LOADED MODS IN LOGS  ({0})" -f $infoLogHits.Count) -ForegroundColor Cyan
    Write-Line
    Write-ConsoleLogList -Hits $infoLogHits -Color Cyan

    Write-Host ""
    Write-Host "SUMMARY" -ForegroundColor Cyan
    Write-Line
    Write-Host ("  Report saved:       {0}" -f $ReportPath) -ForegroundColor White
    Write-Host "  Treffer sind nur Hinweise. Ein Fund beweist nicht automatisch Cheating auf diesem Server." -ForegroundColor Yellow

    $sparkles = [char]::ConvertFromUtf32(0x2728)
    Write-Host ""
    Write-Host ("  {0} Analysis complete! Thanks for using MinecraftDeepScanner" -f $sparkles) -ForegroundColor Cyan
    Write-Line
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
    $configFindings = @($Findings | Where-Object { $_.Area -eq "CONFIG" } | Sort-Object RelativePath)
    $logAreaFindings = @($Findings | Where-Object { $_.Area -eq "LOGS" } | Sort-Object RelativePath)
    $executableFindings = @($Findings | Where-Object { $ExecutableExtensions -contains $_.Extension.ToLowerInvariant() } | Sort-Object RelativePath)
    $archiveFindings = @($Findings | Where-Object { $ArchiveExtensions -contains $_.Extension.ToLowerInvariant() } | Sort-Object RelativePath)
    $unknownAreaFindings = @($Findings | Where-Object { $_.Area -eq "UNKNOWN" } | Sort-Object RelativePath)

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

    Add-Section -Lines $lines -Title "CONFIG - EXTRA"
    Add-FindingLines -Lines $lines -Findings $configFindings

    Add-Section -Lines $lines -Title "LOG-DATEIEN - EXTRA"
    Add-FindingLines -Lines $lines -Findings $logAreaFindings

    Add-Section -Lines $lines -Title "EXECUTABLES / DLL / SCRIPTS - EXTRA"
    Add-FindingLines -Lines $lines -Findings $executableFindings

    Add-Section -Lines $lines -Title "ARCHIVE - EXTRA"
    Add-FindingLines -Lines $lines -Findings $archiveFindings

    Add-Section -Lines $lines -Title "UNBEKANNTE ORDNER - EXTRA"
    Add-FindingLines -Lines $lines -Findings $unknownAreaFindings

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
    Show-Banner
    Write-Host "Read-only scan: no delete, no move, no internet upload, no admin requirement." -ForegroundColor Green

    $startedAt = Get-Date
    $rootPath = Select-MinecraftFolder -InitialPath $Path -AllowFolderDialog ([bool]$UseFolderDialog)

    Write-Host ""
    Write-Host ("Scanning directory: {0}" -f $rootPath) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Pass 1 - Collecting all profile files..." -ForegroundColor Cyan

    $scan = Get-FilesDeep -RootPath $rootPath
    $allFiles = @($scan.Files)
    $scanErrors = @($scan.Errors)

    $watchedFiles = @($allFiles | Where-Object { $WatchedExtensions -contains $_.Extension.ToLowerInvariant() })
    $findings = New-Object System.Collections.ArrayList

    Write-Host ("Pass 2 - Checking {0} watched files..." -f $watchedFiles.Count) -ForegroundColor Cyan
    $current = 0
    foreach ($file in $watchedFiles) {
        $current++
        Write-SpinnerStatus -Activity "File scan" -Index $current -Total $watchedFiles.Count -Name $file.Name
        $percent = if ($watchedFiles.Count -gt 0) { [int](($current / $watchedFiles.Count) * 100) } else { 100 }
        Write-Progress -Activity "Dateien bewerten" -Status $file.FullName -PercentComplete $percent
        [void]$findings.Add((New-ScanFinding -File $file -RootPath $rootPath))
    }
    Clear-SpinnerStatus
    Write-Progress -Activity "Dateien bewerten" -Completed

    Write-Host "Pass 3 - Reading logs and latest.log..." -ForegroundColor Cyan
    $logFindings = Get-LogFindings -AllFiles $allFiles -RootPath $rootPath -ScanGzLogs ([bool]$IncludeGzLogs)

    $finishedAt = Get-Date
    $reportLines = New-Report -RootPath $rootPath -Findings @($findings) -LogFindings $logFindings -ScanErrors $scanErrors -TotalFiles $allFiles.Count -StartedAt $startedAt -FinishedAt $finishedAt

    $reportName = "MinecraftDeepScan_Report_{0}.txt" -f $finishedAt.ToString("yyyy-MM-dd_HH-mm-ss")
    $reportPath = Join-Path -Path $PSScriptRoot -ChildPath $reportName
    $reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

    Show-ConsoleReport -RootPath $rootPath -Findings @($findings) -LogFindings $logFindings -ScanErrors $scanErrors -TotalFiles $allFiles.Count -ReportPath $reportPath -StartedAt $startedAt -FinishedAt $finishedAt
}
catch {
    Write-Host ""
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Es wurden keine Dateien veraendert." -ForegroundColor Yellow
    exit 1
}
