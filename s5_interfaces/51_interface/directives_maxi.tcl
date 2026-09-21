# Solution: maxi
#
# All three arrays are fetched and stored by the block itself through one
# AXI4 master adapter, bundle gmem, so a and b share one read channel.
#
# -offset direct  each base address is a plain 64-bit input port named a, b
#                 and y. With -offset slave the addresses would go into an
#                 AXI4-Lite slave instead, adding a second adapter to this
#                 solution (see section 9 of the README).
# -depth 16       sizes the memory model that co-simulation serves the master
#                 from. It builds no hardware; for pointers it is mandatory.
#
# Predicted, not yet measured: C synthesis latency above 33, because one
# 32-bit read channel delivers at most one word per cycle and each iteration
# needs two. Co-simulation latency above C synthesis, because C synthesis
# schedules against an assumed bus latency.

set_directive_interface -mode m_axi -bundle gmem -offset direct -depth 16 "vadd" a
set_directive_interface -mode m_axi -bundle gmem -offset direct -depth 16 "vadd" b
set_directive_interface -mode m_axi -bundle gmem -offset direct -depth 16 "vadd" y