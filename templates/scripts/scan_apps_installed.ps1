# scan_apps_installed.ps1 — apps installées (Registry + Winget + Appx) + dernière utilisation
# Read-only
param(
    [int]$TopN = 50
)

. "$PSScriptRoot\_common.ps1"

_Write-Phase "scan_apps_installed : Registry Uninstall (HKLM 32 + 64 + HKCU)"

$uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$registryApps = foreach ($key in $uninstallKeys) {
    Get-ItemProperty -Path $key -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -and -not $_.SystemComponent -and -not $_.ParentKeyName
    } | ForEach-Object {
        [PSCustomObject]@{
            name        = $_.DisplayName
            version     = $_.DisplayVersion
            publisher   = $_.Publisher
            install_date = $_.InstallDate
            install_loc  = $_.InstallLocation
            size_kb      = if ($_.EstimatedSize) { [int]$_.EstimatedSize } else { 0 }
            source       = 'registry'
        }
    }
}

# Dédup par nom
$registryAppsUnique = $registryApps | Sort-Object name -Unique

_Write-Phase "scan_apps_installed : Get-AppxPackage (UWP)"
$appxApps = @()
try {
    $appxApps = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object {
        -not $_.IsFramework -and $_.SignatureKind -ne 'System'
    } | ForEach-Object {
        [PSCustomObject]@{
            name      = $_.Name
            version   = $_.Version
            publisher = $_.Publisher
            install_loc = $_.InstallLocation
            source    = 'appx'
        }
    }
} catch {
    _Warn "Get-AppxPackage erreur : $_"
}

_Write-Phase "scan_apps_installed : winget list (si dispo)"
$wingetApps = @()
if (Get-Command winget -ErrorAction SilentlyContinue) {
    try {
        # winget produit du texte tabulaire — on garde brut, on parsera côté report
        $wingetRaw = & winget list --accept-source-agreements --disable-interactivity 2>$null
        $wingetApps = @($wingetRaw)
    } catch {
        _Warn "winget list erreur : $_"
    }
}

_Write-Phase "scan_apps_installed : tailles dossiers grosses apps"
$largeApps = $registryAppsUnique | Where-Object {
    $_.install_loc -and (Test-Path -LiteralPath $_.install_loc) -and ($_.size_kb -gt 500000)  # > 500 MB rapporté par registry
} | Sort-Object size_kb -Descending | Select-Object -First $TopN | ForEach-Object {
    [PSCustomObject]@{
        name       = $_.name
        path       = $_.install_loc
        size_gb    = [math]::Round($_.size_kb / 1MB, 2)
        size_human = _Format-Size ([long]$_.size_kb * 1KB)
        publisher  = $_.publisher
        tool_hint  = 'wingetui'
    }
}

_Write-Phase "scan_apps_installed : UserAssist (dernière utilisation, ROT13 décodé)"
function ConvertFrom-Rot13 {
    param([string]$Text)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $Text.ToCharArray()) {
        $code = [int]$c
        if ($code -ge 65 -and $code -le 90)  { $code = (($code - 65 + 13) % 26) + 65 }
        elseif ($code -ge 97 -and $code -le 122) { $code = (($code - 97 + 13) % 26) + 97 }
        [void]$sb.Append([char]$code)
    }
    return $sb.ToString()
}

$rarelyUsed = @()
$userAssistRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist'
try {
    $cutoffMonths = 6
    $cutoff = (Get-Date).AddMonths(-$cutoffMonths)
    $guidKeys = Get-ChildItem -LiteralPath $userAssistRoot -ErrorAction SilentlyContinue
    foreach ($guid in $guidKeys) {
        $countKey = "$($guid.PSPath)\Count"
        if (-not (Test-Path -LiteralPath $countKey)) { continue }
        $values = (Get-Item -LiteralPath $countKey).Property
        foreach ($val in $values) {
            $decoded = ConvertFrom-Rot13 $val
            if ($decoded -notmatch '\.(exe|lnk)$') { continue }
            # Le binaire UserAssist contient un timestamp FILETIME aux offsets 60-67
            $raw = (Get-ItemProperty -LiteralPath $countKey -Name $val -ErrorAction SilentlyContinue).$val
            if ($raw -and $raw.Length -ge 68) {
                try {
                    $ft = [BitConverter]::ToInt64($raw, 60)
                    if ($ft -gt 0) {
                        $lastUsed = [DateTime]::FromFileTime($ft)
                        if ($lastUsed -lt $cutoff -and $lastUsed.Year -gt 2000) {
                            $rarelyUsed += [PSCustomObject]@{
                                exe       = $decoded
                                last_used = $lastUsed.ToString('yyyy-MM-dd')
                            }
                        }
                    }
                } catch { continue }
            }
        }
    }
    $rarelyUsed = $rarelyUsed | Sort-Object last_used | Select-Object -First $TopN -Unique
} catch {
    _Warn "UserAssist decode erreur : $_"
}

_Report-ScanStats

$output = [PSCustomObject]@{
    category      = 'apps_installed'
    registry_apps = @($registryAppsUnique)
    appx_apps     = @($appxApps)
    winget_raw    = $wingetApps
    large_apps    = @($largeApps)
    rarely_used   = @($rarelyUsed)
    totals = [PSCustomObject]@{
        registry_count = ($registryAppsUnique | Measure-Object).Count
        appx_count     = ($appxApps | Measure-Object).Count
        large_count    = ($largeApps | Measure-Object).Count
        rarely_used_count = ($rarelyUsed | Measure-Object).Count
        rarely_used_cutoff_months = 6
    }
}

_Emit-Json $output -Depth 8
