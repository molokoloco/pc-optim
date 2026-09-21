# _common.ps1 — helpers partagés pour pc-optim scans
# Dot-sourcé par scan_*.ps1 : . "$PSScriptRoot\_common.ps1"
# Read-only strict : aucun Set-Content / New-Item / Remove-Item / Stop- / Restart-
# Set-StrictMode désactivé volontairement (Get-ChildItem -EA SilentlyContinue retourne $null)

$ErrorActionPreference = 'Continue'

# Logs stderr en UTF-8 (sinon accents mojibake dans _scan_*.log). Per-process, read-only.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}

$script:AccessDeniedCount = 0
$script:OneDriveSkipped = 0

function _Format-Size {
    param([Parameter(Mandatory)][long]$Bytes)
    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return ("{0:N1} KB" -f ($Bytes / 1KB)) }
    if ($Bytes -lt 1GB) { return ("{0:N1} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -lt 1TB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    return ("{0:N2} TB" -f ($Bytes / 1TB))
}

function _To-GB {
    param([Parameter(Mandatory)][long]$Bytes)
    return [math]::Round($Bytes / 1GB, 2)
}

function _Get-FolderSize {
    <#
    .SYNOPSIS
        Calcule la taille d'un dossier (récursif), tolérant AccessDenied + placeholder Drive Stream.
    .OUTPUTS
        long — taille totale en bytes (0 si dossier absent ou full denied)
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$TimeoutSeconds = 90
    )

    if (-not (Test-Path -LiteralPath $Path)) { return 0 }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $total = [long]0

    # NB : Get-ChildItem doit STREAMER (pipeline), pas être collecté dans une variable.
    # Collecté, l'énumération complète se fait avant la 1re itération : sur un gros dossier
    # elle dépasse déjà le deadline, on breake au 1er élément et on retourne 0 B — un dossier
    # de 80 GB était silencieusement rapporté vide. Le do/while donne une cible au `break`.
    $timedOut = $false
    try {
        do {
            Get-ChildItem -LiteralPath $Path -Recurse -File -Force `
                -ErrorAction SilentlyContinue -ErrorVariable +scanErrors |
                ForEach-Object {
                    if ((Get-Date) -gt $deadline) { $timedOut = $true; break }
                    # Skip placeholder OneDrive / Google Drive Stream
                    $attrs = [string]$_.Attributes
                    if ($attrs -match 'Offline|RecallOnOpen|RecallOnDataAccess') {
                        $script:OneDriveSkipped++
                        return
                    }
                    $total += $_.Length
                }
        } while ($false)
        if ($timedOut) {
            _Warn ("_Get-FolderSize timeout apres {0}s sur {1} — total PARTIEL ({2})" `
                -f $TimeoutSeconds, $Path, (_Format-Size $total))
        }
        if ($scanErrors) {
            $denied = @($scanErrors | Where-Object { $_.Exception -is [System.UnauthorizedAccessException] }).Count
            $script:AccessDeniedCount += $denied
        }
    } catch {
        _Warn ("_Get-FolderSize erreur sur {0} : {1}" -f $Path, $_.Exception.Message)
    }

    return $total
}

function _Resolve-LongPath {
    <#
    .SYNOPSIS
        Chemin canonique pour dédupliquer : nom long (pas 8.3), casse du disque, sans `\` final.
        $env:TEMP est souvent en 8.3 (C:\Users\MOLOK~1\...) alors que $env:LOCALAPPDATA\Temp
        ne l'est pas — même dossier, deux écritures.
    #>
    param([Parameter(Mandatory)][string]$Path)
    try {
        $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
        $root = [System.IO.Path]::GetPathRoot($full)
        $resolved = $root.TrimEnd('\')
        foreach ($seg in $full.Substring($root.Length).Split('\', [StringSplitOptions]::RemoveEmptyEntries)) {
            $hit = [System.IO.Directory]::GetFileSystemEntries("$resolved\", $seg) | Select-Object -First 1
            $resolved = if ($hit) { $hit.TrimEnd('\') } else { "$resolved\$seg" }
        }
        return $resolved
    } catch {
        return $Path.TrimEnd('\')
    }
}

function _Get-TopFolders {
    <#
    .SYNOPSIS
        Top N sous-dossiers directs d'un parent, triés par taille décroissante.
    #>
    param(
        [Parameter(Mandatory)][string]$ParentPath,
        [int]$TopN = 20,
        # AppData dépasse largement 60s sur un profil chargé. Surchargeable : PC_OPTIM_FOLDER_TIMEOUT
        [int]$PerFolderTimeoutSeconds = $(if ($env:PC_OPTIM_FOLDER_TIMEOUT) { [int]$env:PC_OPTIM_FOLDER_TIMEOUT } else { 240 })
    )

    if (-not (Test-Path -LiteralPath $ParentPath)) { return @() }

    $children = Get-ChildItem -LiteralPath $ParentPath -Directory -Force `
        -ErrorAction SilentlyContinue
    $results = foreach ($child in $children) {
        $size = _Get-FolderSize -Path $child.FullName -TimeoutSeconds $PerFolderTimeoutSeconds
        [PSCustomObject]@{
            path        = $child.FullName
            size_bytes  = $size
            size_human  = _Format-Size $size
            size_gb     = _To-GB $size
        }
    }
    return $results | Sort-Object size_bytes -Descending | Select-Object -First $TopN
}

function _New-Finding {
    <#
    .SYNOPSIS
        Objet finding standardisé pour le rapport.
    .PARAMETER Risk
        green | yellow | red
    .PARAMETER ToolHint
        spacesniffer | ccleaner | 7zip | wingetui | memorycleaner | oem | windows-builtin | manual
    #>
    param(
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][long]$SizeBytes,
        [ValidateSet('green','yellow','red')][string]$Risk = 'yellow',
        [string]$Recommendation = '',
        [string]$ToolHint = 'manual',
        [string]$Label = ''
    )
    return [PSCustomObject]@{
        category         = $Category
        label            = $Label
        path             = $Path
        size_bytes       = $SizeBytes
        size_human       = _Format-Size $SizeBytes
        size_gb          = _To-GB $SizeBytes
        risk             = $Risk
        gain_estimate_gb = _To-GB $SizeBytes
        recommendation   = $Recommendation
        tool_hint        = $ToolHint
    }
}

function _Get-Risk {
    <#
    .SYNOPSIS
        Détermine le niveau de risque par catégorie + taille.
        Heuristique conservative : risque = potentiel de casse si suppression aveugle.
    #>
    param(
        [Parameter(Mandatory)][string]$Category,
        [long]$SizeBytes = 0
    )
    switch ($Category) {
        'temp'              { return 'green' }      # Windows Temp / cache navigateur
        'recycle_bin'       { return 'green' }
        'package_cache'     { return 'green' }      # npm/pip/yarn cache régénérable
        'docker_dangling'   { return 'green' }
        'archive'           { return 'yellow' }     # ISO peuvent être utiles
        'download'          { return 'yellow' }
        'duplicate'         { return 'yellow' }     # nom+taille != preuve
        'ai_model'          { return 'yellow' }     # à vérifier si utilisé
        'app_unused'        { return 'yellow' }
        'node_modules'      { return 'yellow' }
        'system_critical'   { return 'red' }
        'app_active'        { return 'red' }
        'unknown_listening' { return 'red' }
        default             { return 'yellow' }
    }
}

function _Test-IsAdmin {
    try {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $pr = New-Object System.Security.Principal.WindowsPrincipal($id)
        return $pr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function _Warn {
    # Sortie sur stderr "vrai" (stream 2) — Write-Warning va sur stream 3
    # qui n'est pas capturé par la redirection bash `2> log`.
    param([Parameter(Mandatory)][string]$Message)
    [Console]::Error.WriteLine($Message)
}

function _Write-Phase {
    param([Parameter(Mandatory)][string]$Message)
    _Warn "[$((Get-Date).ToString('HH:mm:ss'))] $Message"
}

function _Get-MachineInfo {
    try {
        $os  = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cs  = Get-CimInstance Win32_ComputerSystem  -ErrorAction SilentlyContinue
        $cpu = Get-CimInstance Win32_Processor       -ErrorAction SilentlyContinue | Select-Object -First 1
        return [PSCustomObject]@{
            hostname    = if ($cs) { $cs.Name } else { $env:COMPUTERNAME }
            os_caption  = if ($os) { $os.Caption } else { '' }
            os_version  = if ($os) { $os.Version } else { '' }
            cpu         = if ($cpu) { $cpu.Name.Trim() } else { '' }
            ram_gb      = if ($cs) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { 0 }
            is_admin    = _Test-IsAdmin
            scanned_at  = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
        }
    } catch {
        return [PSCustomObject]@{
            hostname   = $env:COMPUTERNAME
            os_caption = ''; os_version = ''; cpu = ''; ram_gb = 0
            is_admin   = _Test-IsAdmin
            scanned_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
        }
    }
}

function _Get-DriveInfo {
    param([string]$DriveLetter = 'C')
    try {
        $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${DriveLetter}:'" -ErrorAction Stop
        return [PSCustomObject]@{
            drive       = "${DriveLetter}:"
            size_gb     = [math]::Round($d.Size / 1GB, 1)
            free_gb     = [math]::Round($d.FreeSpace / 1GB, 1)
            used_gb     = [math]::Round(($d.Size - $d.FreeSpace) / 1GB, 1)
            used_pct    = if ($d.Size) { [math]::Round((($d.Size - $d.FreeSpace) / $d.Size) * 100, 1) } else { 0 }
            filesystem  = $d.FileSystem
            volume_name = $d.VolumeName
        }
    } catch {
        return [PSCustomObject]@{
            drive = "${DriveLetter}:"; size_gb = 0; free_gb = 0; used_gb = 0; used_pct = 0
            filesystem = ''; volume_name = ''
        }
    }
}

function _Emit-Json {
    <#
    .SYNOPSIS
        Sérialise en JSON puis échappe tout non-ASCII en \uXXXX avant d'écrire sur stdout.
    .DESCRIPTION
        La redirection bash `> fichier.json` passe par la codepage console : un caractère
        hors codepage est translittéré silencieusement. Un nom de fichier contenant
        U+FF02 (guillemet pleine chasse) devient un `"` droit non échappé → JSON invalide.
        Sortie ASCII pure = immunisée à la codepage.
    #>
    param([Parameter(Mandatory)]$InputObject, [int]$Depth = 8)
    $json = $InputObject | ConvertTo-Json -Depth $Depth
    [regex]::Replace($json, '[^\x20-\x7E\r\n\t]', {
        param($m) '\u{0:x4}' -f [int][char]$m.Value
    })
}

function _Report-ScanStats {
    _Warn ("Stats scan : {0} AccessDenied skippés, {1} placeholder Drive skippés" `
        -f $script:AccessDeniedCount, $script:OneDriveSkipped)
}

# Note : pas d'export-module — fichier dot-sourcé.
