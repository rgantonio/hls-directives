# Solution: bram
#
# Pin a_buf to a single-port RAM built from block RAM, with the latency left to
# the tool. A block RAM is a hard 18 Kb memory block with a registered read,
# so the data of a read issued in one cycle arrives in the next.
# Check run.log and the Bind Storage Report: a_buf should show RAM_1P, bram.
set_directive_bind_storage -type RAM_1P -impl BRAM "vadd" a_buf