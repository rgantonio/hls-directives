#!/usr/bin/env bash
# common/collect_resources.sh <project_dir>
#
# Prints one row per solution with the generated module name and the post
# synthesis resource estimates taken from
# <project>/<solution>/syn/report/csynth.xml.
#
# The columns are the FPGA primitives Vitis HLS estimates: BRAM_18K is a block
# RAM half-tile, DSP is a hardened multiply-accumulate slice, FF is a flip-flop
# and LUT is a look-up table. URAM is the larger UltraRAM block.

set -u

proj="${1:-}"
if [ -z "$proj" ]; then
    echo "usage: $0 <project_dir>" >&2
    exit 2
fi

tag() {
    sed -n "s:.*<$2>\([^<]*\)</$2>.*:\1:p" "$1" | head -n 1
}

found=0
printf "%-10s %-14s %9s %6s %8s %8s %6s\n" \
       solution module BRAM_18K DSP FF LUT URAM

for xml in "$proj"/*/syn/report/csynth.xml; do
    [ -e "$xml" ] || continue
    found=1
    sol=$(basename "$(dirname "$(dirname "$(dirname "$xml")")")")

    dsp="$(tag "$xml" 'DSP')"
    [ -n "$dsp" ] || dsp="$(tag "$xml" 'DSP48E')"

    printf "%-10s %-14s %9s %6s %8s %8s %6s\n" \
        "$sol" \
        "$(tag "$xml" 'TopModelName')" \
        "$(tag "$xml" 'BRAM_18K')" \
        "$dsp" \
        "$(tag "$xml" 'FF')" \
        "$(tag "$xml" 'LUT')" \
        "$(tag "$xml" 'URAM')"
done

if [ "$found" -eq 0 ]; then
    echo "no csynth.xml found under $proj (has C synthesis run?)" >&2
    exit 1
fi