# Solution: base
#
# DATAFLOW on the top function and nothing else. Both loops touch t strictly
# in order, so Vitis HLS turns t into a FIFO on its own (XFORM 203-721), and
# a converted array keeps its size as its depth: 16 words of 32 bits. This is
# the same channel as the 6.1 dataflow solution; only the kernel's STORE
# operator differs from 6.1.
#
# Measured: LOAD proc 49, STORE proc 81, latency 83, interval 82.
#           Cosim 83 / 84, 1343 cycles for 16 calls.
#           t_U = fifo channel, srl, 32 x 16 x 1 bank.
#           Vivado: 113 LUT (32 of them SRL16E), 114 FF, 3 DSP, 0 BRAM.

set_directive_dataflow "pipe2"
