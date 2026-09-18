#!/usr/bin/env bash
# common/collect_latency.sh <project_dir>
#
# Prints one row per solution with the latency and interval numbers taken from
# <project>/<solution>/syn/report/csynth.xml. The XML report is used instead of
# the pretty-printed csynth.rpt because its tags are stable and easy to grep.
#
# If a column comes out empty, list the tag names your install actually writes:
#   grep -o '<[A-Za-z0-9_-]*>' <project>/<solution>/syn/report/csynth.xml | sort -u

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
printf "%-10s %10s %10s %10s %10s %12s\n" \
       solution best worst ii_min ii_max clk_est_ns

for xml in "$proj"/*/syn/report/csynth.xml; do
    [ -e "$xml" ] || continue
    found=1
    sol=$(basename "$(dirname "$(dirname "$(dirname "$xml")")")")
    printf "%-10s %10s %10s %10s %10s %12s\n" \
        "$sol" \
        "$(tag "$xml" 'Best-caseLatency')" \
        "$(tag "$xml" 'Worst-caseLatency')" \
        "$(tag "$xml" 'Interval-min')" \
        "$(tag "$xml" 'Interval-max')" \
        "$(tag "$xml" 'EstimatedClockPeriod')"
done

if [ "$found" -eq 0 ]; then
    echo "no csynth.xml found under $proj (has C synthesis run?)" >&2
    exit 1
fi