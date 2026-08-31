# Diagnostic PC — {{DATE}}

> Généré par `/pc-optim` v{{SKILL_VERSION}} · **read-only**, aucune modification système.
>
> Machine : **{{HOSTNAME}}** · {{OS_CAPTION}} ({{OS_VERSION}})
> CPU : {{CPU}} · RAM : {{RAM_GB}} GB · Admin : {{IS_ADMIN}}
>
> Disque **C:** : {{DISK_USED_GB}} / {{DISK_SIZE_GB}} GB utilisés ({{DISK_USED_PCT}} %) · libre {{DISK_FREE_GB}} GB

---

## Executive Summary

| Dimension | État | Gain potentiel |
|---|---|---|
| §1 Espace disque | {{SCORE_DISK}} | **{{GAIN_DISK_GB}} GB** |
| §2 Modèles IA | {{SCORE_AI}} | **{{GAIN_AI_GB}} GB** |
| §3 Caches dev | {{SCORE_DEV}} | **{{GAIN_DEV_GB}} GB** |
| §4 Doublons | {{SCORE_DUP}} | **{{GAIN_DUP_GB}} GB** |
| §5 Apps installées | {{SCORE_APP}} | indicatif |
| §6 Réseau & sécurité | {{SCORE_NET}} | n/a |

**Gain total estimé : {{GAIN_TOTAL_GB}} GB**

### Top 3 actions immédiates

{{TOP_ACTIONS}}

---

## §1. Espace disque C:\

### 1.1 Vue d'ensemble

| | Valeur |
|---|---|
| Volume | {{DISK_VOLUME_NAME}} ({{DISK_FS}}) |
| Taille totale | {{DISK_SIZE_GB}} GB |
| Utilisé | {{DISK_USED_GB}} GB ({{DISK_USED_PCT}} %) |
| Libre | {{DISK_FREE_GB}} GB |

### 1.2 Top dossiers sous `{{USERPROFILE}}`

{{DISK_TOP_FOLDERS}}

### 1.3 Temp & cache système récupérables

{{DISK_TEMP_ZONES}}

### 1.4 Archives volumineuses (> 500 MB)

{{DISK_ARCHIVES}}

---

## §2. Modèles IA locaux

### 2.1 Par provider

{{AI_BY_PROVIDER}}

### 2.2 Fichiers orphelins (.gguf / .safetensors > 1 GB hors dossiers connus)

{{AI_ORPHANS}}

---

## §3. Caches développement

### 3.1 Package managers

{{DEV_PACKAGE_CACHES}}

### 3.2 Docker

{{DEV_DOCKER}}

### 3.3 `node_modules` orphelins (> 6 mois, > 100 MB)

{{DEV_NODE_MODULES}}

---

## §4. Doublons (heuristique nom + taille, > 10 MB)

> Candidats. Pour **certifier** un doublon avant suppression : ouvrir le sous-dossier dans **dupeGuru** ou **AllDup**.

{{DUPLICATES}}

---

## §5. Applications installées

### 5.1 Vue d'ensemble

| Source | Nb |
|---|---|
| Registry (Win32) | {{APPS_REGISTRY_COUNT}} |
| UWP (Appx) | {{APPS_APPX_COUNT}} |

### 5.2 Grosses applications (> 500 MB selon registry)

{{APPS_LARGE}}

### 5.3 Apps peu utilisées (UserAssist > 6 mois)

{{APPS_RARELY_USED}}

---

## §6. Réseau & sécurité

### 6.1 DNS résolveurs

{{NET_DNS}}

### 6.2 VPN / proxy

**VPN connexions :**
{{NET_VPN}}

**Proxy WinHTTP :**
```
{{NET_PROXY_WINHTTP}}
```

**Proxy WinINET (Internet Settings) :**
{{NET_PROXY_WININET}}

### 6.3 Ports en écoute (hors loopback strict)

{{NET_PORTS}}

### 6.4 Windows Defender

{{NET_DEFENDER}}

### 6.5 Firewall — profils

{{NET_FIREWALL}}

### 6.6 Qualité connexion

{{NET_CONNECTIVITY}}

### 6.7 Cartes réseau actives

{{NET_ADAPTERS}}

---

## Quick wins → outils déjà installés

> Article hub Julien : *[Nettoyer, optimiser et mettre à jour votre Windows 10/11](https://julienweb.fr/blog/nettoyer-optimiser-et-mettre-a-jour-votre-windows-10-11)*

{{QUICK_WINS_TABLE}}

---

## Réflexes manuels Windows

Le rapport dit **où aller**, pas **quoi supprimer à ta place**. Trois commandes natives :

| Commande | Ce qu'elle fait |
|---|---|
| `ms-settings:storagesense` | Paramètres → Stockage : vue par catégorie + Assistant Stockage (nettoyage auto) |
| `cleanmgr` | Nettoyage de disque classique (+ « Nettoyer les fichiers système » pour Windows Update) |
| `cleanmgr /sageset:1` puis `cleanmgr /sagerun:1` | Profil de nettoyage réutilisable, à relancer sans re-cocher |

---

## Annexes

- `pc-optim-out/_scan_disk_usage.json`
- `pc-optim-out/_scan_ai_models.json`
- `pc-optim-out/_scan_dev_caches.json`
- `pc-optim-out/_scan_duplicates.json`
- `pc-optim-out/_scan_apps_installed.json`
- `pc-optim-out/_scan_network_security.json`
- `pc-optim-out/_*.log` — warnings, AccessDenied, timeouts

> Rapport généré le {{DATE}} · skill `/pc-optim` v{{SKILL_VERSION}}
