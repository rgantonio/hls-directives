# Solution: base
#
# Two helper directives, identical in all three solutions, so that the only
# difference between the solutions is the DEPENDENCE line.
#
# PIPELINE: DEPENDENCE only matters when iterations overlap, so HIST_LOOP is
# pipelined. No -II is given, so the scheduler reports the best II it can
# reach and the log line says Target II = NA.
#
# BIND_STORAGE: acc is pinned to a plain two-port block RAM. This matters.
# Left to itself on this kernel, Vitis HLS 2023.2.2 builds read-during-write
# forwarding logic of its own, a register plus a comparator plus a
# multiplexer, and reaches II 1 without any help. Pinning acc to an ordinary
# RAM_2P is the realistic storage choice that makes the loop-carried
# dependence visible in the schedule instead of hidden in extra hardware.
#
# With no DEPENDENCE directive the tool assumes that iteration i+1 may read
# the element that iteration i writes, cannot meet that constraint at II 1,
# and settles on II 2. This solution is correct for every input.
set_directive_pipeline "hist/HIST_LOOP"
set_directive_bind_storage -type RAM_2P -impl BRAM -latency 1 "hist" acc
