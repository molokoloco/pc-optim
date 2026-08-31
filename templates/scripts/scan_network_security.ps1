# scan_network_security.ps1 — DNS, VPN, proxy, ports, Defender, firewall, qualité connexion
# Read-only
param(
    [int]$TopN = 50
)

. "$PSScriptRoot\_common.ps1"

# --- DNS ---
_Write-Phase "scan_network_security : DNS résolveurs"
$dnsKnownProviders = @{
    '1.1.1.1'  = 'Cloudflare'; '1.0.0.1' = 'Cloudflare'
    '8.8.8.8'  = 'Google';     '8.8.4.4' = 'Google'
    '9.9.9.9'  = 'Quad9';      '149.112.112.112' = 'Quad9'
    '208.67.222.222' = 'OpenDNS'; '208.67.220.220' = 'OpenDNS'
    '94.140.14.14'   = 'AdGuard'; '94.140.15.15' = 'AdGuard'
    '80.67.169.12'   = 'FDN (FR)'; '80.67.169.40' = 'FDN (FR)'
    '212.27.40.240'  = 'Free (FR)'; '212.27.40.241' = 'Free (FR)'
}
$dnsServers = @()
try {
    $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.ServerAddresses -and $_.InterfaceAlias -notmatch 'Loopback' }
    foreach ($entry in $dns) {
        foreach ($srv in $entry.ServerAddresses) {
            $dnsServers += [PSCustomObject]@{
                interface = $entry.InterfaceAlias
                server    = $srv
                provider  = if ($dnsKnownProviders.ContainsKey($srv)) { $dnsKnownProviders[$srv] } else { 'inconnu (FAI?)' }
            }
        }
    }
} catch { _Warn "DNS erreur : $_" }

# --- VPN ---
_Write-Phase "scan_network_security : VPN connexions"
$vpn = @()
try {
    $vpn = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            name        = $_.Name
            server      = $_.ServerAddress
            tunnel_type = $_.TunnelType
            status      = $_.ConnectionStatus
        }
    }
    $vpn += Get-VpnConnection -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            name        = $_.Name
            server      = $_.ServerAddress
            tunnel_type = $_.TunnelType
            status      = $_.ConnectionStatus
        }
    }
    $vpn = $vpn | Sort-Object name -Unique
} catch { _Warn "VPN erreur : $_" }

# --- Proxy ---
_Write-Phase "scan_network_security : proxy WinHTTP + WinINET"
$proxy = [PSCustomObject]@{ winhttp = ''; wininet = $null }
try {
    $proxy.winhttp = (& netsh winhttp show proxy 2>$null) -join "`n"
} catch {}
try {
    $inet = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if ($inet) {
        $proxy.wininet = [PSCustomObject]@{
            ProxyEnable = $inet.ProxyEnable
            ProxyServer = $inet.ProxyServer
            AutoConfigURL = $inet.AutoConfigURL
        }
    }
} catch {}

# --- Ports en écoute ---
_Write-Phase "scan_network_security : ports TCP en écoute"
$ports = @()
try {
    $listening = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalAddress -notmatch '^(::1|127\.0\.0\.1)$' -or $_.LocalAddress -eq '0.0.0.0' -or $_.LocalAddress -eq '::' }
    $ports = $listening | ForEach-Object {
        $procInfo = $null
        try { $procInfo = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue } catch {}
        [PSCustomObject]@{
            local_addr   = $_.LocalAddress
            local_port   = $_.LocalPort
            pid          = $_.OwningProcess
            process_name = if ($procInfo) { $procInfo.ProcessName } else { '?' }
            process_path = if ($procInfo -and $procInfo.Path) { $procInfo.Path } else { '?' }
        }
    } | Sort-Object local_port -Unique | Select-Object -First $TopN
} catch { _Warn "Get-NetTCPConnection erreur : $_" }

# --- Windows Defender ---
_Write-Phase "scan_network_security : Windows Defender"
$defender = [PSCustomObject]@{ available = $false }
try {
    $pref = Get-MpPreference -ErrorAction SilentlyContinue
    $stat = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($pref -and $stat) {
        $sigAgeDays = if ($stat.AntivirusSignatureLastUpdated) {
            [math]::Round((New-TimeSpan -Start $stat.AntivirusSignatureLastUpdated -End (Get-Date)).TotalDays, 1)
        } else { -1 }
        $defender = [PSCustomObject]@{
            available           = $true
            real_time_enabled   = -not $pref.DisableRealtimeMonitoring
            tamper_protection   = if ($stat.PSObject.Properties.Name -contains 'IsTamperProtected') { $stat.IsTamperProtected } else { $null }
            antivirus_enabled   = $stat.AntivirusEnabled
            antispyware_enabled = $stat.AntispywareEnabled
            signature_age_days  = $sigAgeDays
            last_quick_scan     = if ($stat.QuickScanEndTime) { $stat.QuickScanEndTime.ToString('yyyy-MM-dd HH:mm') } else { 'jamais' }
            last_full_scan      = if ($stat.FullScanEndTime) { $stat.FullScanEndTime.ToString('yyyy-MM-dd HH:mm') } else { 'jamais' }
            exclusion_path      = @($pref.ExclusionPath)
            exclusion_extension = @($pref.ExclusionExtension)
            exclusion_process   = @($pref.ExclusionProcess)
        }
    }
} catch { _Warn "Defender erreur : $_" }

# --- Firewall ---
_Write-Phase "scan_network_security : firewall profils"
$firewall = @()
try {
    $firewall = Get-NetFirewallProfile -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            profile        = $_.Name
            enabled        = $_.Enabled
            default_inbound  = [string]$_.DefaultInboundAction
            default_outbound = [string]$_.DefaultOutboundAction
            notifications  = $_.NotifyOnListen
        }
    }
} catch { _Warn "Firewall erreur : $_" }

# --- Connectivité ---
_Write-Phase "scan_network_security : qualité connexion (ping 1.1.1.1 + 8.8.8.8)"
$connectivity = [PSCustomObject]@{}
try {
    $t1 = Test-NetConnection -ComputerName '1.1.1.1' -InformationLevel Detailed -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    $t2 = Test-NetConnection -ComputerName '8.8.8.8' -InformationLevel Detailed -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    $connectivity = [PSCustomObject]@{
        cloudflare_ping_ok = if ($t1) { $t1.PingSucceeded } else { $false }
        cloudflare_ping_ms = if ($t1 -and $t1.PingReplyDetails) { $t1.PingReplyDetails.RoundtripTime } else { -1 }
        google_ping_ok     = if ($t2) { $t2.PingSucceeded } else { $false }
        google_ping_ms     = if ($t2 -and $t2.PingReplyDetails) { $t2.PingReplyDetails.RoundtripTime } else { -1 }
        interface_alias    = if ($t1) { $t1.InterfaceAlias } else { '' }
    }
} catch { _Warn "Connectivity erreur : $_" }

# --- Cartes réseau actives ---
_Write-Phase "scan_network_security : cartes réseau actives"
$adapters = @()
try {
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        [PSCustomObject]@{
            name      = $_.Name
            type      = $_.MediaType
            link_speed = $_.LinkSpeed
            mac       = $_.MacAddress
        }
    }
} catch { _Warn "Get-NetAdapter erreur : $_" }

_Report-ScanStats

$output = [PSCustomObject]@{
    category     = 'network_security'
    dns          = @($dnsServers)
    vpn          = @($vpn)
    proxy        = $proxy
    ports_listening = @($ports)
    defender     = $defender
    firewall     = @($firewall)
    connectivity = $connectivity
    adapters     = @($adapters)
}

_Emit-Json $output -Depth 8
