# pc-optim/templates/scripts

Helpers PowerShell + 6 scans + assembleur, orchestrés par `../../pc-optim.sh`.

## Convention de sortie

Chaque `scan_*.ps1` :

- `param([int]$TopN = 50)` accepté
- dot-source `_common.ps1` pour les helpers partagés
- **stdout** : un seul objet JSON via `ConvertTo-Json -Depth 8`
- **stderr** : warnings + compteur AccessDenied (via `_Write-Phase` et `Write-Warning`)
- **Aucune écriture filesystem** (sauf `_build_report.ps1` qui écrit le rapport final passé en `-OutFile`)

## Fichiers

| Fichier | Rôle | Sortie |
|---|---|---|
| `_common.ps1` | Helpers partagés (`_Format-Size`, `_Get-FolderSize`, `_New-Finding`, `_Get-Risk`, `_Test-IsAdmin`, `_Get-MachineInfo`, `_Get-DriveInfo`) | (dot-sourcé) |
| `scan_disk_usage.ps1` | Drive info + top dossiers profil + temp zones + archives > 500 MB | JSON |
| `scan_ai_models.ps1` | Ollama / HF / LM Studio / GPT4All / SD / ComfyUI + orphelins | JSON |
| `scan_dev_caches.ps1` | npm/pip/yarn/pnpm/cargo/go/Maven/Gradle/VS Code/JetBrains + Docker + node_modules orphelins | JSON |
| `scan_duplicates.ps1` | Fichiers > 10 MB groupés par (Name, Length) | JSON |
| `scan_apps_installed.ps1` | Registry Uninstall + AppX + winget + UserAssist | JSON |
| `scan_network_security.ps1` | DNS + VPN + proxy + ports + Defender + firewall + ping | JSON |
| `_build_report.ps1` | Lit les 6 JSON + template + mapping → écrit le `.md` final | écrit `-OutFile` |

## Read-only garanti

Aucun script ne contient :
- `Set-Content` (sauf `_build_report.ps1` — fichier de sortie en cwd utilisateur)
- `New-Item`, `Remove-Item`, `Move-Item`, `Rename-Item`
- `Set-ItemProperty`, `New-ItemProperty`, `Remove-ItemProperty`
- `Add-MpPreference`, `Set-MpPreference`
- `Set-NetFirewallProfile`, `New-NetFirewallRule`
- `Stop-Process`, `Restart-Computer`, `Uninstall-*`, `Disable-*`

Vérification rapide :

```bash
grep -rE 'Set-(?!Variable|Location)|New-Item|Remove-Item|Stop-Process|Restart-|Add-Mp|Uninstall-|Disable-' \
  ~/.claude/skills/pc-optim/templates/scripts/ | grep -v _build_report.ps1
```

Doit retourner vide.

## Test isolé d'un scan

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File ~/.claude/skills/pc-optim/templates/scripts/scan_disk_usage.ps1 \
  -TopN 10 > /tmp/test.json 2> /tmp/test.log
```

Vérifier que `/tmp/test.json` est un JSON valide.
