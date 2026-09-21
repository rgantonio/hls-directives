# Solution: pipo
#
# DATAFLOW, plus STREAM forcing t to be a ping-pong buffer. The producer
# fills one bank of 16 words while the consumer may read the other, so the
# two processes overlap only across calls, never inside one call. STORE_LOOP's
# ap_start is gated by the channel's t_empty_n, which is what serializes them.
#
# Note that this solution prints nothing about t in the log: -type pipo asks
# for the default channel form, so there is no conversion to report.
#
# Measured: LOAD proc 33 (a RAM write needs 2 states per element, not 3),
#           STORE proc 81, latency 115 = 33 + 1 + 81, interval 82 (unchanged).
#           Cosim 115 / 116, 1855 cycles for 16 calls.
#           t_U = ram_1p channel, pipo, auto, latency 1, 32 x 16 x 2 banks.
#           Vivado: 97 LUT (20 of them LUTRAM), 85 FF, 3 DSP, 0 BRAM -- the
#           cheapest of the three, despite holding 1024 bits.

set_directive_dataflow "pipe2"
set_directive_stream -type pipo "pipe2" t
