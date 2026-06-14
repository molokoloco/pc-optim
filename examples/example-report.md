> **Exemple de rapport `/pc-optim`** — généré sur une machine de démo, **données anonymisées**
> (hostname, nom d'utilisateur, adresses MAC et IP locales remplacés). Donné à titre d'illustration
> de ce que le skill produit. Voir l'aperçu : [example-report.png](example-report.png).

---

# Diagnostic PC — 2026-06-12

> Généré par `/pc-optim` v1.0.0 · **read-only**, aucune modification système.
>
> Machine : **PC-DEMO** · Microsoft Windows 10 Professionnel (10.0.19045)
> CPU : Intel(R) Core(TM) i7-4900MQ CPU @ 2.80GHz · RAM : 15.9 GB · Admin : non (scan dégradé sur certains points)
>
> Disque **C:** : 227.8 / 238.5 GB utilisés (95.5 %) · libre 10.7 GB

---

## Executive Summary

| Dimension | État | Gain potentiel |
|---|---|---|
| §1 Espace disque | 🟢 propre | **3.43 GB** |
| §2 Modèles IA | 🟡 cleanup utile | **12.5 GB** |
| §3 Caches dev | 🟢 propre | **0.96 GB** |
| §4 Doublons | — rien à signaler | **0 GB** |
| §5 Apps installées | 75 apps répertoriées | indicatif |
| §6 Réseau & sécurité | 🟢 Defender actif | n/a |

**Gain total estimé : 16.89 GB**

### Top 3 actions immédiates

1. **Auditer modèles IA locaux (2 provider(s), 1 orphelin(s))** — gain ~12.5 GB · outil : *ollama-cli*
2. **Vider Temp + SoftwareDistribution + corbeille** — gain ~2.6 GB · outil : *windows-builtin*

---

## §1. Espace disque C:\

### 1.1 Vue d'ensemble

| | Valeur |
|---|---|
| Volume |  (NTFS) |
| Taille totale | 238.5 GB |
| Utilisé | 227.8 GB (95.5 %) |
| Libre | 10.7 GB |

### 1.2 Top dossiers sous `C:\Users\demo`

| Dossier | Taille |
|---|---|
| `C:\Users\demo\Downloads` | 17,61 GB |
| `C:\Users\demo\.ollama` | 8,95 GB |
| `C:\Users\demo\Music` | 8,12 GB |
| `C:\Users\demo\OneDrive` | 4,95 GB |
| `C:\Users\demo\Local Sites` | 2,74 GB |
| `C:\Users\demo\.vscode` | 2,07 GB |
| `C:\Users\demo\Videos` | 1,70 GB |
| `C:\Users\demo\.lmstudio` | 1,56 GB |
| `C:\Users\demo\.cache` | 672,7 MB |
| `C:\Users\demo\.antigravity` | 608,8 MB |
| `C:\Users\demo\.local` | 518,6 MB |
| `C:\Users\demo\.claude` | 487,0 MB |
| `C:\Users\demo\.gemini` | 348,2 MB |
| `C:\Users\demo\.antigravity-ide` | 47,0 MB |
| `C:\Users\demo\.continue` | 42,6 MB |
| `C:\Users\demo\.codex` | 6,9 MB |
| `C:\Users\demo\.codegpt` | 700,3 KB |
| `C:\Users\demo\.vscode-shared` | 180,4 KB |
| `C:\Users\demo\.ft-bookmarks` | 125,9 KB |
| `C:\Users\demo\.ssh` | 109,7 KB |
| `C:\Users\demo\IntelGraphicsProfiles` | 24,7 KB |
| `C:\Users\demo\diagnostics-pc` | 15,9 KB |
| `C:\Users\demo\.google_workspace_mcp` | 9,2 KB |
| `C:\Users\demo\Searches` | 1,8 KB |
| `C:\Users\demo\.docker` | 963 B |
| `C:\Users\demo\.crossnote` | 881 B |
| `C:\Users\demo\Favorites` | 690 B |
| `C:\Users\demo\.gnutls` | 473 B |
| `C:\Users\demo\.copilot` | 439 B |
| `C:\Users\demo\Contacts` | 412 B |
| `C:\Users\demo\.gmail` | 408 B |
| `C:\Users\demo\Saved Games` | 282 B |
| `C:\Users\demo\.config` | 99 B |
| `C:\Users\demo\.dbus-keyrings` | 78 B |
| `C:\Users\demo\.cagent` | 71 B |
| `C:\Users\demo\Recent` | 0 B |
| `C:\Users\demo\AppData` | 0 B |
| `C:\Users\demo\Voisinage d'impression` | 0 B |
| `C:\Users\demo\Voisinage r�seau` | 0 B |
| `C:\Users\demo\SendTo` | 0 B |
| `C:\Users\demo\.aws` | 0 B |
| `C:\Users\demo\Application Data` | 0 B |
| `C:\Users\demo\Local Settings` | 0 B |
| `C:\Users\demo\Cookies` | 0 B |
| `C:\Users\demo\Menu D�marrer` | 0 B |
| `C:\Users\demo\.azure` | 0 B |
| `C:\Users\demo\Mod�les` | 0 B |
| `C:\Users\demo\Mes documents` | 0 B |

### 1.3 Temp & cache système récupérables

| Risque | Zone | Chemin | Taille | Outil |
|---|---|---|---|---|
| 🟢 | Windows SoftwareDistribution | `C:\Windows\SoftwareDistribution\Download` | 256,2 MB | windows-builtin |
| 🔴 | Windows Installer cache | `C:\Windows\Installer` | 1,17 GB | manual |
| 🟢 | User Temp | `C:\Users\demo\AppData\Local\Temp` | 609,3 MB | ccleaner |
| 🟢 | LocalAppData Temp | `C:\Users\demo\AppData\Local\Temp` | 609,3 MB | ccleaner |
| 🟢 | Recycle Bin | `C:\$Recycle.Bin` | 129 B | windows-builtin |

### 1.4 Archives volumineuses (> 500 MB)

| Fichier | Taille | Risque |
|---|---|---|
| `C:\Users\demo\Downloads\Serato DJ Lite 4.0.2.zip` | 841,4 MB | 🟡 |

---

## §2. Modèles IA locaux

### 2.1 Par provider

| Provider | Chemin | Taille | Top fichiers |
|---|---|---|---|
| **ollama** | `C:\Users\demo\.ollama\models` | 8,95 GB | <br>• sha256-4c27e0f5b5adf02ac956c7322bd2ee7636fe3f45a8512c9aba5385242cb6e09a (8,95 GB) |
| **lmstudio** | `C:\Users\demo\.lmstudio` | 1,56 GB | <br>• ggml-cuda.dll (536,5 MB)<br>• cublasLt64_11.dll (294,3 MB) |

### 2.2 Fichiers orphelins (.gguf / .safetensors > 1 GB hors dossiers connus)

| Fichier | Taille | Risque |
|---|---|---|
| `C:\Users\demo\Downloads\OllamaSetup.exe` | 1,99 GB | 🟡 |

---

## §3. Caches développement

### 3.1 Package managers

| Risque | Tool | Chemin | Taille | Commande |
|---|---|---|---|---|
| 🟢 | **pip** | `C:\Users\demo\AppData\Local\pip\Cache` | 156,6 MB | pip cache purge |
| 🟢 | **vscode-cacheData** | `C:\Users\demo\AppData\Roaming\Code\CachedData` | 150,9 MB | Quit VS Code puis supprimer |
| 🟢 | **puppeteer** | `C:\Users\demo\.cache\puppeteer` | 672,7 MB | Cache chromium Puppeteer - r�install sur prochain npm i |

### 3.2 Docker

_(Docker non détecté)_

### 3.3 `node_modules` orphelins (> 6 mois, > 100 MB)

| Chemin | Taille | Recommandation |
|---|---|---|
| `` |  |  |

---

## §4. Doublons (heuristique nom + taille, > 10 MB)

> Candidats. Pour **certifier** un doublon avant suppression : ouvrir le sous-dossier dans **dupeGuru** ou **AllDup**.

_(aucun doublon candidat)_

---

## §5. Applications installées

### 5.1 Vue d'ensemble

| Source | Nb |
|---|---|
| Registry (Win32) | 75 |
| UWP (Appx) | 63 |

### 5.2 Grosses applications (> 500 MB selon registry)

| App | Install location | Taille | Éditeur |
|---|---|---|---|
| Docker Desktop | `C:\Program Files\Docker\Docker` | 3,45 GB | Docker Inc. |
| Ollama version 0.30.6 | `C:\Users\demo\AppData\Local\Programs\Ollama\` | 3,00 GB | Ollama |
| Microsoft Edge | `C:\Program Files (x86)\Microsoft\Edge\Application` | 1,95 GB | Microsoft Corporation |
| Antigravity IDE (User) | `C:\Users\demo\AppData\Local\Programs\Antigravity IDE\` | 1,00 GB | Google |
| Dell SupportAssist | `C:\Program Files\Dell\SupportAssistAgent\` | 872,1 MB | Dell Inc. |
| Microsoft Visual Studio Code (User) | `C:\Users\demo\AppData\Local\Programs\Microsoft VS Code\` | 804,5 MB | Microsoft Corporation |
| Inkscape | `C:\Program Files\Inkscape\` | 654,1 MB | Inkscape |
| Brave | `C:\Program Files\BraveSoftware\Brave-Browser\Application` | 495,3 MB | Auteurs de Brave |

### 5.3 Apps peu utilisées (UserAssist > 6 mois)

| Exécutable | Dernière utilisation |
|---|---|
| `{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\cmd.exe` | 2025-01-04 |

---

## §6. Réseau & sécurité

### 6.1 DNS résolveurs

| Interface | Serveur | Provider |
|---|---|---|
| Wi-Fi | 192.168.1.1 | inconnu (FAI?) |

### 6.2 VPN / proxy

**VPN connexions :**
_(aucune connexion VPN configurée)_

**Proxy WinHTTP :**
```

Param�tres de proxy WinHTTP actuels�:

    Acc�s direct (sans serveur proxy).

```

**Proxy WinINET (Internet Settings) :**
- ProxyEnable : 0
- ProxyServer : 
- AutoConfigURL : 

### 6.3 Ports en écoute (hors loopback strict)

| Port | Adresse | PID | Process | Chemin |
|---|---|---|---|---|
| 135 | 0.0.0.0 | 1192 | svchost | `?` |
| 139 | 192.168.1.2 | 4 | System | `?` |
| 445 | :: | 4 | System | `?` |
| 2179 | :: | 2388 | vmms | `?` |
| 3001 | :: | 24784 | node | `C:\Program Files\nodejs\node.exe` |
| 5040 | 0.0.0.0 | 8692 | svchost | `?` |
| 5357 | :: | 4 | System | `?` |
| 7680 | :: | 548 | svchost | `?` |
| 49664 | 0.0.0.0 | 912 | lsass | `?` |
| 49665 | :: | 764 | wininit | `?` |
| 49666 | 0.0.0.0 | 1484 | svchost | `?` |
| 49667 | :: | 2232 | svchost | `?` |
| 49668 | :: | 1352 | spoolsv | `?` |
| 49869 | :: | 852 | services | `?` |
| 54112 | 0.0.0.0 | 11388 | Code | `C:\Users\demo\AppData\Local\Programs\Microsoft VS Code\Code.exe` |
| 54113 | :: | 22568 | Code | `C:\Users\demo\AppData\Local\Programs\Microsoft VS Code\Code.exe` |
| 59869 | 0.0.0.0 | 4056 | logioptionsplus_agent | `C:\Program Files\LogiOptionsPlus\logioptionsplus_agent.exe` |

### 6.4 Windows Defender

| Réglage | Valeur |
|---|---|
| Real-time scan activé | True |
| Antivirus actif | True |
| Antispyware actif | True |
| Âge signatures (jours) | 0.8 |
| Dernier scan rapide | 2026-06-12 00:16 |
| Dernier scan complet | jamais |
| Tamper Protection | True |
| Nb exclusions chemins | 1 |
| Nb exclusions extensions | 1 |
| Nb exclusions process | 1 |

### 6.5 Firewall — profils

| Profil | Activé | Inbound par défaut | Outbound par défaut |
|---|---|---|---|
| Domain | 1 | NotConfigured | NotConfigured |
| Private | 1 | NotConfigured | NotConfigured |
| Public | 1 | NotConfigured | NotConfigured |

### 6.6 Qualité connexion

- Cloudflare 1.1.1.1 : ping=True latency=156 ms
- Google 8.8.8.8 : ping=True latency=632 ms
- Interface utilisée : Wi-Fi

### 6.7 Cartes réseau actives

| Carte | Type | Débit | MAC |
|---|---|---|---|
| Wi-Fi | Native 802.11 | 144 Mbps | XX-XX-XX-XX-XX-XX |
| vEthernet (Default Switch) | 802.3 | 10 Gbps | XX-XX-XX-XX-XX-XX |

---

## Quick wins → outils déjà installés

> Article hub Julien : *[Nettoyer, optimiser et mettre à jour votre Windows 10/11](https://julienweb.fr/blog/nettoyer-optimiser-et-mettre-a-jour-votre-windows-10-11)*

| Finding | Risque | Gain | Outil | Action |
|---|---|---|---|---|
| Temp système & cache Windows | 🟢 | ~2.61 GB | windows-builtin | Paramètres → Système → Stockage → Fichiers temporaires |
| Archives lourdes (1) | 🟡 | ~0.82 GB | 7zip | Trier .zip/.rar/.iso dans Downloads |
| Modèles IA (2 provider) | 🟡 | ~12.5 GB | ollama-cli | `ollama list` puis `ollama rm` les inutiles |
| Caches dev | 🟢 | ~0.96 GB | CLI dédié | `npm cache clean --force` / `docker system prune -a --volumes` |
| RAM saturée après build/VM | 🟢 | n/a | memorycleaner | Lancer Windows Memory Cleaner |
| Pilotes / BIOS obsolètes | 🟢 | n/a | oem | Lancer l'utilitaire fabricant |

---

## Annexes

- `pc-optim-out/_scan_disk_usage.json`
- `pc-optim-out/_scan_ai_models.json`
- `pc-optim-out/_scan_dev_caches.json`
- `pc-optim-out/_scan_duplicates.json`
- `pc-optim-out/_scan_apps_installed.json`
- `pc-optim-out/_scan_network_security.json`
- `pc-optim-out/_*.log` — warnings, AccessDenied, timeouts

> Rapport généré le 2026-06-12 · skill `/pc-optim` v1.0.0
