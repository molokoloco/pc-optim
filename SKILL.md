---
name: pc-optim
version: 1.1.1
description: Diagnostic read-only PC Windows — disk (C:\), modèles IA, caches dev, doublons, apps, réseau & sécurité. 6 scans PowerShell + rapport markdown. Mapping findings → outils Julien (SpaceSniffer/CCleaner/7-Zip/WingetUI/Memory Cleaner/OEM). Aucune écriture système. Trigger /pc-optim.
trigger: /pc-optim
allowed-tools: Read, Write, Bash, Grep, Glob
---

# /pc-optim — diagnostic read-only PC Windows

Tâche typique : « mon C:\ se remplit, je veux savoir ce qui pèse et quoi cleaner sans rien casser ».
Sortie : un rapport markdown `pc-optim-YYYY-MM-DD.md` dans le cwd + JSON intermédiaires dans `./pc-optim-out/`.

**Read-only strict.** Zéro `Set-`, `New-`, `Remove-`, `Add-`. Aucune modif registre / policy / service / système de fichiers en dehors du dossier de sortie.

---

## 1. Quand utiliser

- Diagnostic trimestriel d'hygiène disque
- Avant grosse install (jeu AAA, nouveau modèle IA local, VM Hyper-V)
- Suspicion lenteur / disque presque plein
- Audit DNS / VPN / ports après installation d'un nouveau soft réseau
- Vérification rapide état Defender + firewall avant déplacement de la machine
- Inventaire applications pour préparer une migration de PC

**Pas pour** :
- Nettoyage effectif → utiliser les outils que tu possèdes déjà (SpaceSniffer, CCleaner, WingetUI, Windows Memory Cleaner) ou les 3 commandes natives Windows (`ms-settings:storagesense`, `cleanmgr`, `cleanmgr /sageset:1` + `/sagerun:1`) listées en fin de rapport section **Réflexes manuels Windows**. Le rapport te dit **où aller**, pas **quoi supprimer à ta place**
- Profiling perf CPU/GPU temps réel → HWMonitor / Task Manager
- Scan antivirus → Windows Defender (Sécurité Windows → Analyse rapide)
- Dépannage Windows Update → `cleanmgr` + DISM/SFC (cf. article hub Julienweb)

---

## 2. Pattern technique

Windows = pas de `du -sh` ni `df -h` natifs lisibles. Solution : **PowerShell `.ps1` lancés en read-only via wrapper Bash**, sortie JSON pivot, assemblage final via template Markdown.

```
pc-optim.sh (Bash MSYS / Git-Bash)
  ├─ powershell.exe -NoProfile -ExecutionPolicy Bypass -File scan_disk_usage.ps1     > _scan_disk_usage.json
  ├─ powershell.exe ... scan_ai_models.ps1                                            > _scan_ai_models.json
  ├─ powershell.exe ... scan_dev_caches.ps1                                           > _scan_dev_caches.json
  ├─ powershell.exe ... scan_duplicates.ps1                                           > _scan_duplicates.json
  ├─ powershell.exe ... scan_apps_installed.ps1                                       > _scan_apps_installed.json
  ├─ powershell.exe ... scan_network_security.ps1                                     > _scan_network_security.json
  └─ powershell.exe ... _build_report.ps1 -InputDir pc-optim-out/ -Out pc-optim-*.md
```

`-ExecutionPolicy Bypass` est **per-process** (pas `Set-ExecutionPolicy`). Aucune persistance, aucune modif registre.

---

## 3. Pipeline 6 scans + assemblage

| Phase | Script | Cible | Temps |
|---|---|---|---|
| 1 | `scan_disk_usage.ps1` | Top dossiers C:\, temp système, archives | 60-180 s |
| 2 | `scan_ai_models.ps1` | Ollama / HF / LM Studio / GPT4All / SD / ComfyUI | ~30 s |
| 3 | `scan_dev_caches.ps1` | npm/pip/yarn/pnpm/cargo/go/Maven + Docker + IDE | 30-90 s |
| 4 | `scan_duplicates.ps1` | Downloads/Documents/Desktop/Pictures/Videos > 10 MB | 60-300 s |
| 5 | `scan_apps_installed.ps1` | Registry + Winget + Appx + UserAssist | ~20 s |
| 6 | `scan_network_security.ps1` | DNS / VPN / ports / Defender / firewall / ping | ~15 s |
| 7 | `_build_report.ps1` | Lit les 6 JSON + mapping → écrit le `.md` final | < 5 s |
| 8 | `scripts/render_pc_optim_pdf.js` | MD → PDF A4 branded Julienweb (Chrome headless) | ~3 s |
| 9 | `winget upgrade --all --silent` | Met à jour toutes les apps connues winget | 1-15 min |
| 10 | `explorer /select` | Ouvre Explorer sur le PDF (ou MD si PDF skip) | < 1 s |

**Total : 3-10 minutes** (hors winget upgrade qui dépend du nombre d'apps à mettre à jour).

---

## 4. Catégories scannées

| Catégorie | Cibles précises |
|---|---|
| **Disk** | `$env:USERPROFILE`, `C:\Windows\Temp`, `C:\Windows\SoftwareDistribution\Download`, `C:\Windows\Installer`, `C:\$Recycle.Bin`, `$env:TEMP`, `$env:LOCALAPPDATA\Temp`, archives `.zip/.rar/.7z/.iso` > 500 MB |
| **AI models** | `$env:USERPROFILE\.ollama\models`, `$env:USERPROFILE\.cache\huggingface`, `$env:USERPROFILE\.lmstudio`, `$env:LOCALAPPDATA\nomic.ai\GPT4All`, `$env:USERPROFILE\stable-diffusion-webui\models`, `$env:USERPROFILE\ComfyUI\models` + fichiers `.gguf/.safetensors/.bin/.ckpt` > 1 GB |
| **Dev caches** | `$env:LOCALAPPDATA\npm-cache` + `$env:APPDATA\npm-cache` (les deux testés), `$env:LOCALAPPDATA\pip\Cache`, `$env:LOCALAPPDATA\Yarn\Cache`, `$env:LOCALAPPDATA\pnpm`, `$env:USERPROFILE\.cargo`, `$env:USERPROFILE\.gradle`, `$env:USERPROFILE\.m2`, `$env:USERPROFILE\go`, `$env:APPDATA\Code\Cache*`, `$env:LOCALAPPDATA\JetBrains`, `docker system df --format json` ; si le daemon ne répond pas : taille de `$env:LOCALAPPDATA\Docker\wsl` (information, hors gain) |
| **Duplicates** | `$env:USERPROFILE\Downloads`, `Documents`, `Desktop`, `Pictures`, `Videos` — fichiers > 10 MB groupés par `(Name, Length)` |
| **Apps** | `HKLM\…\Uninstall\*` (32 + 64), `HKCU\…\Uninstall\*`, `Get-AppxPackage`, `winget list --accept-source-agreements`, dernière utilisation via `UserAssist` ROT13 |
| **Network** | `Get-DnsClientServerAddress`, `Get-VpnConnection`, `netsh winhttp show proxy`, `Get-NetTCPConnection -State Listen`, `Get-MpPreference`, `Get-MpComputerStatus`, `Get-NetFirewallProfile`, `Test-NetConnection 1.1.1.1 -InformationLevel Detailed` |

---

## 5. Heuristique doublons (nom + taille)

Stratégie volontairement simple : `Get-ChildItem -File -Recurse | Group-Object Name, Length | Where Count -gt 1`.

**Pourquoi pas de hash MD5/SHA1 ?**
- Hash récursif sur un home Windows = 20-90 minutes selon volume. Hors scope d'un rapport de diagnostic.
- Pour 99% des doublons utiles à dégager (ISO Windows téléchargée 3x, installeur Node v18 / v20, vidéo récupérée 2 fois), `(Name, Length)` exact suffit.
- Pour certifier un doublon avant suppression, l'utilisateur lance **dupeGuru** ou **AllDup** sur le sous-dossier identifié — c'est l'outil dédié.

Le rapport remonte donc des **candidats**, pas des certitudes. Le risque (🟢/🟡/🔴) reflète cette incertitude.

---

## 6. Mapping findings → outils Julien

Fichier `templates/tools-mapping.json` — chaque catégorie / sous-catégorie pointe vers l'outil idéal **déjà installé** chez Julien :

| `tool_hint` | Outil | Cas d'usage |
|---|---|---|
| `spacesniffer` | SpaceSniffer | Explorer visuellement un dossier lourd identifié |
| `ccleaner` | CCleaner | Caches navigateurs, registre, cookies, autoruns |
| `7zip` | 7-Zip | Recompresser une archive, extraire un installeur |
| `wingetui` | WingetUI / UpdateHub | Mettre à jour ou désinstaller proprement les apps listées |
| `memorycleaner` | Windows Memory Cleaner | Libérer la RAM après gros build / VM |
| `oem` | Dell SupportAssist / HP / Lenovo Vantage / MyASUS / Acer / MSI / Razer / Surface | Pilotes, BIOS, diagnostics matériels |
| `windows-builtin` | Nettoyage de disque / Storage Sense | Windows Update files, miniatures, corbeille |
| `manual` | Action manuelle (Explorer / Settings) | Tri ponctuel ou réglage spécifique |

Article hub de référence : `D:/Google Drive/_WWW_/Julienweb.fr/content/articles-publies/2024-12-02_nettoyer-optimiser-et-mettre-a-jour-votre-windows-10-11.md`.

---

## 7. Usage

```bash
# Diagnostic complet (3-10 min)
cd ~/diagnostics-pc/
bash ~/.claude/skills/pc-optim/pc-optim.sh

# Sortie :
#   ./pc-optim-out/_scan_*.json   (6 JSON + 6 logs)
#   ./pc-optim-2026-06-12.md      (rapport final)
```

Flags d'env (skip une phase, utile pour relancer un scan rapide après changement) :

```bash
SKIP_DUP=1 SKIP_NET=1 bash ~/.claude/skills/pc-optim/pc-optim.sh
# Scans       : SKIP_DISK, SKIP_AI, SKIP_DEV, SKIP_DUP, SKIP_APP, SKIP_NET
# Post-rapport : SKIP_PDF (export PDF), SKIP_UPGRADE (winget), SKIP_OPEN (Explorer)
```

Top N configurable par scan via `PC_OPTIM_TOPN=100` (défaut : 50).

Timeout de mesure par dossier via `PC_OPTIM_FOLDER_TIMEOUT=600` (défaut : 240 s). À monter sur un profil
chargé : `AppData` seul dépasse 120 s. Au-delà du délai, le total du dossier est **partiel** — le scan le
signale en stderr au lieu de rendre un chiffre faux silencieusement.

### Sortie complète

```
./pc-optim-out/_scan_*.json    6 JSON read-only
./pc-optim-out/_*.log          warns / AccessDenied / timeouts
./pc-optim-out/_winget_upgrade.log  trace winget
./pc-optim-2026-06-12.md       rapport markdown
./pc-optim-2026-06-12.html     HTML intermédiaire (debug/print)
./pc-optim-2026-06-12.pdf      PDF A4 branded Julienweb
```

À la fin : Explorer s'ouvre automatiquement, fichier PDF présélectionné.

---

## 8. Pièges connus

- **ExecutionPolicy** : ne **jamais** lancer `Set-ExecutionPolicy`. Le wrapper utilise `-ExecutionPolicy Bypass` per-process (scope éphémère). Voir `howto-execution-policy.md`.
- **Windows Defender real-time scan** peut throttler `Get-ChildItem -Recurse` dans `$env:TEMP` et dans les conteneurs UWP `AppData\Local\Packages\*\AC`. Mitigation : `-ErrorAction SilentlyContinue` partout + skip d'un sous-dossier si son scan dépasse 90 s. **Ne pas ajouter d'exclusion Defender permanente** juste pour ce skill. Voir `howto-defender-exclusions.md`.
- **OneDrive / Google Drive Stream placeholders** : fichiers `FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS`. Lire `Length` peut déclencher un téléchargement involontaire. Solution : filtrer `Attributes -notmatch 'Offline|RecallOnOpen'` avant agrégation taille.
- **AccessDenied** sur `C:\System Volume Information`, `C:\Windows\CSC`, UWP `AC` containers : tous les `Get-ChildItem` utilisent `-ErrorAction SilentlyContinue`. Le compteur de dossiers skippés sort sur stderr (`X dossiers skippés (AccessDenied)`).
- **`Get-NetTCPConnection`** vide si lancé depuis session non-interactive (SSH headless, scheduled task SYSTEM). Hors cas Julien mais documenté.
- **`winget list`** : flag `--accept-source-agreements` obligatoire ; fallback registry-seul si winget absent ou trop lent. La détection « peu utilisée » via UserAssist échoue sur les apps lancées seulement via raccourci épinglé Start (limite Windows).
- **Durée scan doublons** : limitée volontairement aux 5 dossiers utilisateur principaux (pas tout `$env:USERPROFILE`) sinon 5+ min sur des Documents volumineux.
- **Sous-comptage sur `AppData` (non résolu, 2026-08-31)** : `Get-ChildItem -Recurse` abandonne toute une branche au premier `AccessDenied` au lieu de continuer. Sur un profil chargé, `AppData` est ressorti à **28,9 GB** contre **82,3 GB** réels (14 refus, surtout `Local\Packages` UWP et `Local\Docker`). Sur un sous-arbre sans refus le helper est exact au byte près. **Recouper toute grosse valeur** avec `robocopy <dir> C:\__nx__ /L /S /NJH /BYTES /NC /NDL /XJ /R:0 /W:0`. Attention : robocopy compte les placeholders Drive/OneDrive à leur taille logique — il surestime là où `_Get-FolderSize` les exclut.
- **Gain potentiel = 🟢 + 🟡 seulement.** Une zone 🔴 (`C:\Windows\Installer`) est listée en §1.3 mais n'entre jamais dans le gain. Les zones temp sont dédupliquées par chemin résolu : `$env:TEMP` et `$env:LOCALAPPDATA\Temp` sont le même dossier sur un Windows standard.
- **Admin** : non requis pour 90% des scans. Sans admin, certains `OwningProcess` n'exposent pas leur `Path` complet → le rapport affiche `?` à la place. `_Test-IsAdmin` warn en stderr si non-admin, scan continue dégradé.

---

## 9. Forkability

Skill par nature **mono-machine** (le PC de Julien). Pas de snapshot local de fork par défaut.

Une variante utile : **baseline mensuelle** pour suivre l'évolution dans le temps.

```bash
# Run et archive avec timestamp dans un dossier dédié
cd ~/diagnostics-pc/baseline/
bash ~/.claude/skills/pc-optim/pc-optim.sh
# → pc-optim-2026-06-12.md gardé en historique
# → diff manuel mois suivant : comparer Top dossiers et gains potentiels
```

Pour porter le skill à **Linux/macOS** : remplacer les `.ps1` par des `.sh` équivalents (`du -ah`, `find -size +`, `systemctl list-units`, `ss -tln`, `resolvectl status`). Le squelette template + `tools-mapping.json` + wrapper restent identiques. Adapter `tools-mapping.json` aux outils Unix (BleachBit, ncdu, fdupes, etc.).

---

## 10. Référence implémentation

- **Première run** : 2026-06-12 sur un poste de test (laptop i7 de 2014, Win10 Pro, C:\ plein à 95.5 %) → **16.89 GB récupérables** identifiés (dont 12.5 GB de modèles IA Ollama/LM Studio, 2.6 GB temp système, 0.96 GB caches dev). Run en quelques minutes, read-only confirmé. Piège observé : le scan disque peut traîner (>10 min) quand des dossiers Google Drive Stream / OneDrive sont présents (recall placeholders) — déjà documenté §8.
- **Article hub** : `Julienweb.fr/content/articles-publies/2024-12-02_nettoyer-optimiser-et-mettre-a-jour-votre-windows-10-11.md`
- **Pattern source** : `~/.claude/skills/scan-wp-db/` (read-only diagnostic forkable)
- **Pattern orchestration** : `~/.claude/skills/audit-seo/` (helpers + JSON pivot + reprise)
