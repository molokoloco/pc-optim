# howto — Windows Defender & le scan `/pc-optim`

## Le symptôme

Pendant `scan_disk_usage.ps1` ou `scan_duplicates.ps1`, certains dossiers prennent **8+ minutes** au lieu de quelques secondes. Souvent :

- `%TEMP%`
- `%LOCALAPPDATA%\Packages\*\AC` (conteneurs UWP)
- `%LOCALAPPDATA%\Packages\Microsoft.MicrosoftEdge*\AC`

## Pourquoi

Windows Defender real-time scan **inspecte chaque fichier** lu par PowerShell pendant `Get-ChildItem -Recurse`. Sur des dossiers contenant des dizaines de milliers de petits fichiers (caches navigateur, profil UWP), le throttling est mesurable.

## La mauvaise réflexe : ajouter une exclusion Defender

```powershell
Add-MpPreference -ExclusionPath "$env:TEMP"
```

→ **À ne PAS faire** :
1. Persistant dans le registre — sort du périmètre read-only de `/pc-optim`.
2. Réduit la sécurité du PC pour toujours, pas juste pendant la run.
3. Beaucoup de malwares logent justement dans `%TEMP%`. Exclure ce dossier = ouvrir une porte.

## La bonne mitigation — déjà intégrée dans le skill

`_common.ps1::_Get-FolderSize` :

```powershell
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
foreach ($item in $items) {
    if ((Get-Date) -gt $deadline) {
        Write-Warning "_Get-FolderSize timeout après ${TimeoutSeconds}s sur $Path"
        break
    }
    # ...
}
```

- Chaque dossier a un **timeout soft** (60-90 s par défaut)
- Au-delà du timeout : le scan logge un warning sur stderr et continue. La taille remontée est partielle, mais le rapport reste utile.
- `-ErrorAction SilentlyContinue` partout : les `AccessDenied` sont comptés (`$script:AccessDeniedCount`) et résumés en fin de scan.

## Si la run est vraiment trop lente

Variantes acceptables :

1. **Skipper les phases coûteuses** :
   ```bash
   SKIP_DUP=1 SKIP_DISK=1 bash ~/.claude/skills/pc-optim/pc-optim.sh
   ```
2. **Réduire le `TopN`** :
   ```bash
   PC_OPTIM_TOPN=10 bash ~/.claude/skills/pc-optim/pc-optim.sh
   ```
3. **Lancer la run quand Defender est en plein scan complet** : les conflits real-time sont pires. Vérifier dans Sécurité Windows → Protection antivirus que la dernière analyse complète est terminée.

**Jamais** d'exclusion permanente juste pour ce skill.

## Lecture conseillée

- [Microsoft Docs — Configure exclusions in Microsoft Defender Antivirus](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/configure-exclusions-microsoft-defender-antivirus) (pourquoi être **très** parcimonieux avec les exclusions)
