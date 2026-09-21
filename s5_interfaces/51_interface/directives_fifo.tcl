# Solution: fifo
#
# All three arrays become ap_fifo ports. Legal here because vadd reads every
# a[i] and b[i] once and writes every y[i] once, in increasing index order.
#
# Ports: a_dout, a_empty_n, a_read (and b likewise); y_din, y_full_n, y_write.
# 2023.2 may also add *_num_data_valid and *_fifo_cap, which the loop ignores.
#
# Predicted, not yet measured: a FIFO read has no address phase, so the read,
# the add and the write share one state. Iteration latency 1, function
# latency 17, interval 18. Every access is blocking: while any empty_n or
# full_n of the state is low, the FSM stays in that state and no port moves.

set_directive_interface -mode ap_fifo "vadd" a
set_directive_interface -mode ap_fifo "vadd" b
set_directive_interface -mode ap_fifo "vadd" y