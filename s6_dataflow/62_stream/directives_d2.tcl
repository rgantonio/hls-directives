# Solution: d2
#
# DATAFLOW, plus STREAM setting t to a FIFO of depth 2. STORE_LOOP is slower
# than LOAD_LOOP, so the FIFO fills and LOAD_LOOP waits on if_full_n. This is
# the solution that prints HLS 214-142, and the one run_hls.tcl co-simulates
# with -trace_level port_hier so that t_U can be dumped to a VCD afterwards.
#
# Measured: identical to base in every timing number -- LOAD proc 49,
#           STORE proc 81, latency 83, interval 82, cosim 83 / 84, 1343
#           cycles for 16 calls. The consumer sets both, so the 22 cycles
#           LOAD_LOOP spends stalled per call cost nothing.
#           t_U = fifo channel, srl, 32 x 2 x 1 bank; first full edge c47.
#           Vivado: 109 LUT, 176 FF, 3 DSP, 0 BRAM. The 64 bits of storage
#           land on 64 flip-flops because a 2-deep shift register is too
#           short to infer SRL16E, so d2 is the largest of the three in FF.

set_directive_dataflow "pipe2"
set_directive_stream -type fifo -depth 2 "pipe2" t
