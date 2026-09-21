# Solution: dataflow
#
# DATAFLOW on the top function. Each loop is extracted into a process with its
# own FSM, and t becomes a channel between them.
#
# config_dataflow is left at its defaults, so an array channel would be a
# ping-pong buffer of two banks. It is not one here: both ends touch t strictly
# in order, so Vitis HLS converts it to a FIFO on its own
# ("Change variable 't' to FIFO automatically"). A FIFO releases the consumer
# after the first element instead of after the whole array, so the two stages
# overlap inside a single call and the latency falls as well as the interval.
#
# Measured: latency 51, interval 50 (the slower process, LOAD at 49, plus one);
# two process modules, Loop_LOAD_LOOP_proc at 49 and Loop_STORE_LOOP_proc at
# 33; t_U is a fifo channel, srl, 32 x 16 -- the same 512 bits as base, not
# double; ap_ready is the AND of both processes' ready signals, ap_done comes
# from the STORE process alone. Co-simulation: 51/52 per call, 831 cycles for
# 16 calls against 1071 in base. Vivado: 131 LUT, 94 FF (+14 / +39).

set_directive_dataflow "pipe2"
