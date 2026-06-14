# scan_duplicates.ps1 — doublons fichiers > 10 MB par (Name, Length)
# Heuristique volontairement légère (pas de hash). Read-only.
param(
    [int]$TopN = 50,
    [int]$MinSizeMB = 10
)

. "$PSScriptRoot\_common.ps1"

_Write-Phase "scan_duplicates : collecte fichiers"

$zones = @(
    "$env:USERPROFILE\Downloads"
    "$env:USERPROFILE\Documents"
    "$env:USERPROFILE\Desktop"
    "$env:USERPROFILE\Pictures"
    "$env:USERPROFILE\Videos"
    "$env:USERPROFILE\Music"
) | Where-Object { Test-Path -LiteralPath $_ }

$minBytes = $MinSizeMB * 1MB
$allFiles = New-Object System.Collections.Generic.List[object]
$scannedCount = 0

foreach ($zone in $zones) {
    _Write-Phase ("  - {0}" -f $zone)
    $files = Get-ChildItem -LiteralPath $zone -Recurse -File -Force `
        -ErrorAction SilentlyContinue | Where-Object {
            $_.Length -ge $minBytes -and ($_.Attributes -notmatch 'Offline|RecallOnOpen|RecallOnDataAccess')
        }
    foreach ($f in $files) {
        $allFiles.Add([PSCustomObject]@{
            Name     = $f.Name
            Length   = $f.Length
            FullName = $f.FullName
            LastMod  = $f.LastWriteTime
        })
        $scannedCount++
    }
}

_Write-Phase ("scan_duplicates : {0} fichiers scannés > {1} MB" -f $scannedCount, $MinSizeMB)

_Write-Phase "scan_duplicates : groupement par (Name, Length)"
$groups = $allFiles | Group-Object -Property Name, Length |
    Where-Object { $_.Count -gt 1 } |
    Sort-Object { $_.Group[0].Length * ($_.Count - 1) } -Descending |
    Select-Object -First $TopN

$findings = foreach ($g in $groups) {
    $first = $g.Group[0]
    $wasted = $first.Length * ($g.Count - 1)
    [PSCustomObject]@{
        name           = $first.Name
        size_bytes     = $first.Length
        size_human     = _Format-Size $first.Length
        copies         = @($g.Group | ForEach-Object { $_.FullName })
        copy_count     = $g.Count
        wasted_bytes   = $wasted
        wasted_human   = _Format-Size $wasted
        wasted_gb      = _To-GB $wasted
        risk           = 'yellow'
        tool_hint      = 'manual'
        recommendation = "Candidats doublons (nom+taille). Certifier avec dupeGuru/AllDup avant suppression."
    }
}

$totalWasted = ($findings | Measure-Object wasted_bytes -Sum).Sum

_Report-ScanStats

$output = [PSCustomObject]@{
    category       = 'duplicates'
    scanned_files  = $scannedCount
    min_size_mb    = $MinSizeMB
    groups         = $findings
    totals         = [PSCustomObject]@{
        groups_count  = ($findings | Measure-Object).Count
        wasted_gb     = [math]::Round($totalWasted / 1GB, 2)
    }
}

$output | ConvertTo-Json -Depth 8
