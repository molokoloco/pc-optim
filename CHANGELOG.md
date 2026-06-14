# Changelog — pc-optim

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
