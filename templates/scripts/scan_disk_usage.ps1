# scan_disk_usage.ps1 — top dossiers C:\, temp système, archives volumineuses
# Sortie : JSON unique sur stdout
# Read-only : aucune écriture, aucune modif système
param(
    [int]$TopN = 50
)

. "$PSScriptRoot\_common.ps1"

_Write-Phase "scan_disk_usage : drive info"
$drive = _Get-DriveInfo -DriveLetter 'C'
$machine = _Get-MachineInfo

_Write-Phase "scan_disk_usage : top dossiers profil utilisateur"
$userTop = _Get-TopFolders -ParentPath $env:USERPROFILE -TopN $TopN

_Write-Phase "scan_disk_usage : temp système & cache Windows"
$tempZones = @(
    @{ label = 'Windows Temp';                path = "$env:WINDIR\Temp";                                   risk = 'green';  tool = 'windows-builtin' }
    @{ label = 'Windows SoftwareDistribution'; path = "$env:WINDIR\SoftwareDistribution\Download";          risk = 'green';  tool = 'windows-builtin' }
    @{ label = 'Windows Installer cache';     path = "$env:WINDIR\Installer";                              risk = 'red';    tool = 'manual' }
    @{ label = 'User Temp';                   path = $env:TEMP;                                            risk = 'green';  tool = 'ccleaner' }
    @{ label = 'LocalAppData Temp';           path = "$env:LOCALAPPDATA\Temp";                             risk = 'green';  tool = 'ccleaner' }
    @{ label = 'Recycle Bin';                 path = 'C:\$Recycle.Bin';                                    risk = 'green';  tool = 'windows-builtin' }
)
$tempFindings = foreach ($z in $tempZones) {
    $size = _Get-FolderSize -Path $z.path -TimeoutSeconds 60
    if ($size -gt 0) {
        _New-Finding -Category 'temp' -Label $z.label -Path $z.path -SizeBytes $size `
            -Risk $z.risk -ToolHint $z.tool `
            -Recommendation ("Récupérable {0}" -f (_Format-Size $size))
    }
}

_Write-Phase "scan_disk_usage : archives > 500 MB (dossiers de stockage utilisateur)"
$archiveExts = '*.zip','*.rar','*.7z','*.iso','*.tar','*.tar.gz','*.tgz','*.dmg','*.vhd','*.vhdx'
# Scan limité aux dossiers de stockage habituels (pas AppData, pas tout le profil)
$archiveZones = @(
    "$env:USERPROFILE\Downloads"
    "$env:USERPROFILE\Documents"
    "$env:USERPROFILE\Desktop"
    "$env:USERPROFILE\Pictures"
    "$env:USERPROFILE\Videos"
    "$env:USERPROFILE\Music"
) | Where-Object { Test-Path -LiteralPath $_ }

$archives = foreach ($zone in $archiveZones) {
    foreach ($ext in $archiveExts) {
        Get-ChildItem -LiteralPath $zone -Filter $ext -Recurse -File -Force `
            -ErrorAction SilentlyContinue -Depth 5 | Where-Object {
                $_.Length -gt 500MB -and ($_.Attributes -notmatch 'Offline|RecallOnOpen|RecallOnDataAccess')
            }
    }
}
$archiveFindings = $archives | Sort-Object Length -Descending | Select-Object -First $TopN | ForEach-Object {
    _New-Finding -Category 'archive' -Label $_.Extension.TrimStart('.') -Path $_.FullName `
        -SizeBytes $_.Length -Risk 'yellow' -ToolHint '7zip' `
        -Recommendation "Archive lourde — vérifier si encore utile, sinon extraire ou supprimer"
}

_Report-ScanStats

$output = [PSCustomObject]@{
    category    = 'disk_usage'
    machine     = $machine
    drive       = $drive
    top_folders = $userTop
    temp_zones  = $tempFindings
    archives    = $archiveFindings
    totals      = [PSCustomObject]@{
        recoverable_temp_gb = [math]::Round((($tempFindings | Measure-Object size_bytes -Sum).Sum / 1GB), 2)
        archives_count      = ($archiveFindings | Measure-Object).Count
        archives_total_gb   = [math]::Round((($archiveFindings | Measure-Object size_bytes -Sum).Sum / 1GB), 2)
    }
}

$output | ConvertTo-Json -Depth 8
