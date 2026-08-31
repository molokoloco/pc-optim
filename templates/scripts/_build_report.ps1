# _build_report.ps1 — assemble les 6 JSON + template + mapping en rapport Markdown
# Seule écriture autorisée du skill : le fichier de rapport final passé en -OutFile
param(
    [Parameter(Mandatory)][string]$InputDir,
    [Parameter(Mandatory)][string]$Template,
    [Parameter(Mandatory)][string]$Mapping,
    [Parameter(Mandatory)][string]$OutFile
)

. "$PSScriptRoot\_common.ps1"

$SKILL_VERSION = '1.1.0'

# --- Helpers locaux ---
function Load-Json {
    param([string]$Name)
    $p = Join-Path $InputDir "_$Name.json"
    if (-not (Test-Path -LiteralPath $p)) {
        _Warn "JSON manquant : $p"
        return $null
    }
    try {
        $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8
        if (-not $raw -or $raw.Trim().Length -eq 0) {
            _Warn "JSON vide : $p"
            return $null
        }
        return $raw | ConvertFrom-Json
    } catch {
        _Warn "JSON parse erreur ${p} : $_"
        return $null
    }
}

function Score-Section {
    param([double]$GainGB)
    if ($GainGB -ge 20) { return '🔴 cleanup recommandé' }
    if ($GainGB -ge 5)  { return '🟡 cleanup utile' }
    if ($GainGB -gt 0)  { return '🟢 propre' }
    return '— rien à signaler'
}

function Risk-Icon {
    param([string]$Risk)
    switch ($Risk) {
        'green'  { return '🟢' }
        'yellow' { return '🟡' }
        'red'    { return '🔴' }
        default  { return '⚪' }
    }
}

function Esc-Md {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace '\|','\|' -replace '\r?\n',' ')
}

function Get-ToolName {
    param([string]$Hint)
    if (-not $Hint) { return '—' }
    if ($mapping.tools.PSObject.Properties.Name -contains $Hint) {
        return $mapping.tools.$Hint.name
    }
    return $Hint
}

# --- Chargement ---
_Write-Phase "build_report : chargement JSON"
$disk = Load-Json 'scan_disk_usage'
$ai   = Load-Json 'scan_ai_models'
$dev  = Load-Json 'scan_dev_caches'
$dup  = Load-Json 'scan_duplicates'
$apps = Load-Json 'scan_apps_installed'
$net  = Load-Json 'scan_network_security'

$mappingRaw = Get-Content -LiteralPath $Mapping -Raw -Encoding UTF8
$mapping = $mappingRaw | ConvertFrom-Json

# --- Gains par section ---
$gainDisk = if ($disk) { [double]$disk.totals.recoverable_temp_gb + [double]$disk.totals.archives_total_gb } else { 0 }
$gainAi   = if ($ai)   { [double]$ai.totals.total_gb } else { 0 }
$gainDev  = if ($dev)  { [double]$dev.totals.package_total_gb + [double]$dev.totals.node_modules_total_gb } else { 0 }
$gainDup  = if ($dup)  { [double]$dup.totals.wasted_gb } else { 0 }
$gainTotal = [math]::Round($gainDisk + $gainAi + $gainDev + $gainDup, 2)

# --- Top 3 actions ---
$candidateActions = New-Object System.Collections.Generic.List[object]
if ($disk -and $disk.totals.recoverable_temp_gb -gt 1) {
    $candidateActions.Add([PSCustomObject]@{
        gain = [double]$disk.totals.recoverable_temp_gb
        desc = "Vider Temp + SoftwareDistribution + corbeille"
        tool = (Get-ToolName 'windows-builtin')
    })
}
if ($ai -and $ai.totals.total_gb -gt 5) {
    $candidateActions.Add([PSCustomObject]@{
        gain = [double]$ai.totals.total_gb
        desc = "Auditer modèles IA locaux ($($ai.totals.providers_count) provider(s), $($ai.totals.orphans_count) orphelin(s))"
        tool = (Get-ToolName 'ollama-cli')
    })
}
if ($dev -and ($dev.totals.package_total_gb + $dev.totals.node_modules_total_gb) -gt 3) {
    $candidateActions.Add([PSCustomObject]@{
        gain = [double]($dev.totals.package_total_gb + $dev.totals.node_modules_total_gb)
        desc = "Purger caches dev (npm/pip/yarn/Docker) + node_modules orphelins"
        tool = "CLI tools (npm cache clean / docker system prune)"
    })
}
if ($dup -and $dup.totals.wasted_gb -gt 1) {
    $candidateActions.Add([PSCustomObject]@{
        gain = [double]$dup.totals.wasted_gb
        desc = "Vérifier $($dup.totals.groups_count) groupe(s) de doublons (Downloads, Documents…)"
        tool = (Get-ToolName 'dupeguru')
    })
}
if ($disk -and $disk.totals.archives_total_gb -gt 2) {
    $candidateActions.Add([PSCustomObject]@{
        gain = [double]$disk.totals.archives_total_gb
        desc = "Trier $($disk.totals.archives_count) archive(s) lourde(s) (.zip/.iso/.7z)"
        tool = (Get-ToolName '7zip')
    })
}

$top3 = $candidateActions | Sort-Object gain -Descending | Select-Object -First 3
$topActionsMd = if ($top3.Count -gt 0) {
    ($top3 | ForEach-Object -Begin { $i = 0 } -Process {
        $i++
        "$i. **$($_.desc)** — gain ~$([math]::Round($_.gain,1)) GB · outil : *$($_.tool)*"
    }) -join "`n"
} else {
    "_Rien d'urgent à signaler._"
}

# --- §1 Disk ---
$diskTopMd = if ($disk -and $disk.top_folders) {
    $rows = $disk.top_folders | ForEach-Object {
        "| ``$(Esc-Md $_.path)`` | $($_.size_human) |"
    }
    "| Dossier | Taille |`n|---|---|`n" + ($rows -join "`n")
} else { "_(scan disk skippé ou aucun dossier remontable)_" }

$diskTempMd = if ($disk -and $disk.temp_zones) {
    $rows = $disk.temp_zones | ForEach-Object {
        "| $(Risk-Icon $_.risk) | $($_.label) | ``$(Esc-Md $_.path)`` | $($_.size_human) | $(Get-ToolName $_.tool_hint) |"
    }
    "| Risque | Zone | Chemin | Taille | Outil |`n|---|---|---|---|---|`n" + ($rows -join "`n")
} else { "_(aucune zone temp à signaler)_" }

$diskArchMd = if ($disk -and $disk.archives -and ($disk.archives | Measure-Object).Count -gt 0) {
    $rows = $disk.archives | ForEach-Object {
        "| ``$(Esc-Md $_.path)`` | $($_.size_human) | $(Risk-Icon $_.risk) |"
    }
    "| Fichier | Taille | Risque |`n|---|---|---|`n" + ($rows -join "`n")
} else { "_(aucune archive > 500 MB)_" }

# --- §2 AI ---
$aiProviderMd = if ($ai -and $ai.by_provider -and $ai.by_provider.PSObject.Properties.Count -gt 0) {
    $rows = $ai.by_provider.PSObject.Properties | ForEach-Object {
        $name = $_.Name; $info = $_.Value
        $files = if ($info.top_files -and $info.top_files.Count -gt 0) {
            "<br>" + (($info.top_files | Select-Object -First 5 | ForEach-Object { "• $($_.name) ($($_.size_human))" }) -join "<br>")
        } else { '' }
        "| **$name** | ``$(Esc-Md $info.path)`` | $($info.size_human) | $files |"
    }
    "| Provider | Chemin | Taille | Top fichiers |`n|---|---|---|---|`n" + ($rows -join "`n")
} else { "_(aucun provider IA local détecté)_" }

$aiOrphanMd = if ($ai -and $ai.orphan_files -and ($ai.orphan_files | Measure-Object).Count -gt 0) {
    $rows = $ai.orphan_files | ForEach-Object {
        "| ``$(Esc-Md $_.path)`` | $($_.size_human) | $(Risk-Icon $_.risk) |"
    }
    "| Fichier | Taille | Risque |`n|---|---|---|`n" + ($rows -join "`n")
} else { "_(aucun fichier orphelin)_" }

# --- §3 Dev caches ---
$devCacheMd = if ($dev -and $dev.package_caches -and ($dev.package_caches | Measure-Object).Count -gt 0) {
    $rows = $dev.package_caches | ForEach-Object {
        "| $(Risk-Icon $_.risk) | **$($_.label)** | ``$(Esc-Md $_.path)`` | $($_.size_human) | $(Esc-Md $_.recommendation) |"
    }
    "| Risque | Tool | Chemin | Taille | Commande |`n|---|---|---|---|---|`n" + ($rows -join "`n")
} else { "_(aucun cache dev > 50 MB)_" }

$dockerMd = if ($dev -and $dev.docker -and $dev.docker.available) {
    if ($dev.docker.df) {
        $rows = $dev.docker.df | ForEach-Object {
            "| $($_.Type) | $($_.TotalCount) | $($_.Size) | $($_.Reclaimable) |"
        }
        "| Type | Total | Taille | Récupérable |`n|---|---|---|---|`n" + ($rows -join "`n") + "`n`n_Commande : `docker system prune -a --volumes`_"
    } else { "_Docker installé, df vide_" }
} else { "_(Docker non détecté)_" }

$nodeModulesMd = if ($dev -and $dev.node_modules_orphans -and ($dev.node_modules_orphans | Measure-Object).Count -gt 0) {
    $rows = $dev.node_modules_orphans | ForEach-Object {
        "| ``$(Esc-Md $_.path)`` | $($_.size_human) | $(Esc-Md $_.recommendation) |"
    }
    "| Chemin | Taille | Recommandation |`n|---|---|---|`n" + ($rows -join "`n")
} else { "_(aucun node_modules orphelin)_" }

# --- §4 Duplicates ---
$duplicatesMd = if ($dup -and $dup.groups -and ($dup.groups | Measure-Object).Count -gt 0) {
    $blocks = $dup.groups | ForEach-Object {
        $copies = ($_.copies | ForEach-Object { "  - ``$_``" }) -join "`n"
        "**$($_.name)** — $($_.copy_count) copies × $($_.size_human) → gain ~$($_.wasted_human)`n`n$copies"
    }
    ($blocks -join "`n`n---`n`n")
} else { "_(aucun doublon candidat)_" }

# --- §5 Apps ---
$appsLargeMd = if ($apps -and $apps.large_apps -and ($apps.large_apps | Measure-Object).Count -gt 0) {
    $rows = $apps.large_apps | ForEach-Object {
        "| $(Esc-Md $_.name) | ``$(Esc-Md $_.path)`` | $($_.size_human) | $(Esc-Md $_.publisher) |"
    }
    "| App | Install location | Taille | Éditeur |`n|---|---|---|---|`n" + ($rows -join "`n")
} else { "_(aucune app > 500 MB selon registry)_" }

$appsRarelyMd = if ($apps -and $apps.rarely_used -and ($apps.rarely_used | Measure-Object).Count -gt 0) {
    $rows = $apps.rarely_used | ForEach-Object {
        "| ``$(Esc-Md $_.exe)`` | $($_.last_used) |"
    }
    "| Exécutable | Dernière utilisation |`n|---|---|`n" + ($rows -join "`n")
} else { "_(aucune app peu utilisée détectée — UserAssist vide ou récent)_" }

# --- §6 Network ---
$netDnsMd = if ($net -and $net.dns -and ($net.dns | Measure-Object).Count -gt 0) {
    $rows = $net.dns | ForEach-Object {
        "| $(Esc-Md $_.interface) | $($_.server) | $(Esc-Md $_.provider) |"
    }
    "| Interface | Serveur | Provider |`n|---|---|---|`n" + ($rows -join "`n")
} else { "_(aucun DNS configuré ou scan skippé)_" }

$netVpnMd = if ($net -and $net.vpn -and ($net.vpn | Measure-Object).Count -gt 0) {
    $rows = $net.vpn | ForEach-Object {
        "| $(Esc-Md $_.name) | $(Esc-Md $_.server) | $(Esc-Md $_.tunnel_type) | $(Esc-Md $_.status) |"
    }
    "| Nom | Serveur | Tunnel | Statut |`n|---|---|---|---|`n" + ($rows -join "`n")
} else { "_(aucune connexion VPN configurée)_" }

$netProxyWinhttp = if ($net -and $net.proxy.winhttp) { $net.proxy.winhttp } else { '(scan skippé)' }
$netProxyWininet = if ($net -and $net.proxy.wininet) {
    $w = $net.proxy.wininet
    "- ProxyEnable : $($w.ProxyEnable)`n- ProxyServer : $($w.ProxyServer)`n- AutoConfigURL : $($w.AutoConfigURL)"
} else { "_(aucun proxy WinINET configuré)_" }

$netPortsMd = if ($net -and $net.ports_listening -and ($net.ports_listening | Measure-Object).Count -gt 0) {
    $rows = $net.ports_listening | ForEach-Object {
        "| $($_.local_port) | $(Esc-Md $_.local_addr) | $($_.pid) | $(Esc-Md $_.process_name) | ``$(Esc-Md $_.process_path)`` |"
    }
    "| Port | Adresse | PID | Process | Chemin |`n|---|---|---|---|---|`n" + ($rows -join "`n")
} else { "_(aucun port en écoute — ou Get-NetTCPConnection indisponible en session non-interactive)_" }

$netDefenderMd = if ($net -and $net.defender.available) {
    $d = $net.defender
    @"
| Réglage | Valeur |
|---|---|
| Real-time scan activé | $($d.real_time_enabled) |
| Antivirus actif | $($d.antivirus_enabled) |
| Antispyware actif | $($d.antispyware_enabled) |
| Âge signatures (jours) | $($d.signature_age_days) |
| Dernier scan rapide | $($d.last_quick_scan) |
| Dernier scan complet | $($d.last_full_scan) |
| Tamper Protection | $($d.tamper_protection) |
| Nb exclusions chemins | $(($d.exclusion_path | Measure-Object).Count) |
| Nb exclusions extensions | $(($d.exclusion_extension | Measure-Object).Count) |
| Nb exclusions process | $(($d.exclusion_process | Measure-Object).Count) |
"@
} else { "_(Defender non interrogeable — module ConfigDefender absent ?)_" }

$netFirewallMd = if ($net -and $net.firewall -and ($net.firewall | Measure-Object).Count -gt 0) {
    $rows = $net.firewall | ForEach-Object {
        "| $($_.profile) | $($_.enabled) | $($_.default_inbound) | $($_.default_outbound) |"
    }
    "| Profil | Activé | Inbound par défaut | Outbound par défaut |`n|---|---|---|---|`n" + ($rows -join "`n")
} else { "_(profils firewall non lisibles)_" }

$netConnMd = if ($net -and $net.connectivity) {
    $c = $net.connectivity
    @"
- Cloudflare 1.1.1.1 : ping=$($c.cloudflare_ping_ok) latency=$($c.cloudflare_ping_ms) ms
- Google 8.8.8.8 : ping=$($c.google_ping_ok) latency=$($c.google_ping_ms) ms
- Interface utilisée : $($c.interface_alias)
"@
} else { "_(test connexion skippé)_" }

$netAdaptersMd = if ($net -and $net.adapters -and ($net.adapters | Measure-Object).Count -gt 0) {
    $rows = $net.adapters | ForEach-Object {
        "| $(Esc-Md $_.name) | $(Esc-Md $_.type) | $(Esc-Md $_.link_speed) | $($_.mac) |"
    }
    "| Carte | Type | Débit | MAC |`n|---|---|---|---|`n" + ($rows -join "`n")
} else { "_(aucune carte active)_" }

# --- Quick wins table ---
$quickWinsRows = New-Object System.Collections.Generic.List[string]
if ($disk -and $disk.totals.recoverable_temp_gb -gt 0.5) {
    $quickWinsRows.Add("| Temp système & cache Windows | 🟢 | ~$($disk.totals.recoverable_temp_gb) GB | $(Get-ToolName 'windows-builtin') | Paramètres → Système → Stockage → Fichiers temporaires |")
}
if ($disk -and $disk.totals.archives_count -gt 0) {
    $quickWinsRows.Add("| Archives lourdes ($($disk.totals.archives_count)) | 🟡 | ~$($disk.totals.archives_total_gb) GB | $(Get-ToolName '7zip') | Trier .zip/.rar/.iso dans Downloads |")
}
if ($ai -and $ai.totals.providers_count -gt 0) {
    $quickWinsRows.Add("| Modèles IA ($($ai.totals.providers_count) provider) | 🟡 | ~$($ai.totals.total_gb) GB | $(Get-ToolName 'ollama-cli') | ``ollama list`` puis ``ollama rm`` les inutiles |")
}
if ($dev -and ($dev.totals.package_total_gb + $dev.totals.node_modules_total_gb) -gt 0.5) {
    $quickWinsRows.Add("| Caches dev | 🟢 | ~$([math]::Round($dev.totals.package_total_gb + $dev.totals.node_modules_total_gb, 2)) GB | CLI dédié | ``npm cache clean --force`` / ``docker system prune -a --volumes`` |")
}
if ($dup -and $dup.totals.groups_count -gt 0) {
    $quickWinsRows.Add("| Doublons candidats ($($dup.totals.groups_count) groupes) | 🟡 | ~$($dup.totals.wasted_gb) GB | $(Get-ToolName 'dupeguru') | Pointer dupeGuru sur Downloads/Documents |")
}
if ($apps -and $apps.totals.rarely_used_count -gt 5) {
    $quickWinsRows.Add("| Apps peu utilisées ($($apps.totals.rarely_used_count)) | 🟡 | indicatif | $(Get-ToolName 'wingetui') | Désinstaller proprement via WingetUI |")
}
$quickWinsRows.Add("| RAM saturée après build/VM | 🟢 | n/a | $(Get-ToolName 'memorycleaner') | Lancer Windows Memory Cleaner |")
$quickWinsRows.Add("| Pilotes / BIOS obsolètes | 🟢 | n/a | $(Get-ToolName 'oem') | Lancer l'utilitaire fabricant |")

$quickWinsMd = "| Finding | Risque | Gain | Outil | Action |`n|---|---|---|---|---|`n" + ($quickWinsRows -join "`n")

# --- Substitution template ---
_Write-Phase "build_report : substitution template"
$tpl = Get-Content -LiteralPath $Template -Raw -Encoding UTF8

$machine = if ($disk) { $disk.machine } else { _Get-MachineInfo }
$driveInfo = if ($disk) { $disk.drive } else { _Get-DriveInfo -DriveLetter 'C' }

$substitutions = @{
    '{{DATE}}'                = (Get-Date).ToString('yyyy-MM-dd')
    '{{SKILL_VERSION}}'       = $SKILL_VERSION
    '{{HOSTNAME}}'            = $machine.hostname
    '{{OS_CAPTION}}'          = $machine.os_caption
    '{{OS_VERSION}}'          = $machine.os_version
    '{{CPU}}'                 = $machine.cpu
    '{{RAM_GB}}'              = "$($machine.ram_gb)"
    '{{IS_ADMIN}}'            = if ($machine.is_admin) { 'oui' } else { 'non (scan dégradé sur certains points)' }
    '{{USERPROFILE}}'         = $env:USERPROFILE
    '{{DISK_VOLUME_NAME}}'    = $driveInfo.volume_name
    '{{DISK_FS}}'             = $driveInfo.filesystem
    '{{DISK_SIZE_GB}}'        = "$($driveInfo.size_gb)"
    '{{DISK_USED_GB}}'        = "$($driveInfo.used_gb)"
    '{{DISK_USED_PCT}}'       = "$($driveInfo.used_pct)"
    '{{DISK_FREE_GB}}'        = "$($driveInfo.free_gb)"
    '{{GAIN_DISK_GB}}'        = "$gainDisk"
    '{{GAIN_AI_GB}}'          = "$gainAi"
    '{{GAIN_DEV_GB}}'         = "$gainDev"
    '{{GAIN_DUP_GB}}'         = "$gainDup"
    '{{GAIN_TOTAL_GB}}'       = "$gainTotal"
    '{{SCORE_DISK}}'          = Score-Section $gainDisk
    '{{SCORE_AI}}'            = Score-Section $gainAi
    '{{SCORE_DEV}}'           = Score-Section $gainDev
    '{{SCORE_DUP}}'           = Score-Section $gainDup
    '{{SCORE_APP}}'           = if ($apps) { "$($apps.totals.registry_count) apps répertoriées" } else { 'scan skippé' }
    '{{SCORE_NET}}'           = if ($net -and $net.defender.real_time_enabled) { '🟢 Defender actif' } elseif ($net) { '🟡 vérifier réglages' } else { 'scan skippé' }
    '{{TOP_ACTIONS}}'         = $topActionsMd
    '{{DISK_TOP_FOLDERS}}'    = $diskTopMd
    '{{DISK_TEMP_ZONES}}'     = $diskTempMd
    '{{DISK_ARCHIVES}}'       = $diskArchMd
    '{{AI_BY_PROVIDER}}'      = $aiProviderMd
    '{{AI_ORPHANS}}'          = $aiOrphanMd
    '{{DEV_PACKAGE_CACHES}}'  = $devCacheMd
    '{{DEV_DOCKER}}'          = $dockerMd
    '{{DEV_NODE_MODULES}}'    = $nodeModulesMd
    '{{DUPLICATES}}'          = $duplicatesMd
    '{{APPS_REGISTRY_COUNT}}' = if ($apps) { "$($apps.totals.registry_count)" } else { '0' }
    '{{APPS_APPX_COUNT}}'     = if ($apps) { "$($apps.totals.appx_count)" } else { '0' }
    '{{APPS_LARGE}}'          = $appsLargeMd
    '{{APPS_RARELY_USED}}'    = $appsRarelyMd
    '{{NET_DNS}}'             = $netDnsMd
    '{{NET_VPN}}'             = $netVpnMd
    '{{NET_PROXY_WINHTTP}}'   = $netProxyWinhttp
    '{{NET_PROXY_WININET}}'   = $netProxyWininet
    '{{NET_PORTS}}'           = $netPortsMd
    '{{NET_DEFENDER}}'        = $netDefenderMd
    '{{NET_FIREWALL}}'        = $netFirewallMd
    '{{NET_CONNECTIVITY}}'    = $netConnMd
    '{{NET_ADAPTERS}}'        = $netAdaptersMd
    '{{QUICK_WINS_TABLE}}'    = $quickWinsMd
}

foreach ($k in $substitutions.Keys) {
    $tpl = $tpl.Replace($k, [string]$substitutions[$k])
}

# --- Écriture rapport (UTF-8 sans BOM) ---
_Write-Phase "build_report : écriture $OutFile"
[System.IO.File]::WriteAllText($OutFile, $tpl, [System.Text.UTF8Encoding]::new($false))

_Warn "Rapport généré : $OutFile (gain estimé $gainTotal GB)"
