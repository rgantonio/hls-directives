#!/usr/bin/env bash
# common/collect_latency.sh
# Collect latency information from Vitis HLS reports into one markdown file.
#
# Run from the exercise directory, e.g.:
#   PROJ=fir_proj TOP=fir3 SOLS="seq pipe pipe_2p" OUT=lat_fir.md ../../common/collect_latency.sh
#
#   PROJ     project directory                                  (required)
#   TOP      top function name                                  (required)
#   SOLS     space-separated solution names                     (default: every solution with syn/report)
#   OUT      output markdown file                               (default: lat_<PROJ>.md)
#   ALL_OPS  1 = every operator in the Bind Op table,
#            0 = only operators with latency > 0                (default: 0)
#
# Sources per solution:
#   syn/report/<module>_csynth.rpt   timing, module latency, loop table (every module,
#                                    so loops extracted into e.g. <top>_Pipeline_<LOOP> are found)
#   syn/report/csynth.rpt            Bind Op Report (operator latencies; only in this file in 2023.2)
#   sim/report/*cosim.rpt            cosim latency, if cosim was run

set -euo pipefail

: "${PROJ:?set PROJ, e.g. PROJ=fir_proj}"
: "${TOP:?set TOP, e.g. TOP=fir3}"
OUT="${OUT:-lat_${PROJ}.md}"
ALL_OPS="${ALL_OPS:-0}"

[[ -d "$PROJ" ]] || { echo "error: project dir '$PROJ' not found" >&2; exit 1; }

if [[ -z "${SOLS:-}" ]]; then
  SOLS=""
  for d in "$PROJ"/*/syn/report; do
    [[ -d "$d" ]] || continue
    s="${d#"$PROJ"/}"
    SOLS="$SOLS ${s%%/*}"
  done
fi
[[ -n "${SOLS// /}" ]] || { echo "error: no solutions found in '$PROJ'" >&2; exit 1; }

TRIM='function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }'

# Per-module reports of one solution, top module first.
module_reports() {
  local dir="$PROJ/$1/syn/report" r
  if [[ -f "$dir/${TOP}_csynth.rpt" ]]; then echo "$dir/${TOP}_csynth.rpt"; fi
  for r in "$dir"/*_csynth.rpt; do
    if [[ -f "$r" && "$r" != "$dir/${TOP}_csynth.rpt" ]]; then echo "$r"; fi
  done
}

{
echo "# Latency: $PROJ (top: $TOP)"
echo

# ---------------------------------------------------------------- timing + top latency
echo "## Timing and function latency (top module)"
echo
echo "| solution | clock target | clock est. | uncertainty | Fn lat min | Fn lat max | interval min | interval max | pipeline type |"
echo "|---|---|---|---|---|---|---|---|---|"
for s in $SOLS; do
  r="$PROJ/$s/syn/report/${TOP}_csynth.rpt"
  if [[ ! -f "$r" ]]; then echo "| $s | missing ${TOP}_csynth.rpt | | | | | | | |"; continue; fi
  awk -v sol="$s" "$TRIM"'
    /^\+ Timing:/  { sec = "t" }
    /^\+ Latency:/ { sec = "l" }
    sec == "t" && /\|ap_clk/ { split($0, f, "|"); tgt = trim(f[3]); est = trim(f[4]); unc = trim(f[5]) }
    sec == "l" && !got && /^[ \t]*\|[ \t]*[0-9?]/ {
      split($0, f, "|")
      lmin = trim(f[2]); lmax = trim(f[3]); imin = trim(f[6]); imax = trim(f[7]); pt = trim(f[8]); got = 1
    }
    END { printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", sol, tgt, est, unc, lmin, lmax, imin, imax, pt }
  ' "$r"
done
echo

# ---------------------------------------------------------------- every module
echo "## Module latency (all modules)"
echo
echo "| solution | module | lat min | lat max | interval min | interval max | pipeline type |"
echo "|---|---|---|---|---|---|---|"
for s in $SOLS; do
  while IFS= read -r r; do
    m="$(basename "$r" _csynth.rpt)"
    awk -v sol="$s" -v mod="$m" "$TRIM"'
      /^\+ Latency:/ { sec = "l" }
      sec == "l" && !got && /^[ \t]*\|[ \t]*[0-9?]/ {
        split($0, f, "|")
        printf "| %s | %s | %s | %s | %s | %s | %s |\n", sol, mod, trim(f[2]), trim(f[3]), trim(f[6]), trim(f[7]), trim(f[8])
        got = 1
      }
    ' "$r"
  done < <(module_reports "$s")
done
echo

# ---------------------------------------------------------------- loops
echo "## Loops"
echo
echo "Pipelined rows: \`iter lat\` read one more than the effective depth \$L_p\$ on the S1.1 kernels; check it again here. II achieved and target are separate columns."
echo
echo "| solution | module | loop | lat min | lat max | iter lat | II achieved | II target | trips | pipelined |"
echo "|---|---|---|---|---|---|---|---|---|---|"
for s in $SOLS; do
  rows=""
  while IFS= read -r r; do
    m="$(basename "$r" _csynth.rpt)"
    rows+="$(awk -v sol="$s" -v mod="$m" "$TRIM"'
      /^[ \t]*\* Loop:/ { inl = 1; next }
      inl && (/^=====/ || /^\+ / || /^[ \t]*\* /) { inl = 0 }
      inl && /^[ \t]*\|[ \t]*[-+]+ / {
        split($0, f, "|")
        printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", sol, mod,
               trim(f[2]), trim(f[3]), trim(f[4]), trim(f[5]), trim(f[6]), trim(f[7]), trim(f[8]), trim(f[9])
      }
    ' "$r")"$'\n'
  done < <(module_reports "$s")
  if [[ -z "$(module_reports "$s")" ]]; then echo "| $s | | (no *_csynth.rpt) | | | | | | | |"
  elif [[ -n "${rows//$'\n'/}" ]]; then printf '%s' "$rows" | sed '/^$/d'
  else echo "| $s | | (no loops) | | | | | | | |"; fi
done
echo

# ---------------------------------------------------------------- operator latency
echo "## Operator latency (Bind Op Report)"
echo
if [[ "$ALL_OPS" == "1" ]]; then echo "All operators."; else echo "Operators with latency > 0 only (set ALL_OPS=1 for all)."; fi
echo
echo "| solution | module | instance | variable | op | impl | DSP | latency |"
echo "|---|---|---|---|---|---|---|---|"
for s in $SOLS; do
  r="$PROJ/$s/syn/report/csynth.rpt"
  if [[ ! -f "$r" ]]; then echo "| $s | missing csynth.rpt | | | | | | |"; continue; fi
  awk -v sol="$s" -v all="$ALL_OPS" "$TRIM"'
    /^== Bind Op Report/ { inb = 1; next }
    inb && /^== / { inb = 0 }
    inb && /^\|/ {
      split($0, f, "|")
      if (f[2] ~ /^[ \t]*\+ /) { mod = trim(f[2]); sub(/^\+[ \t]*/, "", mod); next }
      lat = trim(f[8])
      if (lat !~ /^[0-9]+$/) next
      if (all != 1 && lat + 0 == 0) next
      printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", sol, mod, trim(f[2]), trim(f[5]), trim(f[6]), trim(f[7]), trim(f[3]), lat
      n++
    }
    END { if (!n) printf "| %s | | (none) | | | | | |\n", sol }
  ' "$r"
done
echo

# ---------------------------------------------------------------- cosim
echo "## Cosim latency (Verilog)"
echo
echo "| solution | status | lat min | lat avg | lat max | interval min | interval avg | interval max |"
echo "|---|---|---|---|---|---|---|---|"
for s in $SOLS; do
  r="$(ls "$PROJ/$s"/sim/report/*cosim.rpt 2>/dev/null | head -n 1 || true)"
  if [[ -z "$r" ]]; then echo "| $s | (no cosim report) | | | | | | |"; continue; fi
  awk -v sol="$s" "$TRIM"'
    /\|[ \t]*Verilog[ \t]*\|/ {
      split($0, f, "|")
      printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", sol, trim(f[3]), trim(f[4]), trim(f[5]), trim(f[6]), trim(f[7]), trim(f[8]), trim(f[9])
      got = 1
    }
    END { if (!got) printf "| %s | (no Verilog row) | | | | | | |\n", sol }
  ' "$r"
done
} > "$OUT"

cat "$OUT"
echo
echo "wrote $OUT" >&2