# Solution: lutram
#
# Pin a_buf to a single-port RAM built from look-up tables (distributed RAM).
# The LUTs read asynchronously, and Vitis adds an output register, so the read
# latency is expected to stay 1. Only the implementation differs from bram.
# Check the Memory table: BRAM_18K should drop to 0 and LUT should rise.
set_directive_bind_storage -type RAM_1P -impl LUTRAM "vadd" a_buf