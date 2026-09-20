# Solution: max1
#
# Ask for a function latency of exactly one cycle. That means a two-state
# design, which has to hold two dependent 32 bit multiplies and the additions,
# and 3.479 + 2.365 ns of multiplier does not fit in the 2.431 ns that remains
# of a 3.33 ns clock period after clock uncertainty.
#
# Do not assume the tool will therefore refuse. It does not. Vitis HLS honours
# the latency constraint and gives up the clock: it re-binds a*x from the
# pipelined DSP multiplier to a purely combinational LUT multiplier, packs the
# chain into two states, and reports
#
#   WARNING: [HLS 200-886] Cannot meet target clock period ... to honor
#            Latency constraint (Latency=1) in region 'poly'.
#   WARNING: [HLS 200-871] Estimated clock period (5.844 ns) exceeds the target
#
# These are warnings, not errors, so the run still exits with status 0.
#
# Measured: latency 1, interval 2, estimated clock 5.844 ns, slack -3.41 ns,
# Fmax 171 MHz against 423 MHz for the other three solutions. DSP falls from
# 9 to 6 and LUT rises from 242 to 1229, because the multiply that left the
# DSPs reappeared as 1053 look-up tables.
#
# Check run.log for the warnings, and check the estimated clock period and the
# slack -- the latency table on its own says the constraint was honoured and
# tells you nothing about the cost.
set_directive_latency -min 1 -max 1 "poly"
