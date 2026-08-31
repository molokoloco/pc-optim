# scan_dev_caches.ps1 — caches dev (npm/pip/yarn/pnpm/cargo/go/Maven/Gradle/IDE) + Docker
# Read-only
param(
    [int]$TopN = 50
)

. "$PSScriptRoot\_common.ps1"

_Write-Phase "scan_dev_caches : package managers"

$caches = @(
    @{ tool = 'npm';         path = "$env:APPDATA\npm-cache";              recommendation = "npm cache clean --force"; risk = 'green' }
    @{ tool = 'pnpm';        path = "$env:LOCALAPPDATA\pnpm-cache";        recommendation = "pnpm store prune"; risk = 'green' }
    @{ tool = 'pnpm-store';  path = "$env:LOCALAPPDATA\pnpm\store";        recommendation = "pnpm store prune"; risk = 'green' }
    @{ tool = 'yarn';        path = "$env:LOCALAPPDATA\Yarn\Cache";        recommendation = "yarn cache clean"; risk = 'green' }
    @{ tool = 'pip';         path = "$env:LOCALAPPDATA\pip\Cache";         recommendation = "pip cache purge"; risk = 'green' }
    @{ tool = 'cargo';       path = "$env:USERPROFILE\.cargo\registry";   recommendation = "cargo cache --autoclean (via cargo-cache)"; risk = 'green' }
    @{ tool = 'go-mod';      path = "$env:USERPROFILE\go\pkg\mod";        recommendation = "go clean -modcache"; risk = 'green' }
    @{ tool = 'gradle';      path = "$env:USERPROFILE\.gradle\caches";    recommendation = "gradle --stop puis supprimer caches"; risk = 'green' }
    @{ tool = 'maven';       path = "$env:USERPROFILE\.m2\repository";    recommendation = "rm -rf ~/.m2/repository — sera reDL"; risk = 'yellow' }
    @{ tool = 'vscode-cache';path = "$env:APPDATA\Code\Cache";             recommendation = "Quit VS Code puis supprimer"; risk = 'green' }
    @{ tool = 'vscode-cacheData';path = "$env:APPDATA\Code\CachedData";    recommendation = "Quit VS Code puis supprimer"; risk = 'green' }
    @{ tool = 'jetbrains';   path = "$env:LOCALAPPDATA\JetBrains";        recommendation = "Help → Delete Caches & Restart"; risk = 'yellow' }
    @{ tool = 'nuget';       path = "$env:USERPROFILE\.nuget\packages";   recommendation = "dotnet nuget locals all --clear"; risk = 'green' }
    @{ tool = 'composer';    path = "$env:LOCALAPPDATA\Composer";          recommendation = "composer clear-cache"; risk = 'green' }
    @{ tool = 'electron';    path = "$env:LOCALAPPDATA\electron\Cache";    recommendation = "Supprimer cache binaries Electron"; risk = 'green' }
    @{ tool = 'puppeteer';   path = "$env:USERPROFILE\.cache\puppeteer";   recommendation = "Cache chromium Puppeteer — réinstall sur prochain npm i"; risk = 'green' }
)

$cacheFindings = foreach ($c in $caches) {
    if (-not (Test-Path -LiteralPath $c.path)) { continue }
    _Write-Phase ("  - {0}" -f $c.tool)
    $size = _Get-FolderSize -Path $c.path -TimeoutSeconds 45
    if ($size -gt 50MB) {
        _New-Finding -Category 'package_cache' -Label $c.tool -Path $c.path -SizeBytes $size `
            -Risk $c.risk -ToolHint 'manual' `
            -Recommendation $c.recommendation
    }
}

_Write-Phase "scan_dev_caches : Docker (si présent)"
$docker = [PSCustomObject]@{ available = $false }
if (Get-Command docker -ErrorAction SilentlyContinue) {
    try {
        $dfRaw = & docker system df --format '{{json .}}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $dfRaw) {
            $entries = $dfRaw | Where-Object { $_ } | ForEach-Object {
                try { $_ | ConvertFrom-Json } catch { $null }
            } | Where-Object { $_ -ne $null }
            $docker = [PSCustomObject]@{
                available = $true
                df        = @($entries)
            }
        }
    } catch {
        _Warn "docker system df erreur : $_"
    }
}

_Write-Phase "scan_dev_caches : node_modules orphelins (> 6 mois, > 100 MB)"
$cutoff = (Get-Date).AddMonths(-6)
$searchRoots = @($env:USERPROFILE, "$env:USERPROFILE\Documents", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Projects", "$env:USERPROFILE\dev") |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Unique

$nodeModulesFindings = @()
foreach ($root in $searchRoots) {
    $nmDirs = Get-ChildItem -LiteralPath $root -Directory -Recurse -Force `
        -Filter 'node_modules' -ErrorAction SilentlyContinue -Depth 6
    foreach ($nm in $nmDirs) {
        try {
            if ($nm.LastWriteTime -lt $cutoff) {
                $size = _Get-FolderSize -Path $nm.FullName -TimeoutSeconds 45
                if ($size -gt 100MB) {
                    $nodeModulesFindings += _New-Finding -Category 'node_modules' -Label 'orphan' `
                        -Path $nm.FullName -SizeBytes $size -Risk 'yellow' -ToolHint 'manual' `
                        -Recommendation ("Pas touché depuis {0:yyyy-MM-dd} — `rm -rf node_modules` réinstallable" -f $nm.LastWriteTime)
                }
            }
        } catch { continue }
    }
}
$nodeModulesFindings = $nodeModulesFindings | Sort-Object size_bytes -Descending | Select-Object -First $TopN

_Report-ScanStats

$output = [PSCustomObject]@{
    category       = 'dev_caches'
    package_caches = $cacheFindings
    docker         = $docker
    node_modules_orphans = $nodeModulesFindings
    totals = [PSCustomObject]@{
        package_total_gb     = [math]::Round((($cacheFindings | Measure-Object size_bytes -Sum).Sum / 1GB), 2)
        node_modules_total_gb = [math]::Round((($nodeModulesFindings | Measure-Object size_bytes -Sum).Sum / 1GB), 2)
    }
}

_Emit-Json $output -Depth 8
