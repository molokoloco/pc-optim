# Changelog — pc-optim

## v1.1.0 — 2026-08-31

Trois bugs qui rendaient le skill inutilisable en l'état, découverts en le lançant sur un
poste réel à 0,9 GB libres. Chacun échouait **silencieusement** : aucun code retour non nul.

### Corrigé

- **JSON invalide dès qu'un nom de fichier sort de l'ASCII.** La redirection `> _scan_*.json`
  du wrapper Bash passe par la codepage console : un MP3 nommé avec des guillemets pleine chasse
  (`U+FF02`) était translittéré en `"` droits **non échappés**, cassant le JSON et faisant échouer
  l'assemblage. `ConvertTo-Json` n'était pas en cause. Nouveau helper `_Emit-Json` : la sortie est
  ré-échappée en `\uXXXX`, donc ASCII pur et immunisée à la codepage. Logs stderr passés en UTF-8
  au passage (fini les `skipp?s`).
- **`templates/PC-OPTIM-template.md` absent du dépôt.** La règle `.gitignore` `pc-optim-*.md`,
  destinée aux rapports générés, matchait aussi le template — git est **case-insensitive sous
  Windows**. Jamais commité, donc absent au clone : le skill ne pouvait pas produire de rapport
  chez un tiers. Template restauré, règle réancrée en `/pc-optim-20*.md` (racine + datée).
- **Dossiers volumineux rapportés à 0 B.** `_Get-FolderSize` collectait l'arborescence entière
  dans une variable *avant* d'entrer dans la boucle qui teste le deadline. Sur un gros dossier
  l'énumération dépassait déjà le délai à la première itération → `break` immédiat → **0 B**.
  Un `AppData` de 82 GB était rapporté vide, et le plus gros poste du disque disparaissait du
  rapport. L'énumération streame désormais dans le pipeline, et un total tronqué est annoncé
  comme **partiel** au lieu d'être rendu comme un chiffre exact.

### Ajouté

- `PC_OPTIM_FOLDER_TIMEOUT` — timeout de mesure par dossier, défaut relevé de **60 s à 240 s**
  (`AppData` seul dépasse 120 s sur un profil chargé).

### Limite connue (non corrigée)

- **Sous-comptage sur les arborescences protégées.** `Get-ChildItem -Recurse` abandonne toute une
  branche au premier `AccessDenied` au lieu de poursuivre. Mesuré : `AppData` ressort à **28,9 GB**
  contre **82,3 GB** réels (14 refus, surtout `Local\Packages` UWP et `Local\Docker`). Sur un
  sous-arbre sans refus le helper est exact au byte près. Recouper toute grosse valeur avec
  `robocopy <dir> C:\__nx__ /L /S /NJH /BYTES /NC /NDL /XJ /R:0 /W:0` — en gardant à l'esprit que
  robocopy, lui, compte les placeholders OneDrive/Drive à leur taille logique.

## Première run — 2026-06-12

- Run validé sur un poste de test (laptop i7 de 2014, Win10 Pro, C:\ 95.5 %) : **16.89 GB récupérables** identifiés, read-only confirmé.
- Piège confirmé : scan disque lent (>10 min) en présence de Google Drive Stream / OneDrive (recall placeholders).

## v1.0.0 — 2026-06-12

- Création du skill `pc-optim`
- 6 scans PowerShell read-only : disk / ai_models / dev_caches / duplicates / apps_installed / network_security
- Wrapper Bash `pc-optim.sh` (Git Bash / MSYS) avec flags SKIP_* et PC_OPTIM_TOPN
- Helpers partagés `_common.ps1` (_Format-Size, _Get-FolderSize, _New-Finding, _Get-Risk, _Test-IsAdmin)
- Assembleur `_build_report.ps1` : JSON pivot → Markdown via template + tools-mapping
- Template rapport `PC-OPTIM-template.md` (10 sections + Quick wins → outils Julien)
- Mapping outils `tools-mapping.json` (SpaceSniffer, CCleaner, 7-Zip, WingetUI, Memory Cleaner, OEM)
- Howto `execution-policy` + `defender-exclusions`
- Article hub de référence : `Julienweb.fr/content/articles-publies/2024-12-02_nettoyer-optimiser-et-mettre-a-jour-votre-windows-10-11.md`
