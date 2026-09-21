# Solution: base
#
# No directives. One FSM runs LOAD_LOOP and then STORE_LOOP, and t is one
# local memory of 16 words of 32 bits. A new call can start only after
# ap_done, so the interval is the latency plus one.
#
# Measured: latency 66 (two loops of 32 cycles plus 2), interval 67; t_U is a
# ram_1p array (32 x 16 x 1) in the Storage Report; one Verilog module plus
# the RAM. Vivado: 117 LUT, 55 FF, 0 BRAM, 0 DSP.
