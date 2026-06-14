# _common.ps1 — helpers partagés pour pc-optim scans
# Dot-sourcé par scan_*.ps1 : . "$PSScriptRoot\_common.ps1"
# Read-only strict : aucun Set-Content / New-Item / Remove-Item / Stop- / Restart-
# Set-StrictMode désactivé volontairement (Get-ChildItem -EA SilentlyContinue retourne $null)

$ErrorActionPreference = 'Continue'
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

    try {
        $items = Get-ChildItem -LiteralPath $Path -Recurse -File -Force `
            -ErrorAction SilentlyContinue -ErrorVariable +scanErrors
        foreach ($item in $items) {
            if ((Get-Date) -gt $deadline) {
                _Warn "_Get-FolderSize timeout après ${TimeoutSeconds}s sur $Path"
                break
            }
            # Skip placeholder OneDrive / Google Drive Stream
            $attrs = [string]$item.Attributes
            if ($attrs -match 'Offline|RecallOnOpen|RecallOnDataAccess') {
                $script:OneDriveSkipped++
                continue
            }
            $total += $item.Length
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

function _Get-TopFolders {
    <#
    .SYNOPSIS
        Top N sous-dossiers directs d'un parent, triés par taille décroissante.
    #>
    param(
        [Parameter(Mandatory)][string]$ParentPath,
        [int]$TopN = 20,
        [int]$PerFolderTimeoutSeconds = 60
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

function _Report-ScanStats {
    _Warn ("Stats scan : {0} AccessDenied skippés, {1} placeholder Drive skippés" `
        -f $script:AccessDeniedCount, $script:OneDriveSkipped)
}

# Note : pas d'export-module — fichier dot-sourcé.
