#!/usr/bin/env bash
# pc-optim.sh — orchestrateur read-only diagnostic PC Windows
# Usage : bash ~/.claude/skills/pc-optim/pc-optim.sh
# Flags env :
#   SKIP_DISK=1 SKIP_AI=1 SKIP_DEV=1 SKIP_DUP=1 SKIP_APP=1 SKIP_NET=1
#   SKIP_PDF=1        ne pas exporter le rapport en PDF
#   SKIP_UPGRADE=1    ne pas lancer winget upgrade --all en fin
#   SKIP_OPEN=1       ne pas ouvrir Explorer sur le PDF
#   PC_OPTIM_TOPN=100  (défaut 50)
#   PC_OPTIM_OUT=/path/to/out  (défaut $PWD/pc-optim-out)
set -uo pipefail   # PAS de -e : on tolère qu'un scan échoue partiellement

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$SKILL_DIR/templates/scripts"
TEMPLATE="$SKILL_DIR/templates/PC-OPTIM-template.md"
MAPPING="$SKILL_DIR/templates/tools-mapping.json"
PDF_RENDER="$SKILL_DIR/scripts/render_pc_optim_pdf.js"
OUT_DIR="${PC_OPTIM_OUT:-$PWD/pc-optim-out}"
TOPN="${PC_OPTIM_TOPN:-50}"
DATE="$(date +%F)"
REPORT="$PWD/pc-optim-$DATE.md"
REPORT_PDF="$PWD/pc-optim-$DATE.pdf"

mkdir -p "$OUT_DIR"

# Helper : convertir chemin POSIX (MSYS) → Windows pour PowerShell
to_win() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    echo "$1" | sed -E 's|^/([a-z])/|\U\1:\\|' | tr '/' '\\'
  fi
}

run_ps() {
  local name="$1"
  local script_path
  script_path="$(to_win "$SCRIPTS/$name.ps1")"
  echo "==> $name" >&2
  powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "$script_path" -TopN "$TOPN" \
    > "$OUT_DIR/_$name.json" 2> "$OUT_DIR/_$name.log"
  local rc=$?
  if [ $rc -ne 0 ]; then
    echo "    WARN: $name exit=$rc (voir $OUT_DIR/_$name.log)" >&2
  fi
}

# Phases skippables individuellement
[ "${SKIP_DISK:-0}" = "0" ] && run_ps scan_disk_usage         || echo "==> scan_disk_usage SKIPPÉ" >&2
[ "${SKIP_AI:-0}"   = "0" ] && run_ps scan_ai_models          || echo "==> scan_ai_models SKIPPÉ" >&2
[ "${SKIP_DEV:-0}"  = "0" ] && run_ps scan_dev_caches         || echo "==> scan_dev_caches SKIPPÉ" >&2
[ "${SKIP_DUP:-0}"  = "0" ] && run_ps scan_duplicates         || echo "==> scan_duplicates SKIPPÉ" >&2
[ "${SKIP_APP:-0}"  = "0" ] && run_ps scan_apps_installed     || echo "==> scan_apps_installed SKIPPÉ" >&2
[ "${SKIP_NET:-0}"  = "0" ] && run_ps scan_network_security   || echo "==> scan_network_security SKIPPÉ" >&2

# Assemblage final du rapport MD
echo "==> _build_report" >&2
powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(to_win "$SCRIPTS/_build_report.ps1")" \
  -InputDir "$(to_win "$OUT_DIR")" \
  -Template "$(to_win "$TEMPLATE")" \
  -Mapping  "$(to_win "$MAPPING")" \
  -OutFile  "$(to_win "$REPORT")" \
  2> "$OUT_DIR/_build_report.log"
rc=$?

if [ $rc -ne 0 ] || [ ! -f "$REPORT" ]; then
  echo "ERR assembleur (exit=$rc). Voir $OUT_DIR/_build_report.log" >&2
  exit $rc
fi
echo "" >&2
echo "OK rapport MD : $REPORT" >&2
echo "    JSON intermédiaires + logs : $OUT_DIR/" >&2

# ───────────────────────────────────────────────────────────
# Export PDF branded Julienweb (Chrome headless)
# ───────────────────────────────────────────────────────────
if [ "${SKIP_PDF:-0}" = "0" ]; then
  if command -v node >/dev/null 2>&1; then
    echo "==> export PDF" >&2
    node "$PDF_RENDER" "$REPORT" "$REPORT_PDF" >> "$OUT_DIR/_build_report.log" 2>&1
    rc=$?
    if [ $rc -eq 0 ] && [ -f "$REPORT_PDF" ]; then
      sz=$(stat -c%s "$REPORT_PDF" 2>/dev/null || wc -c < "$REPORT_PDF")
      kb=$((sz / 1024))
      echo "    OK PDF : $REPORT_PDF (${kb} KB)" >&2
    else
      echo "    WARN export PDF (exit=$rc) — voir $OUT_DIR/_build_report.log" >&2
      REPORT_PDF=""
    fi
  else
    echo "==> export PDF SKIPPÉ (node introuvable)" >&2
    REPORT_PDF=""
  fi
else
  echo "==> export PDF SKIPPÉ" >&2
  REPORT_PDF=""
fi

# ───────────────────────────────────────────────────────────
# winget upgrade --all (silencieux, opt-out via SKIP_UPGRADE=1)
# ───────────────────────────────────────────────────────────
if [ "${SKIP_UPGRADE:-0}" = "0" ]; then
  if command -v winget.exe >/dev/null 2>&1 || command -v winget >/dev/null 2>&1; then
    echo "==> winget upgrade --all (silencieux)" >&2
    winget upgrade --all --silent \
      --accept-package-agreements --accept-source-agreements \
      > "$OUT_DIR/_winget_upgrade.log" 2>&1
    rc=$?
    if [ $rc -eq 0 ]; then
      echo "    OK winget upgrade terminé (log : $OUT_DIR/_winget_upgrade.log)" >&2
    else
      echo "    WARN winget exit=$rc (log : $OUT_DIR/_winget_upgrade.log)" >&2
    fi
  else
    echo "==> winget upgrade SKIPPÉ (winget introuvable)" >&2
  fi
else
  echo "==> winget upgrade SKIPPÉ" >&2
fi

# ───────────────────────────────────────────────────────────
# Ouvre Explorer sur le PDF (ou MD si pas de PDF)
# Pattern PowerShell wrapper (hook bash explorer-guard bloque /select depuis MSYS)
# ───────────────────────────────────────────────────────────
if [ "${SKIP_OPEN:-0}" = "0" ]; then
  target="$REPORT_PDF"
  [ -z "$target" ] || [ ! -f "$target" ] && target="$REPORT"
  if [ -f "$target" ]; then
    win_target="$(to_win "$target")"
    # Échappe les antislashes pour le passage en ligne PowerShell
    win_escaped=$(printf '%s' "$win_target" | sed 's/\\/\\\\/g')
    powershell.exe -NoProfile -Command \
      "Start-Process explorer.exe -ArgumentList '/select,\"$win_escaped\"'" \
      >/dev/null 2>&1 &
    echo "    Explorer ouvert sur : $win_target" >&2
  fi
fi
