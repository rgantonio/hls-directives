#!/usr/bin/env bash
# Lesson 5.3: simulate one solution's RTL with tb/rst_tb.v, which pulses
# ap_rst between calls. Needs xvlog, xelab and xsim from Vivado on the PATH.
#
#   bash sim_reset.sh base | reset_cnt | reset_hist
set -euo pipefail

sol=${1:-base}
here=$(cd "$(dirname "$0")" && pwd)
rtl=$here/counter_proj/$sol/syn/verilog
work=$here/rst_sim/$sol

[ -d "$rtl" ] || { echo "no RTL in $rtl; run run_hls.tcl first" >&2; exit 1; }

rm -rf "$work"
mkdir -p "$work"
cd "$work"

# The memory modules load their initial contents from .dat files with a
# relative path, so the simulation runs in a copy of the RTL directory.
cp "$rtl"/*.v .
cp "$rtl"/*.dat . 2>/dev/null || true

xvlog --nolog ./*.v "$here/tb/rst_tb.v" > xvlog.out
xelab --nolog -debug typical rst_tb -s rst_tb > xelab.out
echo "== $sol"
xsim --nolog rst_tb -R | grep -E "^call|^-- reset"