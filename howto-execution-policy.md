# howto — ExecutionPolicy sans persistance

## Le problème

Par défaut, Windows refuse d'exécuter un `.ps1` non signé en utilisateur final :

```
.\scan_disk_usage.ps1 ne peut pas être chargé car l'exécution
de scripts est désactivée sur ce système.
```

## La mauvaise solution

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

→ persistante dans le registre. Modifie le comportement de tous les autres scripts PowerShell. **Hors charte read-only de `/pc-optim`.**

## La bonne solution — bypass per-process

Le wrapper `pc-optim.sh` lance chaque scan avec :

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File <ps1>
```

- `-NoProfile` : ignore `$PROFILE` (pas de surprise de l'environnement utilisateur)
- `-ExecutionPolicy Bypass` : scope **process-only**, n'écrit rien dans le registre, disparaît à la fin du process. Documentation Microsoft : [about_Execution_Policies — Bypass](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)
- `-File` : lance le script comme un programme (pas dot-source)

→ **Zéro effet de bord, zéro modification système.**

## Vérification

Après une run, dans une nouvelle session PowerShell utilisateur :

```powershell
Get-ExecutionPolicy -List
```

Les scopes `CurrentUser`, `LocalMachine` doivent être inchangés par rapport à avant la run.

## Si le wrapper ne fonctionne pas en double-clic depuis Explorer

`pc-optim.sh` est un script Bash — il faut Git Bash / MSYS / WSL. Pas double-cliquable depuis Explorer Windows. Lancer depuis un terminal :

```bash
cd ~/diagnostics-pc/
bash ~/.claude/skills/pc-optim/pc-optim.sh
```

Ou, pour un équivalent CMD natif (à écrire si besoin) :

```cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\skills\pc-optim\templates\scripts\scan_disk_usage.ps1"
```

(Le pipeline complet via wrapper Bash reste recommandé pour orchestrer les 6 scans + le build.)
