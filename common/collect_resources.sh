#!/usr/bin/env bash
# collect_resources.sh — dump the Utilization Estimates summary from every solution.
# Run from the exercise directory. Override via environment:
#   PROJ=iface_proj TOP=iface SOLS="a b c" OUT=resources.txt ../../common/collect_resources.sh
#
#   PROJ   project directory                (default: iface_proj)
#   TOP    top function name                (default: iface)
#   SOLS   space-separated solution names   (default: every solution with syn/report)
#   OUT    output file                      (default: resources.txt)
set -u

PROJ=${PROJ:-iface_proj}
TOP=${TOP:-iface}
OUT=${OUT:-resources.txt}

[ -d "$PROJ" ] || { echo "error: project dir '$PROJ' not found" >&2; exit 1; }

if [ -z "${SOLS:-}" ]; then
  SOLS=""
  for d in "$PROJ"/*/syn/report; do
    [ -d "$d" ] || continue
    s="${d#"$PROJ"/}"
    SOLS="$SOLS ${s%%/*}"
  done
fi
[ -n "${SOLS// /}" ] || { echo "error: no solutions found in '$PROJ'" >&2; exit 1; }

rpt_of() { echo "$PROJ/$1/syn/report/${TOP}_csynth.rpt"; }

{
  # ---- raw blocks, one per solution -------------------------------------
  for s in $SOLS; do
    echo "=================== $s ==================="
    r=$(rpt_of "$s")
    if [ -f "$r" ]; then
      awk '/^== Utilization Estimates/{f=1} /^\+ Detail/{f=0} f' "$r"
    else
      echo "  (missing: $r)"
      echo
    fi
  done

  # ---- one-line comparison ----------------------------------------------
  echo "=================== comparison (Total row) ==================="
  printf '%-12s %9s %6s %9s %9s %6s\n' solution BRAM_18K DSP FF LUT URAM
  for s in $SOLS; do
    r=$(rpt_of "$s")
    if [ ! -f "$r" ]; then
      printf '%-12s %9s\n' "$s" "MISSING"
      continue
    fi
    awk -F'|' -v sol="$s" '
      # locate the summary header and remember which column each metric is in
      !hdr && /BRAM_18K/ {
        for (i = 2; i <= NF; i++) { k = $i; gsub(/[ \t]/, "", k); if (k != "") col[k] = i }
        hdr = 1; next
      }
      # first Total row after that header is the design total
      hdr && /^\|Total/ {
        n = split("BRAM_18K DSP FF LUT URAM", want, " ")
        printf "%-12s", sol
        for (j = 1; j <= n; j++) {
          v = (want[j] in col) ? $col[want[j]] : "-"
          gsub(/[ \t]/, "", v)
          printf (j == 2 || j == 5) ? " %6s" : " %9s", v
        }
        printf "\n"
        exit
      }' "$r"
  done
} | tee "$OUT"